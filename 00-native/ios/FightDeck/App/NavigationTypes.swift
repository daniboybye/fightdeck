//
// NavigationTypes.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import Foundation

/// Both event tabs render the same two events; the mode decides which half of the data is
/// relevant. Betting must not spoil the result, and history has nothing to bet on.
enum EventMode: Hashable {
    case upcoming
    case past

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .past: "Past"
        }
    }

    var showsOdds: Bool { self == .upcoming }

    var showsResults: Bool { self == .past }
}

enum EventsRoute: Hashable {
    case event(String)
    case bout(eventID: String, boutID: String)
    case fighter(String)
    case article(String)
    case video(String)
}

