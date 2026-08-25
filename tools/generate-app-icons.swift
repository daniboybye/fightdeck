#!/usr/bin/env swift
//
// Generate distinct launcher icons for every fightdeck host app.
//
//     swift tools/generate-app-icons.swift
//
// Each pair shares a large approach number on the app's dark background, tinted with
// one of the design-token accent colours so five icons on one home screen stay
// separable at a glance during the talk demo.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Design tokens

private enum Tokens {
    /// Matches `DesignTokens.ColorToken` / `Tokens.kt` background.
    static let background = (r: CGFloat(0.043), g: CGFloat(0.055), b: CGFloat(0.078)) // #0B0E14

    static let accent = (r: CGFloat(0.910), g: CGFloat(0.702), b: CGFloat(0.235)) // #E8B33C
    static let cornerBlue = (r: CGFloat(0.290), g: CGFloat(0.498), b: CGFloat(0.851)) // #4A7FD9
    static let cornerRed = (r: CGFloat(0.851), g: CGFloat(0.290), b: CGFloat(0.290)) // #D94A4A
    static let positive = (r: CGFloat(0.239), g: CGFloat(0.839), b: CGFloat(0.549)) // #3DD68C
    static let negative = (r: CGFloat(0.949), g: CGFloat(0.329), b: CGFloat(0.357)) // #F2545B
}

// MARK: - Approaches

private struct Approach {
    let folder: String
    let number: String
    let accent: (r: CGFloat, g: CGFloat, b: CGFloat)

    static let all: [Approach] = [
        Approach(folder: "00-native", number: "0", accent: Tokens.accent),
        Approach(folder: "01-core-swift", number: "1", accent: Tokens.cornerBlue),
        Approach(folder: "02-core-rust", number: "2", accent: Tokens.cornerRed),
        Approach(folder: "03-sdk-rn", number: "3", accent: Tokens.positive),
        Approach(folder: "04-sdk-skip", number: "4", accent: Tokens.negative),
    ]
}

// MARK: - Android densities

private struct Density {
    let folder: String
    let legacySide: Int
    let adaptiveSide: Int
}

private let densities: [Density] = [
    Density(folder: "mipmap-mdpi", legacySide: 48, adaptiveSide: 108),
    Density(folder: "mipmap-hdpi", legacySide: 72, adaptiveSide: 162),
    Density(folder: "mipmap-xhdpi", legacySide: 96, adaptiveSide: 216),
    Density(folder: "mipmap-xxhdpi", legacySide: 144, adaptiveSide: 324),
    Density(folder: "mipmap-xxxhdpi", legacySide: 192, adaptiveSide: 432),
]

// MARK: - Drawing

private struct Failure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private func makeContext(_ size: CGSize, alphaOnly: Bool = false) -> CGContext? {
    CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: (alphaOnly
            ? CGImageAlphaInfo.premultipliedFirst.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue)
    )
}

private func drawCenteredNumber(
    _ text: String,
    in context: CGContext,
    size: CGSize,
    accent: (r: CGFloat, g: CGFloat, b: CGFloat),
    scaleForSafeZone: Bool
) {
    let side = min(size.width, size.height)
    // Adaptive foregrounds crop to a circle; keep the digit inside ~66% of the canvas.
    let usable = side * (scaleForSafeZone ? 0.52 : 0.62)
    let fontSize = usable * 0.95

    let descriptor = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: "Helvetica Neue",
        kCTFontTraitsAttribute: [kCTFontWeightTrait: 0.35],
    ] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)

    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            CGColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    context.textPosition = CGPoint(
        x: (size.width - bounds.width) / 2 - bounds.minX,
        y: (size.height - bounds.height) / 2 - bounds.minY
    )
    CTLineDraw(line, context)
}

private func drawAccentStripe(
    in context: CGContext,
    size: CGSize,
    accent: (r: CGFloat, g: CGFloat, b: CGFloat)
) {
    let stripeHeight = size.height * 0.08
    context.setFillColor(CGColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size.width, height: stripeHeight))
}

private func renderFullIcon(
    approach: Approach,
    side: Int
) throws -> CGImage {
    let size = CGSize(width: side, height: side)
    guard let context = makeContext(size) else {
        throw Failure("no context for \(approach.folder) @ \(side)pt")
    }

    context.setFillColor(CGColor(
        red: Tokens.background.r,
        green: Tokens.background.g,
        blue: Tokens.background.b,
        alpha: 1
    ))
    context.fill(CGRect(origin: .zero, size: size))
    drawAccentStripe(in: context, size: size, accent: approach.accent)
    drawCenteredNumber(
        approach.number,
        in: context,
        size: size,
        accent: approach.accent,
        scaleForSafeZone: false
    )

    guard let image = context.makeImage() else {
        throw Failure("no full icon for \(approach.folder) @ \(side)pt")
    }
    return image
}

