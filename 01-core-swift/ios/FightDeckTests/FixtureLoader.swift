//
// FixtureLoader.swift
// FightDeckTests
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

enum FixtureLoader {
    static func loadJSON(named name: String) throws -> Data {
        let url = fixturesDirectory.appendingPathComponent("\(name).json")
        return try Data(contentsOf: url)
    }

    static var fixturesDirectory: URL {
        if let env = ProcessInfo.processInfo.environment["FIGHTDECK_FIXTURES_ROOT"],
           !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let resource = Bundle(for: BundleMarker.self).resourceURL?
            .appendingPathComponent("fixtures", isDirectory: true),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }

        let sourceFile = URL(fileURLWithPath: #filePath)
        return sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contract/fixtures", isDirectory: true)
    }
}

private final class BundleMarker {}
