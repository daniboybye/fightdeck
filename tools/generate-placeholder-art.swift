#!/usr/bin/env swift
//
// Generate portrait and poster placeholders for the dataset.
//
//     swift tools/generate-placeholder-art.swift
//
// UFC photography cannot be redistributed, and hotlinking ufc.com would make the demo
// depend on a CDN that may answer 403 and on conference wifi. So the apps load real
// images over HTTP from a host we control, and those images are these: deterministic,
// generated, and ours.
//
// They still exercise everything the comparison cares about — async fetch, decode,
// downsample, memory and disk cache — so Kingfisher, Coil and RN's Image are doing
// identical work in all five apps.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Layout

private enum Layout {
    static let portraitSize = CGSize(width: 512, height: 512)
    static let posterSize = CGSize(width: 1024, height: 576)
    static let newsSize = CGSize(width: 1024, height: 576)
    static let portraitFontRatio: CGFloat = 0.34
    static let posterTitleRatio: CGFloat = 0.085
    static let posterSubtitleRatio: CGFloat = 0.045
    static let newsHeadlineRatio: CGFloat = 0.072
    static let newsKickerRatio: CGFloat = 0.038
    static let newsInset: CGFloat = 56
}

// MARK: - Palette

/// A muted, high-contrast palette. Deterministic per fighter so a portrait never changes
/// between runs — a regenerated dataset that reshuffles every colour would show up as
/// noise in screenshot diffs and snapshot tests.
private let palette: [(CGFloat, CGFloat, CGFloat)] = [
    (0.11, 0.14, 0.20), (0.16, 0.12, 0.20), (0.10, 0.18, 0.19),
    (0.20, 0.13, 0.13), (0.13, 0.17, 0.13), (0.18, 0.16, 0.11),
    (0.12, 0.15, 0.23), (0.19, 0.11, 0.17),
]

/// FNV-1a. Any stable hash would do; Swift's `hashValue` is explicitly seeded per process
/// and would hand out different colours on every run.
private func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x1000_0000_01b3
    }
    return hash
}

private func initials(for name: String) -> String {
    let parts = name.split(separator: " ").filter { !$0.isEmpty }
    let letters = parts.prefix(2).compactMap { $0.first }
    return String(letters).uppercased()
}

// MARK: - Drawing

private func makeContext(_ size: CGSize) -> CGContext? {
    CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

private func fillGradient(_ context: CGContext, size: CGSize, seed: UInt64) {
    let base = palette[Int(seed % UInt64(palette.count))]
    let colors = [
        CGColor(red: base.0, green: base.1, blue: base.2, alpha: 1),
        CGColor(red: base.0 * 1.9, green: base.1 * 1.9, blue: base.2 * 1.9, alpha: 1),
    ] as CFArray

    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    ) else { return }

    context.drawLinearGradient(
        gradient,
        start: .zero,
        end: CGPoint(x: size.width, y: size.height),
        options: []
    )
}

private func draw(
    _ text: String,
    in context: CGContext,
    size: CGSize,
    fontSize: CGFloat,
    weight: CGFloat,
    centerY: CGFloat,
    alpha: CGFloat = 1
) {
    let descriptor = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: "Helvetica Neue",
        kCTFontTraitsAttribute: [kCTFontWeightTrait: weight],
    ] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)

    // The CoreText keys rather than the AppKit conveniences: this script imports no UI
    // framework, so `.font` and `.foregroundColor` do not exist here.
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            CGColor(red: 1, green: 1, blue: 1, alpha: alpha),
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    context.textPosition = CGPoint(
        x: (size.width - bounds.width) / 2 - bounds.minX,
        y: centerY - bounds.height / 2 - bounds.minY
    )
    CTLineDraw(line, context)
}

/// Wraps `text` inside a box anchored at the bottom-left, growing upwards, and returns the
/// height it consumed so the caller can stack the next line above it.
@discardableResult
private func drawWrapped(
    _ text: String,
    in context: CGContext,
    box: CGRect,
    fontSize: CGFloat,
    weight: CGFloat,
    alpha: CGFloat = 1
) -> CGFloat {
    let descriptor = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: "Helvetica Neue",
        kCTFontTraitsAttribute: [kCTFontWeightTrait: weight],
    ] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)

    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            CGColor(red: 1, green: 1, blue: 1, alpha: alpha),
    ])

    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let constraint = CGSize(width: box.width, height: .greatestFiniteMagnitude)
    let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter, CFRange(location: 0, length: 0), nil, constraint, nil
    )

    // CoreText lays out from the top of its path, so the path has to be positioned at the
    // measured height for the block to sit on `box.minY`.
    let path = CGPath(
        rect: CGRect(x: box.minX, y: box.minY, width: box.width, height: fitted.height),
        transform: nil
    )
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    CTFrameDraw(frame, context)
    return fitted.height
}

/// JPEG rather than PNG, for two reasons. Gradients compress badly as PNG — the same
/// forty portraits weigh about ten megabytes lossless and well under one as JPEG. And
/// photographs on a real sports app are JPEG, so the decode path the apps exercise
/// matches what they would do in production.
private func write(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
    ) else {
        throw Failure("cannot create JPEG destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationLossyCompressionQuality: 0.85,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw Failure("failed writing \(url.lastPathComponent)")
    }
}

