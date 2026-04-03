import AppKit
import Foundation

/// Two-tier LRU artwork cache: memory (NSCache) + disk (~/Library/Caches/<bundle>/Artwork/).
/// Keyed by Spotify track ID so the same image is never fetched twice.
/// Disk entries are evicted by least-recent access time when the size cap is exceeded.
actor ArtworkCache {
    static let shared = ArtworkCache()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let diskDirectory: URL
    private let session: URLSession
    /// Maximum disk cache size in bytes (100 MB).
    private let diskLimitBytes: Int = 100 * 1024 * 1024

    /// In-flight fetch tasks, keyed by track ID, to avoid duplicate network requests.
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "Lyrisland"
        diskDirectory = cacheDir.appendingPathComponent(bundleId).appendingPathComponent("Artwork")
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 50

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    /// Synchronous memory-cache lookup (NSCache is thread-safe).
    /// Returns nil if the image is not in memory — does not check disk or network.
    nonisolated func cachedImage(for trackId: String) -> NSImage? {
        memoryCache.object(forKey: trackId as NSString)
    }

    /// Returns a cached image or fetches from the network, caching the result.
    /// Concurrent calls for the same track ID are coalesced into a single fetch.
    func image(for trackId: String, url: URL) async -> NSImage? {
        let key = trackId as NSString

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key) {
            touchDiskEntry(trackId)
            return cached
        }

        // 2. Disk cache
        let filePath = diskPath(for: trackId)
        if let data = try? Data(contentsOf: filePath), let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: key)
            touchDiskEntry(trackId)
            return image
        }

        // 3. Coalesce concurrent fetches for the same track
        if let existing = inFlight[trackId] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> { [session] in
            guard let (data, _) = try? await session.data(from: url),
                  let image = NSImage(data: data)
            else {
                logWarning("Artwork fetch failed for track: \(trackId)")
                return nil
            }
            try? data.write(to: filePath, options: .atomic)
            return image
        }
        inFlight[trackId] = task

        let image = await task.value
        inFlight[trackId] = nil

        if let image {
            memoryCache.setObject(image, forKey: key)
            evictDiskIfNeeded()
        }

        return image
    }

    // MARK: - Disk Helpers

    /// Percent-encode trackId for safe use as a filename.
    private func diskPath(for trackId: String) -> URL {
        let safeName = trackId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? trackId
        return diskDirectory.appendingPathComponent(safeName)
    }

    /// Update the file's modification date so it sorts as most-recently-used.
    private func touchDiskEntry(_ trackId: String) {
        let path = diskPath(for: trackId)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: path.path
        )
    }

    /// Remove the oldest files when total disk usage exceeds `diskLimitBytes`.
    private func evictDiskIfNeeded() {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let entries = try? fm.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        ) else { return }

        var totalSize = 0
        var items: [(url: URL, date: Date, size: Int)] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: keys) else { continue }
            let size = values.fileSize ?? 0
            let date = values.contentModificationDate ?? .distantPast
            totalSize += size
            items.append((entry, date, size))
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
