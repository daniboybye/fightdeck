package com.fightdeck.swiftcore.core

import com.fightdeck.sdk.FightDeckJava
import com.fightdeck.sdk.SlipEngine

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

data class DepositMethodOption(val id: String, val title: String, val feeNote: String)

data class DepositQuote(
    /** Two places, ready for `SlipEngine.deposit`. */
    val amount: String,
    val amountDisplay: String,
    val feeDisplay: String,
    val totalDisplay: String,
    val newBalanceDisplay: String,
    val validationMessage: String?,
    val canConfirm: Boolean,
)

fun depositMethods(): List<DepositMethodOption> {
    val methods = FightDeckJava.depositMethods()
    return methods.ids().indices.map {
        DepositMethodOption(methods.ids()[it], methods.titles()[it], methods.feeNotes()[it])
    }
}

/** One JNI call per keystroke, answered in plain values. */
fun depositQuote(amountText: String, methodId: String, balance: String): DepositQuote {
    val quote = FightDeckJava.depositQuote(amountText, methodId, balance)
    return DepositQuote(
        amount = quote.amount(),
        amountDisplay = quote.amountDisplay(),
        feeDisplay = quote.feeDisplay(),
        totalDisplay = quote.totalDisplay(),
        newBalanceDisplay = quote.newBalanceDisplay(),
        validationMessage = quote.validationMessage().orElse(null),
        canConfirm = quote.canConfirm(),
    )
}
