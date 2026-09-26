//
// Humanise.swift
// FightCore
//
// Created by FightDeck on 26.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

#if os(Android)
import FoundationEssentials
#else
import Foundation
#endif

/// Contract codes as the screens print them: `split_decision` → `Split decision`. In the
/// kernel rather than in FightEvents because the slip prints its validation errors this way,
/// and FightSlip does not depend on the catalogue.
public enum Humanise {
    public static func code(_ raw: String) -> String {
        let spaced = spaced(raw)
        guard let first = spaced.first else { return "" }
        return String(first).uppercased() + spaced.dropFirst()
    }

    /// `replacingOccurrences(of:with:)` comes from Foundation's NSString bridge, which is on
    /// the far side of the ICU line on Android. One character for another is a map.
    public static func spaced(_ raw: String) -> String {
        #if os(Android)
        return String(raw.map { $0 == "_" ? " " : $0 })
        #else
        return raw.replacingOccurrences(of: "_", with: " ")
        #endif
    }
}

extension ValidationError {
    /// The line the slip prints for this error.
    public var message: String {
        Humanise.code(rawValue)
    }
}
