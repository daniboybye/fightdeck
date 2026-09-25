//
// BetslipHosting.swift
// FightDeckBetslip
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore

/// The names a slip row shows, looked up in the catalogue the host has already loaded. It used
/// to be a protocol each host implemented — once in Swift and twice in Kotlin, with the same
/// three lookups each time. The host now only hands over its lists.
///
/// A value, not a reference to the host's state: the host builds a new one whenever its lists
/// change, which is what makes the rows swap fighter ids for names when the roster finishes
/// loading after the slip has opened.
public struct CatalogSlipDisplay: Sendable {
    private let events: [Event]
    private let fighters: [Fighter]

    public init(events: [Event], fighters: [Fighter]) {
        self.events = events
        self.fighters = fighters
    }

    public func fighterName(id: String) -> String {
        fighters.first { $0.id == id }?.name ?? id
    }

    public func opponentName(for selection: Selection) -> String {
        guard let bout = bout(id: selection.boutID) else { return "—" }
        let opponentID = bout.redCorner.fighterId == selection.fighterID
            ? bout.blueCorner.fighterId
            : bout.redCorner.fighterId
        return fighterName(id: opponentID)
    }

    public func eventName(for selection: Selection) -> String {
        events.first { event in event.bouts.contains { $0.id == selection.boutID } }?.name ?? "—"
    }

    private func bout(id: String) -> Bout? {
        for event in events {
            if let bout = event.bouts.first(where: { $0.id == id }) {
                return bout
            }
        }
        return nil
    }
}
