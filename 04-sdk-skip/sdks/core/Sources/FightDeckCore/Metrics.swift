//
// Metrics.swift
// FightDeckCore
//
// Created by FightDeck on 23.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

import CoreGraphics

/// Layout numbers that more than one SDK screen needs.
///
/// Each screen keeps a `private enum Layout` for what only it uses — the deposit radio's
/// diameter, the fighter hero's height, the slip's tab-accessory clearance. These four were
/// in two of those enums with identical values, which is how the slip and the deposit ended
/// up agreeing by coincidence rather than by construction.
///
/// Note for the honest version of the Android story: `44` is the Human Interface Guidelines'
/// tap target. Material's is `48`, and the *hosts* already say so — `Tokens.minTapTarget` is
/// 48.dp. The SDK screens use 44 on both platforms, so an SDK button on Android is 4dp under
/// what Material asks for. Fixing that means these become platform-aware, which is a visual
/// change and wants a screenshot pass of its own.
public enum Metrics {
    public static let primaryActionHeight: CGFloat = 44
    public static let secondaryActionHeight: CGFloat = 44
    public static let secondaryActionPadding: CGFloat = 24
    public static let actionBarGap: CGFloat = 12
}
