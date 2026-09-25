//
// DisplayFormatting.swift
// FightDeck
//
// Created by FightDeck on 22.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// Both parsers are reused: building one per cell shows up while scrolling long lists. They are
/// configured once and only ever parsed from afterwards, which Foundation's date formatters have
/// supported concurrently since iOS 7 — the compiler cannot see that, hence the explicit opt-out.
private enum DateParsers {
    /// Dataset dates are plain `yyyy-MM-dd`, which `ISO8601DateFormatter` only accepts with
    /// a time component bolted on.
    nonisolated(unsafe) static let day: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let timestamp = ISO8601DateFormatter()
}

extension String {
    var formattedEventDate: String {
        guard let date = DateParsers.day.date(from: self + "T12:00:00Z") else { return self }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedRelativeDate: String {
        guard let date = DateParsers.timestamp.date(from: self) else { return self }
        return date.formatted(.relative(presentation: .named))
    }
}
