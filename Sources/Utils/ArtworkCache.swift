import AppKit
import Foundation

/// Two-tier LRU artwork cache: memory (NSCache) + disk (~/Library/Caches/<bundle>/Artwork/).
/// Keyed by Spotify track ID so the same image is never fetched twice.
/// Disk entries are evicted by least-recent access time when the size cap is exceeded.
actor ArtworkCache {
    static let shared = ArtworkCache()

    /// L0: decoded NSImage kept in memory to avoid re-decoding on every hit.
    private let imageCache = NSCache<NSString, NSImage>()
    /// L1 + L2: raw Data in memory + disk via generic Cache.
    private let dataCache: Cache<String, Data>
    private let session: URLSession

    private init() {
        imageCache.countLimit = 50
        dataCache = Cache(
            memoryCountLimit: 50,
            namespace: "Artwork",
            diskLimitBytes: 100 * 1024 * 1024,
            serializer: DataCacheSerializer()
        )

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    /// Synchronous memory-cache lookup (NSCache is thread-safe).
    /// Returns nil if the image is not in memory — does not check disk or network.
    nonisolated func cachedImage(for trackId: String) -> NSImage? {
        imageCache.object(forKey: trackId as NSString)
    }

    /// Returns a cached image or fetches from the network, caching the result.
    /// Concurrent calls for the same track ID are coalesced into a single fetch.
    func image(for trackId: String, url: URL) async -> NSImage? {
        let nsKey = trackId as NSString

        // L0: decoded image in memory — zero decode cost
        if let cached = imageCache.object(forKey: nsKey) {
            return cached
        }

        // L1/L2: raw data from memory or disk, then fetch if needed
        let session = session
        let data = await dataCache.value(forKey: trackId) { [session] in
            guard let (data, _) = try? await session.data(from: url),
                  NSImage(data: data) != nil
            else {
                logWarning("Artwork fetch failed for track: \(trackId)")
                return nil
            }
            return data
        }
        guard let data, let image = NSImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: nsKey)
        return image
    }
}
