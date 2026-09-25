package com.fightdeck.swiftcore.core

import com.fightdeck.fightslip.SlipEngine

/**
 * The whole slip in one JNI call. `snapshot()` returns a tuple of plain Java values, so there
 * is no Swift object behind it to keep alive or free; this only turns its parallel arrays back
 * into lists of rows.
 */
fun SlipEngine.readSnapshot(): SlipSnapshot {
    val snapshot = snapshot()
    val boutIds = snapshot.legBoutIDs()
    val fighterIds = snapshot.legFighterIDs()
    val odds = snapshot.legOdds()
    return SlipSnapshot(
        modeTitle = snapshot.modeTitle(),
        legs = boutIds.indices.map { SlipLeg(boutIds[it], fighterIds[it], odds[it]) },
        stake = snapshot.stake(),
        balance = snapshot.balance(),
        balanceDisplay = snapshot.balanceDisplay(),
        returnDisplay = snapshot.returnDisplay(),
        summaryRows = snapshot.summaryLabels().zip(snapshot.summaryValues()),
        errors = snapshot.errors().toList(),
        confirmation = snapshot.confirmation().orElse(null),
    )
}
