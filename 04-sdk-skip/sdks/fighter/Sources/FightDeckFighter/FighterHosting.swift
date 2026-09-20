//
// FighterHosting.swift
// FightDeckFighter
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI

public struct FighterParams: Sendable {
    public let fighter: Fighter
    public let portraitURL: String

    public init(fighter: Fighter, portraitURL: String) {
        self.fighter = fighter
        self.portraitURL = portraitURL
    }
}

// MARK: - Compose (Android)

#if SKIP
public struct FighterComposeEntry: View {
    public let params: FighterParams
    public let theme: ThemeTokens

    public init(params: FighterParams, theme: ThemeTokens) {
        self.params = params
        self.theme = theme
    }

    public var body: some View {
        FighterRootView(params: params, theme: theme)
    }
}
#endif
