package com.fightdeck.baseline.sdk

import com.fightdeck.baseline.data.BoutItem
import com.fightdeck.baseline.ui.LoadState
import com.fightdeck.baseline.ui.MainViewModel
import fight.deck.betslip.binary.SlipDisplayContext
import fight.deck.core.Selection

class HostSlipDisplayContext(
    private val viewModel: MainViewModel,
) : SlipDisplayContext {
    override fun fighterName(id: String): String {
        val fighters = viewModel.fighters.value
        if (fighters !is LoadState.Loaded) {
            return id
        }
        return fighters.value.firstOrNull { it.id == id }?.name ?: id
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
        val events = viewModel.events.value
        if (events !is LoadState.Loaded) {
            return "—"
        }
        return events.value.firstOrNull { event ->
            event.bouts.any { it.id == for_.boutID }
        }?.name ?: "—"
    }

    private fun findBout(boutId: String): BoutItem? {
        val events = viewModel.events.value
        if (events !is LoadState.Loaded) {
            return null
        }
        for (event in events.value) {
            val bout = event.bouts.firstOrNull { it.id == boutId }
            if (bout != null) {
                return bout
            }
        }
        return null
    }
}
