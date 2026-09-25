//
// FighterHosting.swift
// FightDeckFighter
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore

public struct FighterParams: Sendable {
    public let fighter: Fighter
    public let portraitURL: String

    public init(fighter: Fighter, portraitURL: String) {
        self.fighter = fighter
        self.portraitURL = portraitURL
    }
}
