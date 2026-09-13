package com.fightdeck.baseline.sdk

import com.fightdeck.baseline.core.BetMode as HostBetMode
import com.fightdeck.baseline.core.BetSlip as HostBetSlip
import com.fightdeck.baseline.core.Selection as HostSelection
import fight.deck.core.BetMode
import fight.deck.core.BetSlip
import fight.deck.core.Selection
import skip.lib.Array as SkipArray

object SdkSlipMapper {
    fun toSdkSlip(host: HostBetSlip): BetSlip = BetSlip(
        mode = when (host.mode) {
            HostBetMode.single -> BetMode.single
            HostBetMode.accumulator -> BetMode.accumulator
        },
        selections = SkipArray(host.selections.map { toSdkSelection(it) }),
        stake = host.stake,
    )

    fun toHostSlip(sdk: BetSlip): HostBetSlip = HostBetSlip(
        mode = when (sdk.mode) {
            BetMode.single -> HostBetMode.single
            BetMode.accumulator -> HostBetMode.accumulator
        },
        selections = sdk.selections.map { toHostSelection(it) }.toList(),
        stake = sdk.stake,
    )

    private fun toSdkSelection(host: HostSelection): Selection = Selection(
        boutID = host.boutId,
        fighterID = host.fighterId,
        odds = host.odds,
    )

    private fun toHostSelection(sdk: Selection): HostSelection = HostSelection(
        boutId = sdk.boutID,
        fighterId = sdk.fighterID,
        odds = sdk.odds,
    )
}
