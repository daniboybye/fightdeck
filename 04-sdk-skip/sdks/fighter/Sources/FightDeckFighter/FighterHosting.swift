//
// FighterHosting.swift
// FightDeckFighter
//
// Created by FightDeck on 13.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import FightDeckCore
import SwiftUI
#if !SKIP
import UIKit
#endif

public struct FighterParams: Sendable {
    public let fighterJSON: String
    public let portraitURL: String

    public init(fighterJSON: String, portraitURL: String) {
        self.fighterJSON = fighterJSON
        self.portraitURL = portraitURL
    }
}

#if !SKIP
public protocol FighterHosting: AnyObject {
    func configure()
    @MainActor
    func makeViewController(params: FighterParams, theme: ThemeTokens) -> UIViewController
}

public final class SkipFighterHosting: FighterHosting {
    public init() {}

    public func configure() {}

    @MainActor
    public func makeViewController(params: FighterParams, theme: ThemeTokens) -> UIViewController {
        let view = FighterRootView(params: params, theme: theme)
        return UIHostingController(rootView: view)
    }
}
#endif

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