private func renderAdaptiveBackground(side: Int) throws -> CGImage {
    let size = CGSize(width: side, height: side)
    guard let context = makeContext(size) else {
        throw Failure("no adaptive background context @ \(side)pt")
    }
    context.setFillColor(CGColor(
        red: Tokens.background.r,
        green: Tokens.background.g,
        blue: Tokens.background.b,
        alpha: 1
    ))
    context.fill(CGRect(origin: .zero, size: size))
    guard let image = context.makeImage() else {
        throw Failure("no adaptive background @ \(side)pt")
    }
    return image
}

private func renderAdaptiveForeground(
    approach: Approach,
    side: Int
) throws -> CGImage {
    let size = CGSize(width: side, height: side)
    guard let context = makeContext(size, alphaOnly: true) else {
        throw Failure("no adaptive foreground context for \(approach.folder) @ \(side)pt")
    }
    context.clear(CGRect(origin: .zero, size: size))
    drawCenteredNumber(
        approach.number,
        in: context,
        size: size,
        accent: approach.accent,
        scaleForSafeZone: true
    )
    guard let image = context.makeImage() else {
        throw Failure("no adaptive foreground for \(approach.folder) @ \(side)pt")
    }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw Failure("cannot create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw Failure("failed writing \(url.lastPathComponent)")
    }
}

// MARK: - Platform writers

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private let iosContentsJSON = """
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

private let adaptiveIconXML = """
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

private let colorsXML = """
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B0E14</color>
</resources>
"""

private let assetsCatalogContentsJSON = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

private func writeIOSIcons(for approach: Approach) throws {
    let catalog = repoRoot
        .appendingPathComponent(approach.folder)
        .appendingPathComponent("ios/FightDeck/Assets.xcassets")
    let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")

    let icon = try renderFullIcon(approach: approach, side: 1024)
    try writePNG(icon, to: iconSet.appendingPathComponent("AppIcon-1024.png"))
    try iosContentsJSON.write(
        to: iconSet.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
    try assetsCatalogContentsJSON.write(
        to: catalog.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
}

private func writeAndroidIcons(for approach: Approach) throws {
    let resRoot = repoRoot
        .appendingPathComponent(approach.folder)
        .appendingPathComponent("android/app/src/main/res")

    try FileManager.default.createDirectory(
        at: resRoot.appendingPathComponent("values"),
        withIntermediateDirectories: true
    )
    try colorsXML.write(
        to: resRoot.appendingPathComponent("values/colors.xml"),
        atomically: true,
        encoding: .utf8
    )

    let adaptiveDir = resRoot.appendingPathComponent("mipmap-anydpi-v26")
    try FileManager.default.createDirectory(
        at: adaptiveDir,
        withIntermediateDirectories: true
    )
    try adaptiveIconXML.write(
        to: adaptiveDir.appendingPathComponent("ic_launcher.xml"),
        atomically: true,
        encoding: .utf8
    )
    try adaptiveIconXML.write(
        to: adaptiveDir.appendingPathComponent("ic_launcher_round.xml"),
        atomically: true,
        encoding: .utf8
    )

    for density in densities {
        let folder = resRoot.appendingPathComponent(density.folder)
        let legacy = try renderFullIcon(approach: approach, side: density.legacySide)
        try writePNG(legacy, to: folder.appendingPathComponent("ic_launcher.png"))
        try writePNG(legacy, to: folder.appendingPathComponent("ic_launcher_round.png"))

        let background = try renderAdaptiveBackground(side: density.adaptiveSide)
        try writePNG(background, to: folder.appendingPathComponent("ic_launcher_background.png"))

        let foreground = try renderAdaptiveForeground(
            approach: approach,
            side: density.adaptiveSide
        )
        try writePNG(foreground, to: folder.appendingPathComponent("ic_launcher_foreground.png"))
    }
}

// MARK: - Entry point

for approach in Approach.all {
    try writeIOSIcons(for: approach)
    try writeAndroidIcons(for: approach)
    print("  \(approach.folder)")
}
print("  \(Approach.all.count) approaches × iOS + Android")
