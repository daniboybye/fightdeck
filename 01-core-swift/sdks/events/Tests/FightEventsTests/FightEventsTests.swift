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

    @Test("Catalog.load reads the catalogue, news and media from the dataset root")
    func catalogLoad() throws {
        let dataset = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../../../dataset")
            .standardizedFileURL
        let catalog = try Catalog.load(datasetRoot: dataset)
        #expect(!catalog.allEvents().isEmpty)
        #expect(!catalog.boutIndex().isEmpty)
        #expect(try !catalog.news().isEmpty)
        #expect(try catalog.media().allSatisfy { $0.durationSeconds > 0 })
        #expect(throws: CatalogError.self) {
            try Catalog.load(datasetRoot: URL(fileURLWithPath: "/nonexistent/dataset"))
        }
    }
}
