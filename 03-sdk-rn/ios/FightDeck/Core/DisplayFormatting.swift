//
// DisplayFormatting.swift
// FightDeck
//
// Created by FightDeck on 22.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

extension String {
    /// Dataset dates are plain `yyyy-MM-dd`, which `ISO8601DateFormatter` only accepts with
    /// a time component bolted on.
    var formattedEventDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: self + "T12:00:00Z") else { return self }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedRelativeDate: String {
        guard let date = ISO8601DateFormatter().date(from: self) else { return self }
        return date.formatted(.relative(presentation: .named))
    }

    /// `split_decision` reads as a database column; `Split decision` reads as a result.
    var displayMethod: String {
        replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }
}

extension Int {
    /// Clock style rather than `.units`, which rounds a 3:24 clip to "3 min" and drops the
    /// seconds every media player shows.
    var formattedDuration: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }
}
