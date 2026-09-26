//
// DatasetLocator.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// Where the dataset lives is the host's to know: a scheme variable, the app bundle, or the
/// repository checkout while developing. Reading it and serving its images is FightEvents'.
enum DatasetLocator {
    static func datasetRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["FIGHTDECK_DATASET_ROOT"],
           !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Dataset"),
           holdsDataset(bundled) {
            return bundled
        }
        // Development fallback. Walking up beats a fixed number of parent hops, which
        // resolves to a plausible-but-wrong directory the moment this file moves.
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("dataset")
            if holdsDataset(candidate) {
                return candidate
            }
            directory = directory.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: "/tmp/fightdeck-dataset")
    }

    private static func holdsDataset(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("events.json").path)
    }
}
