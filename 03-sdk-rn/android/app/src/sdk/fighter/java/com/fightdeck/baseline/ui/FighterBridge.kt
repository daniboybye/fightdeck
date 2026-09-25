package com.fightdeck.baseline.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.fightdeck.sdk.fighter.FighterAdapter
import com.fightdeck.sdk.fighter.FighterParams

@Composable
fun RNFighterProfileScreen(
    fighterJSON: String,
    portraitURL: String,
    modifier: Modifier = Modifier,
) {
    val adapter = remember { FighterAdapter() }
    val params = FighterParams(
        themeJSON = rememberThemeJSON(),
        fighterJSON = fighterJSON,
        portraitURL = portraitURL,
    )
    RNSurface(
        includesTabBarClearance = false,
        create = { context -> adapter.createView(context, params) },
        update = { view -> adapter.updateProps(view, params) },
        modifier = modifier,
    )
}
