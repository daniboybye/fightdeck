package com.fightdeck.rust.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Only the values Material cannot supply live here. Type comes from
 * `MaterialTheme.typography` so the app scales with the system font size, and surfaces come
 * from the colour scheme so the expressive theme stays in charge of elevation.
 */
object Tokens {
    val background = Color(0xFF0B0E14)
    val surface = Color(0xFF141922)
    val surfaceElevated = Color(0xFF1C2230)
    val accent = Color(0xFFE8B33C)
    val onAccent = Color(0xFF0B0E14)
    val positive = Color(0xFF3DD68C)
    val negative = Color(0xFFF2545B)
    val cornerRed = Color(0xFFD94A4A)
    val cornerBlue = Color(0xFF4A7FD9)

    val spacingXs = 4.dp
    val spacingSm = 8.dp
    val spacingMd = 12.dp
    val spacingLg = 16.dp
    val spacingXl = 24.dp

    val radiusMd = 12.dp
    val radiusLg = 16.dp
}
