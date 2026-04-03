#!/usr/bin/env swift
// Generates a DMG background image with a "drag to Applications" arrow.
// Usage: swift generate-dmg-background.swift <output-path> <width> <height>
// Uses CGBitmapContext directly — no window server needed, safe for headless CI.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let width = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 660 : 660
let height = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 400 : 400

// MARK: - Drawing

func generateBackground(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create bitmap context")
    }

    let w = CGFloat(width)
    let h = CGFloat(height)

    // -- Background gradient (light, elegant) --
    let gradientColors = [
        CGColor(colorSpace: colorSpace, components: [0.85, 0.85, 0.88, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.92, 0.92, 0.95, 1.0])!,
    ]
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: gradientColors as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: h),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // -- Subtle decorative circles --
    context.saveGState()
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.03])!)
    context.fillEllipse(in: CGRect(x: -80, y: h - 200, width: 300, height: 300))
    context.fillEllipse(in: CGRect(x: w - 150, y: -80, width: 280, height: 280))
    context.restoreGState()

    // -- Arrow from app icon area to Applications area --
    let arrowY = h / 2 + 10
    let arrowStartX = w / 2 - 80
    let arrowEndX = w / 2 + 80
    let arrowHeadSize: CGFloat = 12

    context.saveGState()
    // Arrow line (dashed)
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.3])!)
    context.setLineWidth(2.5)
    context.setLineCap(.round)
    context.setLineDash(phase: 0, lengths: [8, 6])
    context.move(to: CGPoint(x: arrowStartX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY))
    context.strokePath()

    // Arrow head (solid)
    context.setLineDash(phase: 0, lengths: [])
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.3])!)
    context.move(to: CGPoint(x: arrowEndX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY + arrowHeadSize / 2 + 2))
    context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY - arrowHeadSize / 2 - 2))
    context.closePath()
    context.fillPath()
    context.restoreGState()

    // -- "Drag to Applications" label via CoreText --
    let fontSize: CGFloat = 13
    let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
    let labelString = "Drag to Applications"
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.4])!,
    ]
    let attrString = CFAttributedStringCreate(nil, labelString as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrString)
    let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    context.saveGState()
    context.textMatrix = .identity
    let textX = (w - textBounds.width) / 2
    let textY = arrowY - 28
    context.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, context)
    context.restoreGState()

    guard let cgImage = context.makeImage() else {
        fatalError("Failed to create CGImage")
    }
    return cgImage
}

// MARK: - Save

let cgImage = generateBackground(width: width, height: height)
let url = URL(fileURLWithPath: outputPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
    fatalError("Failed to create image destination")
}

CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    fatalError("Failed to write PNG")
}

print("DMG background saved to \(outputPath) (\(width)×\(height))")
