import Foundation

// MARK: - CacheSerializer

/// Strategy for encoding/decoding cache values to/from `Data` for disk persistence.
protocol CacheSerializer<Value> {
    associatedtype Value
    func encode(_ value: Value) -> Data?
    func decode(_ data: Data) -> Value?
}

/// Serializer for `Codable` types using JSON.
struct CodableCacheSerializer<T: Codable>: CacheSerializer {
    func encode(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    func decode(_ data: Data) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Pass-through serializer for raw `Data` values (e.g. images).
struct DataCacheSerializer: CacheSerializer {
    func encode(_ value: Data) -> Data? {
        value
    }

    func decode(_ data: Data) -> Data? {
        data
    }
}

// MARK: - Cache

/// Generic two-tier LRU cache: memory (NSCache) + optional disk (~/Library/Caches/<bundle>/<namespace>/).
/// Supports configurable limits and async fetch coalescing.
actor Cache<Key: Hashable & LosslessStringConvertible & Sendable, Value: Sendable> {
    private let memoryCache = NSCache<CacheKey, CacheEntry>()
    private let diskDirectory: URL?
    private let diskLimitBytes: Int
    private let serializeForDisk: (@Sendable (Value) -> Data?)?
    private let deserializeFromDisk: (@Sendable (Data) -> Value?)?

    /// In-flight fetch tasks to avoid duplicate work for the same key.
    private var inFlight: [Key: Task<Value?, Never>] = [:]

    /// Create a memory-only cache.
    init(memoryCountLimit: Int) {
        memoryCache.countLimit = memoryCountLimit
        diskDirectory = nil
        diskLimitBytes = 0
        serializeForDisk = nil
        deserializeFromDisk = nil
    }

    /// Create a two-tier (memory + disk) cache.
    init<S: CacheSerializer>(
        memoryCountLimit: Int,
        namespace: String,
        diskLimitBytes: Int,
        serializer: S
    ) where S.Value == Value {
        memoryCache.countLimit = memoryCountLimit
        self.diskLimitBytes = diskLimitBytes
        serializeForDisk = { serializer.encode($0) }
        deserializeFromDisk = { serializer.decode($0) }

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "Lyrisland"
        let dir = cacheDir.appendingPathComponent(bundleId).appendingPathComponent(namespace)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        diskDirectory = dir
    }

    // MARK: - Public API

    /// Retrieve a value from cache (memory → disk), or fetch via the closure and cache the result.
    /// Concurrent calls for the same key are coalesced into a single fetch.
    func value(forKey key: Key, fetch: @Sendable @escaping () async -> Value?) async -> Value? {
        let cacheKey = CacheKey(key)

        // 1. Memory
        if let cached = memoryCache.object(forKey: cacheKey) {
            touchDiskEntry(for: key)
            return cached.value as? Value
        }

        // 2. Disk
        if let diskDir = diskDirectory, let deserialize = deserializeFromDisk {
            let filePath = diskPath(for: key, in: diskDir)
            if let data = try? Data(contentsOf: filePath), let value = deserialize(data) {
                memoryCache.setObject(CacheEntry(value), forKey: cacheKey)
                touchDiskEntry(for: key)
                return value
            }
        }

        // 3. Coalesce in-flight fetches
        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<Value?, Never> {
            await fetch()
        }
        inFlight[key] = task

        let result = await task.value
        inFlight[key] = nil

        if let result {
            memoryCache.setObject(CacheEntry(result), forKey: cacheKey)
            // Disk write on the actor, serialized with eviction to avoid race
            if let diskDir = diskDirectory, let serialize = serializeForDisk,
               let data = serialize(result) {
                let filePath = diskPath(for: key, in: diskDir)
                try? data.write(to: filePath, options: .atomic)
            }
            evictDiskIfNeeded()
        }

        return result
    }

    /// Store a value directly (both memory and disk).
    func set(_ value: Value, forKey key: Key) {
        memoryCache.setObject(CacheEntry(value), forKey: CacheKey(key))

        if let diskDir = diskDirectory, let serialize = serializeForDisk,
           let data = serialize(value) {
            let filePath = diskPath(for: key, in: diskDir)
            try? data.write(to: filePath, options: .atomic)
            evictDiskIfNeeded()
        }
    }

    /// Retrieve a value without fetching (memory → disk lookup only).
    func get(_ key: Key) -> Value? {
        let cacheKey = CacheKey(key)

        if let cached = memoryCache.object(forKey: cacheKey) {
            touchDiskEntry(for: key)
            return cached.value as? Value
        }

        if let diskDir = diskDirectory, let deserialize = deserializeFromDisk {
            let filePath = diskPath(for: key, in: diskDir)
            if let data = try? Data(contentsOf: filePath), let value = deserialize(data) {
                memoryCache.setObject(CacheEntry(value), forKey: cacheKey)
                touchDiskEntry(for: key)
                return value
            }
        }

        return nil
    }

    /// Remove all entries from both tiers.
    func removeAll() {
        memoryCache.removeAllObjects()
        if let diskDir = diskDirectory {
            let fm = FileManager.default
            if let entries = try? fm.contentsOfDirectory(
                at: diskDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) {
                for entry in entries {
                    try? fm.removeItem(at: entry)
                }
            }
        }
    }

    // MARK: - Disk Helpers

    /// Percent-encode key for safe use as a filename.
    private nonisolated func diskPath(for key: Key, in directory: URL) -> URL { // swiftlint:disable:this modifier_order
        let safeName = key.description
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key.description
        return directory.appendingPathComponent(safeName)
    }

    /// Update the file's modification date so it sorts as most-recently-used.
    private func touchDiskEntry(for key: Key) {
        guard let diskDir = diskDirectory else { return }
        let path = diskPath(for: key, in: diskDir)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: path.path
        )
    }

    /// Remove the oldest files when total disk usage exceeds the limit.
    private func evictDiskIfNeeded() {
        guard let diskDir = diskDirectory, diskLimitBytes > 0 else { return }
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let entries = try? fm.contentsOfDirectory(
            at: diskDir,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        ) else { return }

        var totalSize = 0
        var items: [DiskItem] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: keys) else { continue }
            let size = values.fileSize ?? 0
            let date = values.contentModificationDate ?? .distantPast
            totalSize += size
            items.append(DiskItem(url: entry, date: date, size: size))
        }

        guard totalSize > diskLimitBytes else { return }

        items.sort { $0.date < $1.date }

        for item in items {
            try? fm.removeItem(at: item.url)
            totalSize -= item.size
            if totalSize <= diskLimitBytes { break }
        }
    }
}

// MARK: - DiskItem

private struct DiskItem {
    let url: URL
    let date: Date
    let size: Int
}

// MARK: - NSCache Wrappers (type-erased to avoid generic NSObject subclasses)

/// Type-erased NSObject key wrapping any Hashable value.
private final class CacheKey: NSObject {
    let rawKey: AnyHashable
    init(_ key: some Hashable) {
        rawKey = AnyHashable(key)
    }

    override var hash: Int {
        rawKey.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? CacheKey)?.rawKey == rawKey
    }
}

/// Type-erased NSObject wrapper for cache values.
/// Safety: only `Cache<Key, Value>` writes entries, so `value as? Value` always succeeds.
private final class CacheEntry: NSObject {
    let value: Any
    init(_ value: Any) {
        self.value = value
    }
}
