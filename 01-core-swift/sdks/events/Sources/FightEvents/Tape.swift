//
// Tape.swift
// FightEvents
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public struct TapeRow: Sendable {
    public let label: String
    public let red: String
    public let blue: String
}

public struct TaleOfTheTape: Sendable {
    public let rows: [TapeRow]
}

public enum Tape {
    private static let missing = "—"

    public static func rows(red: Fighter?, blue: Fighter?) -> [TapeRow] {
        [
            TapeRow(
                label: "RECORD",
                red: red?.record.display ?? missing,
                blue: blue?.record.display ?? missing
            ),
            TapeRow(
                label: "HEIGHT",
                red: measure(red?.heightCm, unit: "cm"),
                blue: measure(blue?.heightCm, unit: "cm")
            ),
            TapeRow(
                label: "REACH",
                red: measure(red?.reachIn, unit: "in"),
                blue: measure(blue?.reachIn, unit: "in")
            ),
            TapeRow(
                label: "STANCE",
                red: red.map { text($0.stance.map(Display.humanise)) } ?? missing,
                blue: blue.map { text($0.stance.map(Display.humanise)) } ?? missing
            ),
            TapeRow(
                label: "COUNTRY",
                red: red.map { text($0.country) } ?? missing,
                blue: blue.map { text($0.country) } ?? missing
            ),
        ]
    }

    public static func taleOfTheTape(red: Fighter?, blue: Fighter?) -> TaleOfTheTape {
        TaleOfTheTape(rows: rows(red: red, blue: blue))
    }

    private static func measure(_ value: Int?, unit: String) -> String {
        guard let value else { return missing }
        return "\(value) \(unit)"
    }

    private static func text(_ value: String?) -> String {
        value ?? missing
    }
}
