package com.fightdeck.baseline.ui

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.fightdeck.rn.runtime.FightDeckRNRuntime

/**
 * Every React Native surface in the app is mounted through this one composable. [update] hands
 * the adapter new parameters, and the adapter drops the ones that change nothing, because
 * props re-render the surface from its root.
 *
 * The surface is sized to the space the host leaves it: callers pad it clear of their bars and
 * consume that padding, and imePadding() adds whatever part of the keyboard reaches past it.
 * The React screen then lays out against its own edges, the way a Compose screen does, and
 * needs no insets from the host — in pixels or in any other unit.
 */
@Composable
fun RNSurface(
    create: (Context) -> View,
    update: (View) -> Unit,
    modifier: Modifier = Modifier,
) {
    AndroidView(
        modifier = modifier.fillMaxSize().imePadding(),
        factory = create,
        update = update,
        onRelease = FightDeckRNRuntime::stopSurface,
    )
}
