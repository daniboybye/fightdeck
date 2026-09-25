package com.fightdeck.baseline.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fightdeck.baseline.ui.LoadState
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.BetSlipRootView
import fight.deck.betslip.CatalogSlipDisplay
import fight.deck.core.ThemeTokens
import skip.lib.Array as SkipArray

/**
 * Compiled into every flavour that links the bet slip SDK (`both` and `all`); the others get a
 * placeholder from their own source set.
 *
 * Each SDK screen sits in a `SaveableStateProvider` whose slot is removed when the screen leaves
 * composition. The removal is load-bearing: SkipUI cannot restore its own saved `@FocusState` or
 * `NavigationStack`, so state that survives an activity recreation crashes the screen. See the
 * embedding-seam section of the README.
 */
@Composable
fun BetslipSdkScreen(
    viewModel: MainViewModel,
    saveKey: String,
    onDeposit: () -> Unit,
    onBrowseEvents: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Collected rather than read with `.value`: a plain `.value` read is not a composition
    // input, so selection rows kept showing fighter ids when the slip opened before the roster
    // finished loading.
    val fighters by viewModel.fighters.collectAsStateWithLifecycle()
    val events by viewModel.events.collectAsStateWithLifecycle()
    val stateHolder = rememberSaveableStateHolder()
    stateHolder.SaveableStateProvider(saveKey) {
        val display = remember(fighters, events) {
            CatalogSlipDisplay(
                events = SkipArray((events as? LoadState.Loaded)?.value.orEmpty()),
                fighters = SkipArray((fighters as? LoadState.Loaded)?.value.orEmpty()),
            )
        }
        val theme = remember { ThemeTokens.defaults }
        // The SDK view composes into whatever box it is given and reads no insets of its own, so
        // the host's top-bar padding has to be a real box around it. Without one the list
        // scrolls under the Bet Slip toolbar.
        Box(modifier) {
            BetSlipRootView(
                store = viewModel.slipStore,
                display = display,
                theme = theme,
                onDeposit = onDeposit,
                onBrowseEvents = onBrowseEvents,
            ).Compose()
        }
        DisposableEffect(saveKey) {
            onDispose {
                stateHolder.removeState(saveKey)
            }
        }
    }
}
