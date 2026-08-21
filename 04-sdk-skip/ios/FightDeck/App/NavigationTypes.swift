//
// NavigationTypes.swift
// FightDeck
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Paysafe. All rights reserved.
//

import Foundation

/// Both event tabs render the same two events. The mode decides which half of the data is
/// relevant: betting needs odds and must not spoil the result, browsing history needs the
/// result and has nothing to bet on.
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

/// Shared by both event tabs. The article and video cases are only ever pushed from the past
/// tab, since news and press conferences are reporting on fights that already happened.
enum EventsRoute: Hashable {
    case event(String)
    case bout(eventID: String, boutID: String)
    case fighter(String)
    case article(String)
    case video(String)
}

enum SlipRoute: Hashable {
    case deposit
}
