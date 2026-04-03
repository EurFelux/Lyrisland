import Foundation
@testable import Lyrisland
import Testing

struct CacheTests {
    // MARK: - Memory-only

    @Test("Memory get/set round-trip")
    func memoryGetSet() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        await cache.set("hello", forKey: "key1")
        let value = await cache.get("key1")
        #expect(value == "hello")
    }

    @Test("Memory cache returns nil for missing key")
    func memoryMiss() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        let value = await cache.get("nonexistent")
        #expect(value == nil)
    }

    @Test("value(forKey:fetch:) calls fetch on miss and caches result")
    func fetchOnMiss() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        let value = await cache.value(forKey: "k") {
            "fetched"
        }
        #expect(value == "fetched")
        // Should be cached now
        let cached = await cache.get("k")
        #expect(cached == "fetched")
    }

    @Test("value(forKey:fetch:) returns cached value without calling fetch")
    func fetchSkippedOnHit() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        await cache.set("existing", forKey: "k")
        let value = await cache.value(forKey: "k") {
            "should-not-be-called"
        }
        #expect(value == "existing")
    }

    @Test("removeAll clears memory cache")
    func removeAll() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        await cache.set("a", forKey: "1")
        await cache.set("b", forKey: "2")
        await cache.removeAll()
        #expect(await cache.get("1") == nil)
        #expect(await cache.get("2") == nil)
    }

    // MARK: - Two-tier (memory + disk)

    @Test("Disk persistence round-trip with Codable serializer")
    func diskRoundTrip() async {
        let cache = Cache<String, SyncedLyrics>(
            memoryCountLimit: 10,
            namespace: "CacheTest-\(UUID().uuidString)",
            diskLimitBytes: 10 * 1024 * 1024,
            serializer: CodableCacheSerializer<SyncedLyrics>()
        )

        let lyrics = SyncedLyrics(
            lines: [LyricLine(id: 0, time: 1.0, text: "Hello", translation: nil)],
            source: "test",
            globalOffset: 0
        )
        await cache.set(lyrics, forKey: "track1")

        // Verify in-memory hit
        let cached = await cache.get("track1")
        #expect(cached?.lines.count == 1)
        #expect(cached?.lines.first?.text == "Hello")
        #expect(cached?.source == "test")
    }

    @Test("Fetch coalescing shares a single fetch across concurrent callers")
    func fetchCoalescing() async {
        let cache = Cache<String, String>(memoryCountLimit: 10)
        let counter = FetchCounter()

        // The first fetch blocks on a continuation until we release it,
        // guaranteeing all callers observe the same in-flight task.
        let gate = Gate()

        await withTaskGroup(of: String?.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    await cache.value(forKey: "shared") {
                        await counter.increment()
                        await gate.wait()
                        return "result"
                    }
                }
            }

            // Give tasks time to enter value(forKey:) and coalesce
            try? await Task.sleep(nanoseconds: 100_000_000)
            // Release the gate so the single fetch completes
            await gate.open()

            for await result in group {
                #expect(result == "result")
            }
        }

        // Exactly 1 fetch — all others coalesced onto the in-flight task
        let count = await counter.count
        #expect(count == 1)
    }
}

// MARK: - Test Helpers

/// Thread-safe counter for verifying fetch call count.
private actor FetchCounter {
    var count = 0
    func increment() {
        count += 1
    }
}

/// Simple gate that blocks waiters until opened.
private actor Gate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        opened = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }
}

struct CacheSerializerTests {
    @Test("CodableCacheSerializer round-trip")
    func codableRoundTrip() throws {
        let serializer = CodableCacheSerializer<SyncedLyrics>()
        let lyrics = SyncedLyrics(
            lines: [
                LyricLine(id: 0, time: 5.0, text: "Test line", translation: "翻译"),
                LyricLine(id: 1, time: 10.0, text: "Second line", translation: nil),
            ],
            source: "lrclib",
            globalOffset: 0.5
        )

        let data = serializer.encode(lyrics)
        #expect(data != nil)

        let decoded = try serializer.decode(#require(data))
        #expect(decoded != nil)
        #expect(decoded?.lines.count == 2)
        #expect(decoded?.lines[0].text == "Test line")
        #expect(decoded?.lines[0].translation == "翻译")
        #expect(decoded?.lines[1].translation == nil)
        #expect(decoded?.source == "lrclib")
        #expect(decoded?.globalOffset == 0.5)
    }

    @Test("DataCacheSerializer pass-through")
    func dataPassThrough() {
        let serializer = DataCacheSerializer()
        let original = Data([0x01, 0x02, 0x03])

        let encoded = serializer.encode(original)
        #expect(encoded == original)

        let decoded = serializer.decode(original)
        #expect(decoded == original)
    }
}