private struct Failure: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

// MARK: - Renderers

private func renderPortrait(name: String, id: String, to url: URL) throws {
    let size = Layout.portraitSize
    guard let context = makeContext(size) else { throw Failure("no context for \(id)") }

    let seed = stableHash(id)
    fillGradient(context, size: size, seed: seed)

    // A faint corner wedge so the placeholders do not read as flat colour swatches.
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.04))
    context.move(to: CGPoint(x: 0, y: size.height))
    context.addLine(to: CGPoint(x: size.width, y: size.height))
    context.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
    context.closePath()
    context.fillPath()

    draw(
        initials(for: name),
        in: context,
        size: size,
        fontSize: size.height * Layout.portraitFontRatio,
        weight: 0.4,
        centerY: size.height * 0.5
    )

    guard let image = context.makeImage() else { throw Failure("no image for \(id)") }
    try write(image, to: url)
}

private func renderPoster(title: String, subtitle: String, id: String, to url: URL) throws {
    let size = Layout.posterSize
    guard let context = makeContext(size) else { throw Failure("no context for \(id)") }

    fillGradient(context, size: size, seed: stableHash(id))

    draw(
        title.uppercased(),
        in: context,
        size: size,
        fontSize: size.height * Layout.posterTitleRatio,
        weight: 0.5,
        centerY: size.height * 0.56
    )
    draw(
        subtitle,
        in: context,
        size: size,
        fontSize: size.height * Layout.posterSubtitleRatio,
        weight: 0,
        centerY: size.height * 0.42,
        alpha: 0.7
    )

    guard let image = context.makeImage() else { throw Failure("no image for \(id)") }
    try write(image, to: url)
}

/// Every article used to reuse its event poster, so a news feed of eight stories showed the
/// same two images. Seeding on the article id gives each one its own composition.
///
/// Deliberately text-free: this image stands in for a press photo, and the row already renders
/// the kicker and headline as real text. Baking them into the bitmap too printed everything
/// twice and made the feed look like a slide deck.
private func renderNewsCard(id: String, to url: URL) throws {
    let size = Layout.newsSize
    guard let context = makeContext(size) else { throw Failure("no context for \(id)") }

    let seed = stableHash(id)
    fillGradient(context, size: size, seed: seed)

    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    context.move(to: .zero)
    context.addLine(to: CGPoint(x: size.width, y: 0))
    context.addLine(to: CGPoint(x: size.width, y: size.height * 0.55))
    context.addLine(to: CGPoint(x: 0, y: size.height * 0.78))
    context.closePath()
    context.fillPath()

    // Two overlapping discs, placed from the seed, give each story a recognisable silhouette
    // without any two articles colliding on the same composition.
    let radius = size.height * 0.34
    let centers = [
        CGPoint(
            x: size.width * (0.22 + CGFloat(seed % 17) / 60),
            y: size.height * (0.34 + CGFloat((seed >> 8) % 13) / 55)
        ),
        CGPoint(
            x: size.width * (0.58 + CGFloat((seed >> 16) % 19) / 70),
            y: size.height * (0.52 + CGFloat((seed >> 24) % 11) / 50)
        ),
    ]
    for (index, center) in centers.enumerated() {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: index == 0 ? 0.07 : 0.05))
        context.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    guard let image = context.makeImage() else { throw Failure("no image for \(id)") }
    try write(image, to: url)
}

// MARK: - Entry point

private struct Fighters: Decodable {
    struct Fighter: Decodable { let id: String; let name: String }
    let fighters: [Fighter]
}

private struct News: Decodable {
    struct Article: Decodable { let id: String; let eventId: String; let headline: String }
    let news: [Article]
}

private struct Events: Decodable {
    struct Event: Decodable { let id: String; let name: String; let venue: String; let date: String }
    let events: [Event]
}

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let datasetDir = repoRoot.appendingPathComponent("dataset")

private let fighters = try JSONDecoder().decode(
    Fighters.self,
    from: Data(contentsOf: datasetDir.appendingPathComponent("fighters.json"))
)
private let events = try JSONDecoder().decode(
    Events.self,
    from: Data(contentsOf: datasetDir.appendingPathComponent("events.json"))
)

for fighter in fighters.fighters {
    let url = datasetDir.appendingPathComponent("assets/fighters/\(fighter.id).jpg")
    try renderPortrait(name: fighter.name, id: fighter.id, to: url)
}
print("  \(fighters.fighters.count) portraits")

for event in events.events {
    let url = datasetDir.appendingPathComponent("assets/events/\(event.id).jpg")
    try renderPoster(
        title: event.name,
        subtitle: "\(event.venue) · \(event.date)",
        id: event.id,
        to: url
    )
}
print("  \(events.events.count) posters")

private let news = try JSONDecoder().decode(
    News.self,
    from: Data(contentsOf: datasetDir.appendingPathComponent("news.json"))
)
for article in news.news {
    let url = datasetDir.appendingPathComponent("assets/news/\(article.id).jpg")
    try renderNewsCard(id: article.id, to: url)
}
print("  \(news.news.count) news cards")
