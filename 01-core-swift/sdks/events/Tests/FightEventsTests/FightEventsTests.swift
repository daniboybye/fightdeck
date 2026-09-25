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

    @Test("main event sorts first")
    func segmentRank() {
        #expect(Display.segmentRank("main") < Display.segmentRank("prelim"))
        #expect(Display.segmentRank("prelim") < Display.segmentRank("early_prelim"))
    }

    private static let dataset = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../../../../dataset")
        .standardizedFileURL

    @Test("Catalog.load reads the catalogue, news and media from the dataset root")
    func catalogLoad() throws {
        let catalog = try Catalog.load(datasetRoot: Self.dataset)
        #expect(!catalog.allEvents().isEmpty)
        #expect(!catalog.boutIndex().isEmpty)
        let lastBout = try #require(catalog.allEvents().last?.bouts.last)
        #expect(catalog.bout(id: lastBout.id)?.order == lastBout.order)
        #expect(try !catalog.news().isEmpty)
        #expect(try catalog.media().allSatisfy { $0.durationSeconds > 0 })
        #expect(throws: CatalogError.self) {
            try Catalog.load(datasetRoot: URL(fileURLWithPath: "/nonexistent/dataset"))
        }
    }

    @Test("the card, the bout and the fighter arrive worded for the screen")
    func presentation() throws {
        let catalog = try Catalog.load(datasetRoot: Self.dataset)
        let event = try #require(catalog.eventSummaries().first { $0.id == "ufc-freedom-250" })
        #expect(event.locationLine == "South Lawn of the White House · Washington, D.C.")

        let sections = catalog.cardSections(eventID: event.id)
        #expect(sections.first?.title == "Main Event")
        #expect(sections.map(\.bouts.count).reduce(0, +) == event.boutCount)

        let bout = try #require(catalog.boutSummary(id: "ufc-freedom-250-bout-01"))
        #expect(bout.headline == "LIGHTWEIGHT · TITLE · 5 RNDS")
        #expect(bout.methodDisplay == "Tko")
        #expect(bout.endedLine == "Round 4 · 5:00")
        #expect(bout.red.oddsLabel == "1.20")
        #expect(bout.red.impliedProbability == "0.8333")
        #expect(bout.red.recordDisplay == "17-0-0")

        let fighter = try #require(catalog.fighterSummary(id: "ilia-topuria"))
        #expect(fighter.physicalRows.map(\.value) == ["170 cm", "69 in", "Orthodox", "Spain"])
    }
}
