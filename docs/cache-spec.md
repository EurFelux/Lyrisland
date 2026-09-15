# Cache Layer Spec

Generic two-tier (memory + disk) caching system with LRU eviction and concurrent fetch coalescing.

**Source:** `Sources/Utils/Cache.swift`

## Architecture

```
               value(forKey:fetch:)
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   ┌─────────┐  ┌───────────┐  ┌──────────────┐
   │  Memory  │  │   Disk    │  │ Fetch + Write│
   │ (NSCache)│  │ (LRU dir) │  │  (coalesced) │
   └─────────┘  └───────────┘  └──────────────┘
     L1 hit       L2 hit         L3 network
     ~0 cost    decode cost      full cost
```

Lookup order: Memory → Disk → Fetch closure. Successful fetches are written back to both tiers.

## Key types

### `Cache<Key, Value>` (actor)

Generic parameters:
- `Key: Hashable & LosslessStringConvertible & Sendable` — key also serves as disk filename (percent-encoded)
- `Value: Sendable` — values cross actor boundaries safely

Two initializers:

| Init | Tiers | Use when |
|------|-------|----------|
| `init(memoryCountLimit:)` | Memory only | No persistence needed |
| `init(memoryCountLimit:namespace:diskLimitBytes:serializer:)` | Memory + Disk | Persistence needed |

Disk path: `~/Library/Caches/<bundleId>/<namespace>/`

### Public API

```swift
// Lookup or fetch (coalesces concurrent calls for the same key)
func value(forKey: Key, fetch: @Sendable @escaping () async -> Value?) async -> Value?

// Direct get (memory → disk, no fetch)
func get(_ key: Key) -> Value?

// Direct set (writes to both tiers)
func set(_ value: Value, forKey key: Key)

// Clear everything
func removeAll()
```

### `CacheSerializer` protocol

```swift
protocol CacheSerializer<Value> {
    associatedtype Value
    func encode(_ value: Value) -> Data?
    func decode(_ data: Data) -> Value?
}
```

Built-in implementations:

| Serializer | Value type | Strategy |
|---|---|---|
| `CodableCacheSerializer<T: Codable>` | Any `Codable` | JSON encode/decode |
| `DataCacheSerializer` | `Data` | Pass-through (identity) |

## Current usages

### Lyrics — `LyricsManager`

```swift
private let cache = Cache<String, SyncedLyrics>(
    memoryCountLimit: 200,
    namespace: "Lyrics",
    diskLimitBytes: 50 * 1024 * 1024,     // 50 MB
    serializer: CodableCacheSerializer<SyncedLyrics>()
)
```

- Key: Spotify track ID
- Serializer: JSON (SyncedLyrics conforms to `Codable`)
- Pattern: `cache.get()` for lookup, `cache.set()` for store after provider fetch
- Disk: `~/Library/Caches/com.wangjiyuan.Lyrisland/Lyrics/`

### Artwork — `ArtworkCache`

```swift
// L0: decoded NSImage (no disk, avoids re-decoding)
private let imageCache = NSCache<NSString, NSImage>()  // countLimit: 50

// L1+L2: raw Data via generic Cache
private let dataCache = Cache<String, Data>(
    memoryCountLimit: 50,
    namespace: "Artwork",
    diskLimitBytes: 100 * 1024 * 1024,    // 100 MB
    serializer: DataCacheSerializer()
)
```

- Key: Spotify track ID
- Serializer: pass-through (images stored as raw bytes)
- Pattern: `dataCache.value(forKey:fetch:)` with URL fetch closure; `NSImage` decoded once, held in L0 `imageCache`
- Disk: `~/Library/Caches/com.wangjiyuan.Lyrisland/Artwork/`
- Note: L0 exists because `NSImage(data:)` is expensive; generic `Cache` stores `Data`, `ArtworkCache` adds a decoded-image layer on top

## Disk eviction

LRU by file modification date. On every write:
1. Scan namespace directory for total size
2. If over limit, sort files oldest-first, delete until under limit

`touchDiskEntry()` updates mtime on every read hit to keep hot entries alive.

## Fetch coalescing

`value(forKey:fetch:)` tracks in-flight `Task`s per key. If a second caller requests the same key while a fetch is running, it `await`s the existing task instead of launching a duplicate.

```
Thread A: value(forKey: "x", fetch: fetchFromNetwork)  → starts Task
Thread B: value(forKey: "x", fetch: fetchFromNetwork)  → awaits existing Task
Thread C: value(forKey: "x", fetch: fetchFromNetwork)  → awaits existing Task
                                                         ↓
                                             Single network request
```

## Adding a new cached data type

1. Ensure your `Value` type conforms to `Sendable`. If you need disk persistence, also conform to `Codable`.
2. Instantiate `Cache` with an appropriate serializer:

```swift
let cache = Cache<String, MyModel>(
    memoryCountLimit: 100,
    namespace: "MyModel",
    diskLimitBytes: 20 * 1024 * 1024,
    serializer: CodableCacheSerializer<MyModel>()
)
```

3. For non-`Codable` values needing custom serialization, implement `CacheSerializer`:

```swift
struct MySerializer: CacheSerializer {
    func encode(_ value: MyType) -> Data? { /* ... */ }
    func decode(_ data: Data) -> MyType? { /* ... */ }
}
```

4. If your value type is expensive to decode from `Data` (like `NSImage`), consider adding an L0 `NSCache` for the decoded form on top of the generic `Cache`, as `ArtworkCache` does.

## Capacity reference

| Cache | Memory limit | Disk limit | Disk path |
|---|---|---|---|
| Lyrics | 200 items | 50 MB | `~/Library/Caches/.../Lyrics/` |
| Artwork (data) | 50 items | 100 MB | `~/Library/Caches/.../Artwork/` |
| Artwork (image) | 50 items | N/A (memory only) | — |

## Tests

`Tests/CacheTests.swift` — 9 tests covering:
- Memory get/set round-trip
- Cache miss returns nil
- `value(forKey:fetch:)` calls fetch on miss
- Fetch skipped on hit
- `removeAll` clears cache
- Disk persistence with `CodableCacheSerializer`
- Fetch coalescing (concurrent requests share one task)
- `CodableCacheSerializer` encode/decode
- `DataCacheSerializer` pass-through
