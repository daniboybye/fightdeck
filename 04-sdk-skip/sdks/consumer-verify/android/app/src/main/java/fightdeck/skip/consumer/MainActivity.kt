package fightdeck.skip.consumer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import fight.deck.betslip.BetslipComposeEntry
import fight.deck.betslip.BetSlipStore
import fight.deck.betslip.SlipDisplayContext
import fight.deck.core.FightCore
import fight.deck.core.Selection
import fight.deck.core.ThemeTokens
import skip.lib.Array as SkipArray

private object StubSlipDisplay : SlipDisplayContext {
    override fun fighterName(id: String): String = id
    override fun opponentName(for_: Selection): String = "—"
    override fun eventName(for_: Selection): String = "—"
}

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
                    BetslipComposeEntry(
                        store = store,
                        display = StubSlipDisplay,
                        theme = theme,
                        onDeposit = {},
                        onBrowseEvents = {},
                        onHostSync = { _, _, _ -> },
                    ).Compose()
                }
            }
        }
    }
}
