import AppKit
import CoreImage
import SwiftUI

/// Extracts dominant colors from album artwork using Core Image.
/// Actor-isolated to ensure thread-safe cache access.
actor ColorExtractor {
    static let shared = ColorExtractor()

    private var cache: [String: [Color]] = [:]
    private var insertionOrder: [String] = []
    private let maxCacheSize = 10

    /// Extract dominant colors from an NSImage by sampling 5 regions.
    /// Returns colors sorted by brightness (darkest first).
    func extractColors(from image: NSImage, trackId: String? = nil) -> [Color] {
        if let trackId, let cached = cache[trackId] {
            return cached
        }

        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData)
        else { return [] }

        let extent = ciImage.extent
        let regions: [CGRect] = [
            CGRect(x: extent.minX, y: extent.midY, width: extent.width / 2, height: extent.height / 2),
            CGRect(x: extent.midX, y: extent.midY, width: extent.width / 2, height: extent.height / 2),
            CGRect(x: extent.minX, y: extent.minY, width: extent.width / 2, height: extent.height / 2),
            CGRect(x: extent.midX, y: extent.minY, width: extent.width / 2, height: extent.height / 2),
            CGRect(
                x: extent.width * 0.25,
                y: extent.height * 0.25,
                width: extent.width * 0.5,
                height: extent.height * 0.5
            ),
        ]

        let context = CIContext(options: [.useSoftwareRenderer: false])
        var colors: [Color] = []

        for region in regions {
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: region),
            ]),
                let output = filter.outputImage
            else { continue }

            var pixel = [UInt8](repeating: 0, count: 4)
            context.render(
                output,
                toBitmap: &pixel,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )

            let r = Double(pixel[0]) / 255.0
            let g = Double(pixel[1]) / 255.0
            let b = Double(pixel[2]) / 255.0

            // Darken colors to ensure readability (cap brightness at 0.35)
            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            let scale = brightness > 0.35 ? 0.35 / brightness : 1.0
            colors.append(Color(red: r * scale, green: g * scale, blue: b * scale))
        }

        // Sort by perceived brightness (darkest first)
        colors.sort { c1, c2 in
            perceivedBrightness(c1) < perceivedBrightness(c2)
        }

        if let trackId {
            if cache.count >= maxCacheSize, let oldest = insertionOrder.first {
                cache.removeValue(forKey: oldest)
                insertionOrder.removeFirst()
            }
            cache[trackId] = colors
            insertionOrder.append(trackId)
        }

        return colors
    }

    private func perceivedBrightness(_ color: Color) -> Double {
        let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        return 0.299 * resolved.redComponent + 0.587 * resolved.greenComponent + 0.114 * resolved.blueComponent
    }
}
