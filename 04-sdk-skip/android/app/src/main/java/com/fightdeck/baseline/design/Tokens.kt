package com.fightdeck.baseline.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import fight.deck.core.Palette

/**
 * Only the values Material cannot supply live here. Type comes from
 * `MaterialTheme.typography` so the app scales with the system font size, and surfaces come
 * from the colour scheme so the expressive theme stays in charge of elevation.
 *
 * The sizes below are the host's own and deliberately differ from iOS's: Material's tap
 * target is 48dp, the Human Interface Guidelines' is 44pt. The *colours* are not the host's
 * — they come from the SDK's [Palette], which is the only place a FightDeck colour is
 * written down. Reading them as hex is what makes that possible at all: the SDK's own
 * `Color` type reaches a Compose colour only through a `@Composable` call, so it cannot be
 * held as a constant here.
 */
object Tokens {
    private fun hex(value: String) = Color(android.graphics.Color.parseColor(value))

    val background = hex(Palette.background)
    val surface = hex(Palette.surface)
    val surfaceElevated = hex(Palette.surfaceElevated)
    val accent = hex(Palette.accent)
    val onAccent = hex(Palette.onAccent)
    val positive = hex(Palette.positive)
    val negative = hex(Palette.negative)
    val cornerRed = hex(Palette.cornerRed)
    val cornerBlue = hex(Palette.cornerBlue)

    val spacingXs = 4.dp
    val spacingSm = 8.dp
    val spacingMd = 12.dp
    val spacingLg = 16.dp
    val spacingXl = 24.dp

    val radiusMd = 12.dp
    val radiusLg = 16.dp

    /** Material 3 minimum touch target — visual height and hit area both land here. */
    val minTapTarget = 48.dp

    /** Full-width primary actions — tap-target floor is also the ceiling. */
    val primaryActionHeight = 48.dp

    /** Chips, keyboard dismissal and confirmation acknowledgements — present but quiet. */
    val secondaryActionHeight = 48.dp

    /** Horizontal breathing room for a button that hugs its label instead of filling a bar. */
    val secondaryActionPadding = 24.dp

    /** What an odds pill asks for before padding brings it to the tap target. */
    val oddsLabelHeight = 30.dp

    /** Keeps a pinned action bar off whatever sits below it — nav bar or IME. */
    val actionBarGap = 12.dp
}
