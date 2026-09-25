package fightdeck.skip.consumer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import fight.deck.betslip.BetSlipRootView
import fight.deck.betslip.CatalogSlipDisplay
import fight.deck.core.BetSlipStore
import fight.deck.core.FightCore
import fight.deck.core.ThemeTokens
import skip.lib.Array as SkipArray

/**
 * Links only Maven-published Skip SDK artifacts — no host-side kotlin-reflect/commonmark/material patches.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val fightCore = FightCore(bouts = SkipArray(emptyList()))
        val store = BetSlipStore(fightCore = fightCore)
        val theme = ThemeTokens.defaults
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    BetSlipRootView(
                        store = store,
                        display = CatalogSlipDisplay(events = SkipArray(emptyList()), fighters = SkipArray(emptyList())),
                        theme = theme,
                        onDeposit = {},
                        onBrowseEvents = {},
                    ).Compose()
                }
            }
        }
    }
}
