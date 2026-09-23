//
// GroupedList.swift
// FightDeckCore
//
// Created by FightDeck on 20.09.26.
// Copyright © 2026 Daniel Urumov. All rights reserved.
//

// This file used to hold shared "grouped card" views, because the betslip screen drew the
// inset-grouped look by hand on Android. It holds nothing now, and the note is why — both
// halves are worth one read before anyone factors a screen's sections out again.
//
// The premise was wrong. `List` and `Section` are 🟢 in SkipUI's support table and `Form` is ✅,
// so the grouping never needed drawing: every screen now writes one `List`/`Form` for both
// platforms and lets each side's own styling draw it — inset-grouped cards on iOS, a Material
// list on Android. What genuinely has no SkipUI mapping is small and specific: `LabeledContent`
// (see `LabeledRow`), `.listRowInsets`, `.contentMargins` and `.pickerStyle(.inline)`.
//
// The other half is the trap that sent the first attempt down the hand-drawing road. A *container
// of our own* does not survive transpilation. Three shapes were tried, in this order:
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
// (3) was misdiagnosed at the time. The conclusion drawn from it was that a view of ours has to
// implement `Renderable.Render(context:)` rather than leave the work to `body`, and `LabeledRow`
// was written that way for a while. That was never the cause — see `LabeledRow.swift`, which is
// now one struct with a plain `body` and renders on both platforms. The real cause is the rule
// below, and every symptom in (1) to (3) is a face of it.
//
// The rule, worth more than the three attempts above, because it is
// mechanical and easy to check. **Reach a view of yours through a function, never as a bare
// initialiser inside a `@ViewBuilder`.** `skipstone` emits
//
//     errorRow("...").Compose(composectx)        // a call that returns a view — composed
//     LabeledRow(theme = theme, label = "…", …)  // a constructor statement — result dropped
//
// so the row is built and thrown away. Nothing warns: the Swift compiles, the transpile
// succeeds, the Android build succeeds, and the section simply comes out empty. The fighter and
// deposit screens only ever worked because they happened to route through `detailRow` and
// `summaryRow`; the betslip screen called `LabeledRow(...)` directly and lost its whole summary.
//
// To check a screen, read the generated Kotlin under
// `.build/plugins/outputs/<sdk>/…/src/main/kotlin/` and look for a capitalised call inside a
// `ComposeBuilder` with no `.Compose(` after it.
