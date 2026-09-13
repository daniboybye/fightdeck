//
// Display.swift
// FightEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

public enum Display {
    public static let segmentOrder = [
        "main",
        "main_card",
        "prelim",
        "prelims",
        "early_prelim",
        "early_prelims",
    ]

    public static func humanise(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
        guard let first = spaced.first else { return "" }
        return String(first).uppercased() + spaced.dropFirst()
    }

    public static func duration(totalSeconds: Int) -> String {
        String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    public static func weightClass(_ raw: String) -> String {
        humanise(raw)
    }

    public static func boutHeadline(weightClassRaw: String, titleFight: Bool, scheduledRounds: Int) -> String {
        let base = weightClassRaw.replacingOccurrences(of: "_", with: " ").uppercased()
        let title = titleFight ? " · TITLE" : ""
        return "\(base)\(title) · \(scheduledRounds) RNDS"
    }

    public static func resultLine(winnerName: String, method: String, endRound: Int, endTime: String) -> String {
        "\(winnerName) · \(humanise(method)) · R\(endRound) \(endTime)"
    }

    public static func recordDisplay(wins: Int, losses: Int, draws: Int, noContests: Int) -> String {
        if noContests > 0 {
            return "\(wins)-\(losses)-\(draws) (\(noContests) NC)"
        }
        return "\(wins)-\(losses)-\(draws)"
    }

    public static func segmentTitle(_ segment: String) -> String {
        switch segment {
        case "main": "Main Event"
        case "main_card": "Main Card"
        case "prelim", "prelims": "Prelims"
        default: "Early Prelims"
        }
    }

    public static func segmentRank(_ segment: String) -> Int {
        segmentOrder.firstIndex(of: segment) ?? segmentOrder.count
    }
}
