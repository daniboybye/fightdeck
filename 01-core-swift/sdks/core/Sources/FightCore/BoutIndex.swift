//
// BoutIndex.swift
// FightCore
//
// Created by FightDeck on 20.08.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

public struct BoutIndex: Sendable {
    public let id: String
    public let redFighterID: String
    public let blueFighterID: String
    public let winnerID: String

    public init(id: String, redFighterID: String, blueFighterID: String, winnerID: String) {
        self.id = id
        self.redFighterID = redFighterID
        self.blueFighterID = blueFighterID
        self.winnerID = winnerID
    }
}
