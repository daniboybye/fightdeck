//
// Display.swift
// FightEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightCore
#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

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
        Humanise.code(raw)
    }

    public static func duration(totalSeconds: Int) -> String {
        let seconds = totalSeconds % 60
        #if os(Android)
        // String(format:) is another piece of Foundation that Android would pay ICU for.
        // Seconds never exceed two digits, so the padding is a single comparison.
        return "\(totalSeconds / 60):\(seconds < 10 ? "0" : "")\(seconds)"
        #else
        return String(format: "%d:%02d", totalSeconds / 60, seconds)
        #endif
    }

    public static func weightClass(_ raw: String) -> String {
        humanise(raw)
    }

    public static func boutHeadline(weightClassRaw: String, titleFight: Bool, scheduledRounds: Int) -> String {
        let base = Humanise.spaced(weightClassRaw).uppercased()
        let title = titleFight ? " · TITLE" : ""
        return "\(base)\(title) · \(scheduledRounds) RNDS"
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

    public static func segmentRank(_ segment: String) -> Int {
        segmentOrder.firstIndex(of: segment) ?? segmentOrder.count
    }
}
