package com.fightdeck.rn.nativebadge

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Fabric ViewManager wraps this ComposeView on Android (mirrors SwiftUI badge on iOS).
 * Wired when the Gradle RN runtime module is linked in CI.
 */
object FightDeckNativeBadgeManager {
    @Composable
    fun Badge(label: String, accent: Boolean) {
        val bg = if (accent) Color(0xFFE8B33C) else Color(0xFF1C2230)
        val fg = if (accent) Color(0xFF0B0E14) else Color(0xFF9AA5B8)
        Text(
            text = label,
            color = fg,
            fontSize = 12.sp,
            modifier = Modifier
                .background(bg, RoundedCornerShape(999.dp))
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
    }
}
