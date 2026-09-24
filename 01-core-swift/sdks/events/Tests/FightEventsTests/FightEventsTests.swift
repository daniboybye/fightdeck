//
// FightEventsTests.swift
// FightEventsTests
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation
import Testing
@testable import FightEvents

@Suite("FightEvents")
struct FightEventsTests {
    @Test("humanises contract codes")
    func humanise() {
        #expect(Display.humanise("split_decision") == "Split decision")
        #expect(Display.humanise("tko") == "Tko")
        #expect(Display.humanise("") == "")
    }

    @Test("formats clock durations")
    func duration() {
        #expect(Display.duration(totalSeconds: 204) == "3:24")
        #expect(Display.duration(totalSeconds: 61) == "1:01")
        #expect(Display.duration(totalSeconds: 1800) == "30:00")
    }

    @Test("records show no contests only when present")
    func recordDisplay() {
        #expect(Display.recordDisplay(wins: 27, losses: 5, draws: 0, noContests: 0) == "27-5-0")
        #expect(Display.recordDisplay(wins: 27, losses: 5, draws: 0, noContests: 1) == "27-5-0 (1 NC)")
    }

    @Test("main event sorts first")
    func segmentRank() {
        #expect(Display.segmentRank("main") < Display.segmentRank("prelim"))
        #expect(Display.segmentRank("prelim") < Display.segmentRank("early_prelim"))
    }

    @Test("Catalog.parse loads the dataset")
    func catalogParse() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dataset = repoRoot.appendingPathComponent("dataset")
        let eventsJSON = try String(contentsOf: dataset.appendingPathComponent("events.json"))
        let fightersJSON = try String(contentsOf: dataset.appendingPathComponent("fighters.json"))
        let catalog = try Catalog.parse(eventsJSON: eventsJSON, fightersJSON: fightersJSON)
        #expect(!catalog.allEvents().isEmpty)
        #expect(!catalog.boutIndex().isEmpty)
    }

    @Test("Catalog.load reads the catalogue, news and media from the dataset root")
    func catalogLoad() throws {
        let dataset = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../../../dataset")
            .standardizedFileURL
        let catalog = try Catalog.load(datasetRoot: dataset)
        #expect(!catalog.allEvents().isEmpty)
        #expect(try !catalog.news().isEmpty)
        #expect(try catalog.media().allSatisfy { $0.durationSeconds > 0 })
        #expect(throws: CatalogError.self) {
            try Catalog.load(datasetRoot: URL(fileURLWithPath: "/nonexistent/dataset"))
        }
    }

    @Test("tale of the tape names reach advantage")
    func tapeEdgeSummary() {
        let red = Fighter(
            id: "red",
            name: "Red",
            nickname: nil,
            country: "Testland",
            heightCm: 180,
            reachIn: 70,
            stance: "orthodox",
            record: FighterRecord(wins: 27, losses: 0, draws: 0, noContests: 0, display: "27-0-0"),
            portrait: ""
        )
        let blue = Fighter(
            id: "blue",
            name: "Blue",
            nickname: nil,
            country: "Testland",
            heightCm: 175,
            reachIn: 74,
            stance: "orthodox",
            record: FighterRecord(wins: 20, losses: 0, draws: 0, noContests: 0, display: "20-0-0"),
            portrait: ""
        )
        #expect(Tape.edgeSummary(red: red, blue: blue) == "Blue has a 4 in reach advantage")
    }
}
