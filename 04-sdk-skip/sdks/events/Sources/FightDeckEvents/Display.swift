//
// Display.swift
// FightDeckEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import Foundation

/// The strings both apps put on screen for a bout, an event date or a clip length.
///
/// Written against `DateFormatter` and `RelativeDateTimeFormatter` rather than the newer
/// `.formatted(date:time:)` and `.relative(presentation:)` styles: Skip's Foundation covers the
/// ObjC-era formatters but `FormatStyle` only exists for numbers, so the modern spelling
/// compiles on iOS and then has nothing to transpile to.
public enum Display {
    /// The formatters are reused: building one per cell shows up while scrolling long lists.
    /// They are configured once and only ever read from afterwards. `DateFormatter` is `Sendable`
    /// and needs nothing extra; the other two are not, and the compiler cannot see that a
    /// parse-only formatter has been safe to share since iOS 7 — hence the explicit opt-out.
    private enum Formatters {
        /// Dataset dates are plain `yyyy-MM-dd`. A fixed locale parses them; the display
        /// formatter below is the one that follows the user's.
        static let dayParser: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter
        }()

        static let dayDisplay: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }()

        nonisolated(unsafe) static let timestampParser = ISO8601DateFormatter()

        nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            return formatter
        }()
    }

    /// Both spellings of each undercard segment: the dataset uses the singular, older exports
    /// used the plural, and a bout whose segment is not listed sorts last rather than vanishing.
    public static let segmentOrder = [
        "main",
        "main_card",
        "prelim",
        "prelims",
        "early_prelim",
        "early_prelims",
    ]

    /// `split_decision` reads as a database column; `Split decision` reads as a result.
    public static func humanise(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
        guard let first = spaced.first else { return "" }
        return String(first).uppercased() + String(spaced.dropFirst())
    }

    public static func eventDate(_ raw: String) -> String {
        guard let date = Formatters.dayParser.date(from: raw) else { return raw }
        return Formatters.dayDisplay.string(from: date)
    }

    public static func relativeDate(_ raw: String) -> String {
        guard let date = Formatters.timestampParser.date(from: raw) else { return raw }
        return Formatters.relative.localizedString(for: date, relativeTo: Date())
    }

    /// Clock style rather than a units style, which rounds a 3:24 clip to "3 min" and drops the
    /// seconds every media player shows.
    public static func duration(totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public static func resultLine(winnerName: String, method: String, endRound: Int, endTime: String) -> String {
        "\(winnerName) · \(humanise(method)) · R\(endRound) \(endTime)"
    }

    public static func segmentTitle(_ segment: String) -> String {
        switch segment {
        case "main": "Main Event"
        case "main_card": "Main Card"
        case "prelim", "prelims": "Prelims"
        default: "Early Prelims"
        }
    }

    private static func segmentRank(_ segment: String) -> Int {
        segmentOrder.firstIndex(of: segment) ?? segmentOrder.count
    }

    /// The card, split into the sections a fight night is actually billed as. Grouping once
    /// here rather than in the screen is what keeps the sort off the render path: a view that
    /// asks a computed property per segment re-groups and re-sorts the whole card each time.
    public static func cardSections(for bouts: [Bout]) -> [CardSection] {
        var grouped: [String: [Bout]] = [:]
        for bout in bouts {
            grouped[bout.segment, default: []].append(bout)
        }
        let segments = grouped.keys.sorted { segmentRank($0) < segmentRank($1) }
        return segments.compactMap { segment in
            guard var section = grouped[segment], !section.isEmpty else { return nil }
            section.sort { $0.order < $1.order }
            return CardSection(title: segmentTitle(segment), bouts: section)
        }
    }
}

/// One billed block of a card — "Main Event", "Prelims" — with its bouts already in order.
public struct CardSection: Identifiable, Sendable {
    public let title: String
    public let bouts: [Bout]

    public var id: String { title }

    public init(title: String, bouts: [Bout]) {
        self.title = title
        self.bouts = bouts
    }
}
