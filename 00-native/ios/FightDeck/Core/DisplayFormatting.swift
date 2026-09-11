//
// DisplayFormatting.swift
// FightDeck
//
// Created by FightDeck on 22.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

private enum DateParsers {
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

    var displayMethod: String {
        replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }
}

extension Int {
    var formattedDuration: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }
}
