package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.core.Fighter
import fight.deck.fighter.FighterParams
import fight.deck.fighter.FighterRootView

/**
 * Compiled into the `all` flavour only, the one that links the fighter SDK. The provider and its
 * removal are there for the reason given in `BetslipSdkBridge.kt`.
 */
@Composable
fun FighterSdkScreen(
    fighter: Fighter,
    viewModel: MainViewModel,
    saveKey: String,
    modifier: Modifier = Modifier,
) {
    val stateHolder = rememberSaveableStateHolder()
    stateHolder.SaveableStateProvider(saveKey) {
        val params = remember(fighter) {
            FighterParams(
                fighter = fighter,
                portraitURL = viewModel.imageUrl(fighter.portrait).orEmpty(),
            )
        }
        // The SDK view composes into whatever box it is given, and it reads no window insets of
        // its own, so the host's top inset has to be a real box around it. Dropping the modifier
        // is what let the hero slide up under the toolbar.
        Box(modifier) {
            FighterRootView(
                params = params,
            ).Compose()
        }
        DisposableEffect(saveKey) {
            onDispose {
                stateHolder.removeState(saveKey)
            }
        }
    }
}
