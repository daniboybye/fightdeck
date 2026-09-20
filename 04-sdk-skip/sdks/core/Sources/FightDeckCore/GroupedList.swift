//
// GroupedList.swift
// FightDeckCore
//
// Created by FightDeck on 20.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

// SkipUI maps `List` to a plain Compose list with no grouped style, so the betslip and fighter
// screens draw the inset-grouped look by hand. This file used to hold that as shared views.
// It holds nothing now, and the note is why — the same trap is worth one read before anyone
// tries to factor those screens' sections out again.
//
// Three shapes were tried on Android, in this order:
//
//   1. `GroupedSection { row; row }` — a view of ours taking `@ViewBuilder` content. `skipstone`
//      turns a stored `@ViewBuilder` closure into a plain Kotlin lambda, and a Kotlin lambda
//      yields only its last expression, so the section arrived as its last row alone. Written
//      with a `ForEach` instead, it arrived empty.
//   2. `.groupedCard(theme:)` — a `View` extension holding the styling. Worse: the screen
//      composed to nothing at all.
//   3. `GroupedSectionTitle`, `GroupedDivider`, `GroupedLabeledRow` — plain view structs with no
//      closure at all, placed among siblings in the screens' own `VStack`s. Every one of them
//      dropped out, while the local functions beside them rendered. Chaining a `.padding` onto
//      one also failed transpilation outright: "unable to determine the owning type for member
//      'horizontal'".
//
// What does work, and what both screens now do: SkipUI's own `VStack`, `ForEach` and modifiers,
// with each piece a local function returning SkipUI primitives. The duplication between the two
// screens is the price, and it is smaller than it looks — about twenty lines each.
