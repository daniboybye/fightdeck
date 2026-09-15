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

public enum TapeAdvantage: String, Sendable {
    case red
    case blue
    case even
}

public struct TapeRow: Sendable {
    public let label: String
    public let red: String
    public let blue: String
    public let advantage: TapeAdvantage

    public init(label: String, red: String, blue: String, advantage: TapeAdvantage) {
        self.label = label
        self.red = red
        self.blue = blue
        self.advantage = advantage
    }
}

public struct TaleOfTheTape: Sendable {
    public let rows: [TapeRow]
    public let edgeSummary: String?

    public init(rows: [TapeRow], edgeSummary: String?) {
        self.rows = rows
        self.edgeSummary = edgeSummary
    }
}

public enum Tape {
    private static let missing = "—"

    public static func rows(red: Fighter?, blue: Fighter?) -> [TapeRow] {
        let redHeight = red?.heightCm
        let blueHeight = blue?.heightCm
        let redReach = red?.reachIn
        let blueReach = blue?.reachIn

        return [
            TapeRow(
                label: "RECORD",
                red: red?.record.display ?? missing,
                blue: blue?.record.display ?? missing,
                advantage: recordAdvantage(red: red, blue: blue)
            ),
            TapeRow(
                label: "HEIGHT",
                red: measure(redHeight, unit: "cm"),
                blue: measure(blueHeight, unit: "cm"),
                advantage: tallerAdvantage(redHeight, blueHeight)
            ),
            TapeRow(
                label: "REACH",
                red: measure(redReach, unit: "in"),
                blue: measure(blueReach, unit: "in"),
                advantage: tallerAdvantage(redReach, blueReach)
            ),
            TapeRow(
                label: "STANCE",
                red: red.map { text($0.stance.map(Display.humanise)) } ?? missing,
                blue: blue.map { text($0.stance.map(Display.humanise)) } ?? missing,
                advantage: .even
            ),
            TapeRow(
                label: "COUNTRY",
                red: red.map { text($0.country) } ?? missing,
                blue: blue.map { text($0.country) } ?? missing,
                advantage: .even
            ),
        ]
    }

    public static func edgeSummary(red: Fighter?, blue: Fighter?) -> String? {
        guard let red, let blue, let redReach = red.reachIn, let blueReach = blue.reachIn else {
            return nil
        }
        if redReach == blueReach {
            return "Even on reach"
        }
        if redReach > blueReach {
            return "\(red.name) has a \(redReach - blueReach) in reach advantage"
        }
        return "\(blue.name) has a \(blueReach - redReach) in reach advantage"
    }

    public static func taleOfTheTape(red: Fighter?, blue: Fighter?) -> TaleOfTheTape {
        TaleOfTheTape(rows: rows(red: red, blue: blue), edgeSummary: edgeSummary(red: red, blue: blue))
    }

    private static func measure(_ value: Int?, unit: String) -> String {
        guard let value else { return missing }
        return "\(value) \(unit)"
    }

    private static func tallerAdvantage(_ red: Int?, _ blue: Int?) -> TapeAdvantage {
        guard let red, let blue else { return .even }
        if red > blue { return .red }
        if blue > red { return .blue }
        return .even
    }

    private static func recordAdvantage(red: Fighter?, blue: Fighter?) -> TapeAdvantage {
        guard let red, let blue else { return .even }
        if red.record.wins > blue.record.wins { return .red }
        if blue.record.wins > red.record.wins { return .blue }
        return .even
    }

    private static func text(_ value: String?) -> String {
        value ?? missing
    }
}
