package com.fightdeck.baseline.sdk

import com.fightdeck.baseline.ui.LoadState
import fight.deck.betslip.SlipDisplayContext
import fight.deck.core.Bout
import fight.deck.core.Event
import fight.deck.core.Fighter
import fight.deck.core.Selection

/**
 * Takes the loaded rosters as values rather than reading them off the view model. Holding the
 * view model let the context return ids for names when the slip opened mid-load, because nothing
 * in the SDK's Compose tree depended on the flows that later filled in.
 */
class HostSlipDisplayContext(
    private val fighters: LoadState<List<Fighter>>,
    private val events: LoadState<List<Event>>,
) : SlipDisplayContext {
    override fun fighterName(id: String): String {
        val loaded = fighters as? LoadState.Loaded ?: return id
        return loaded.value.firstOrNull { it.id == id }?.name ?: id
    }

    override fun opponentName(for_: Selection): String {
        val bout = findBout(for_.boutID) ?: return "—"
        val opponentId = if (bout.redCorner.fighterId == for_.fighterID) {
            bout.blueCorner.fighterId
        } else {
            bout.redCorner.fighterId
        }
        return fighterName(opponentId)
    }

    override fun eventName(for_: Selection): String {
        val loaded = events as? LoadState.Loaded ?: return "—"
        return loaded.value.firstOrNull { event ->
            event.bouts.any { it.id == for_.boutID }
        }?.name ?: "—"
    }

    private fun findBout(boutId: String): Bout? {
        val loaded = events as? LoadState.Loaded ?: return null
        for (event in loaded.value) {
            val bout = event.bouts.firstOrNull { it.id == boutId }
            if (bout != null) {
                return bout
            }
        }
        return null
    }
}
