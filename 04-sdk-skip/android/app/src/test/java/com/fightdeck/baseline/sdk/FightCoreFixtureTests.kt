package com.fightdeck.baseline.sdk

import fight.deck.core.BetMode
import fight.deck.core.BetSlip
import fight.deck.core.BoutIndex
import fight.deck.core.FightCore
import fight.deck.core.Money
import fight.deck.core.OddsEngine
import fight.deck.core.Selection
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.math.BigDecimal
import kotlin.test.Test
import kotlin.test.assertEquals
import skip.lib.Array as SkipArray
import skip.lib.Set as SkipSet

/**
 * The same golden fixtures every other core in this repository runs, pointed at the Kotlin
 * that Skip generated from the SDK's Swift. The host used to keep a hand-written Kotlin core
 * and test that instead, which proved only that the copy agreed with the fixtures. Testing
 * the transpiled core proves the transpiler preserved the money, odds and settlement rules.
 */
class FightCoreFixtureTests {
    private val json = Json { ignoreUnknownKeys = true }
    private val core = fixtureFightCore()

    @Test
    fun oddsConversion() {
        val root = json.decodeFromString<OddsConversionRoot>(fixture("odds-conversion"))
        root.cases.forEach { case ->
            val decimal = Money.parse(case.decimal)
            assertEquals(case.fractional, OddsEngine.decimalToFractional(decimal), case.id)
            assertEquals(
                case.impliedProbability,
                OddsEngine.impliedProbability(decimal).setScale(4).toPlainString(),
                case.id,
            )
            val roundTrip = OddsEngine.fractionalToDecimal(case.fractional)
            assertEquals(plain(decimal), plain(roundTrip), case.id)
        }
    }

    @Test
    fun slipMath() {
        val root = json.decodeFromString<SlipMathRoot>(fixture("slip-math"))
        root.cases.forEach { case ->
            val state = core.slipState(case.toSlip(), BigDecimal("10000"))
            case.expect.combinedOddsExact?.let {
                // FightCoreDisplay.formatExactOdds is ICU-backed like Money.format, so the
                // exact odds are compared as an unpadded plain string instead.
                assertEquals(it, state.combinedOddsExact!!.stripTrailingZeros().toPlainString(), case.id)
            }
            case.expect.combinedOddsDisplay?.let {
                assertEquals(it, plain(state.combinedOddsDisplay!!), case.id)
            }
            assertEquals(case.expect.totalStake, plain(state.totalStake), case.id)
            assertEquals(case.expect.potentialReturn, plain(state.potentialReturn), case.id)
            assertEquals(case.expect.potentialProfit, plain(state.potentialProfit), case.id)
        }
    }

    @Test
    fun slipValidation() {
        val root = json.decodeFromString<SlipValidationRoot>(fixture("slip-validation"))
        root.cases.forEach { case ->
            val errors = core.validate(case.toSlip(), Money.parse(case.balance))
                .toList()
                .map { it.rawValue }
            assertEquals(case.expect.errors, errors, case.id)
        }
    }

    @Test
    fun settlement() {
        val root = json.decodeFromString<SettlementRoot>(fixture("settlement"))
        root.cases.forEach { case ->
            val result = core.settle(case.toSlip(), SkipSet(case.voidedBouts ?: emptyList()))
            assertEquals(case.expect.returned, plain(result.returned), case.id)
            assertEquals(case.expect.profit, plain(result.profit), case.id)
            // rawValue, not name: partiallyWon is spelled partially_won in the contract.
            assertEquals(case.expect.status, result.status.rawValue, case.id)
            val legs = result.legs.toList()
            case.expect.legs.forEachIndexed { index, expected ->
                assertEquals(expected.boutId, legs[index].boutID)
                assertEquals(expected.fighterId, legs[index].fighterID)
                assertEquals(expected.outcome, legs[index].outcome.rawValue)
            }
        }
    }

    @Test
    fun cashOut() {
        val root = json.decodeFromString<CashOutRoot>(fixture("cash-out"))
        root.cases.forEach { case ->
            val offer = core.cashOutOffer(case.toSlip(), SkipSet(case.settledBouts))
            assertEquals(case.expect.available, offer.available, case.id)
            assertEquals(case.expect.amount, plain(offer.amount), case.id)
            assertEquals(case.expect.reason, offer.reason, case.id)
        }
    }

    /**
     * `Money.format` goes through skip-foundation's NumberFormatter, which lands on
     * `android.icu.text.NumberFormat` and so cannot run on a plain JVM runner. Rounding is the
     * part of the contract worth asserting here, and `Money.money` is pure BigDecimal, so the
     * amounts are compared as rounded plain strings. Formatting itself is covered by the SDK's
     * own Swift tests.
     */
    private fun plain(value: BigDecimal): String = Money.money(value).toPlainString()

    private fun fixture(name: String): String =
        File(fixturesRoot(), "$name.json").readText()

    private fun fixturesRoot(): String =
        System.getProperty("fightdeck.fixtures.root")
            ?: error("fightdeck.fixtures.root not set")

    private fun fixtureFightCore(): FightCore {
        val datasetRoot = System.getProperty("fightdeck.dataset.root")
            ?: error("fightdeck.dataset.root not set")
        val events = json.decodeFromString<EventsFile>(File(datasetRoot, "events.json").readText())
        val bouts = events.events.flatMap { it.bouts }.map {
            BoutIndex(it.id, it.redCorner.fighterId, it.blueCorner.fighterId, it.result.winnerId)
        }
        return FightCore(SkipArray(bouts))
    }
}

@Serializable
private data class OddsConversionRoot(val cases: List<OddsConversionCase>)

@Serializable
private data class OddsConversionCase(
    val id: String,
    val decimal: String,
    val fractional: String,
    val impliedProbability: String,
)

@Serializable
private data class SlipMathRoot(val cases: List<SlipMathCase>)

@Serializable
private data class SlipMathCase(
    val id: String,
    val mode: String,
    val stake: String,
    val selections: List<SelectionDto>,
    val expect: SlipMathExpect,
) {
    fun toSlip() = slip(mode, selections, stake)
}

@Serializable
private data class SlipMathExpect(
    val combinedOddsExact: String? = null,
    val combinedOddsDisplay: String? = null,
    val totalStake: String,
    val potentialReturn: String,
    val potentialProfit: String,
)

@Serializable
private data class SlipValidationRoot(val cases: List<SlipValidationCase>)

@Serializable
private data class SlipValidationCase(
    val id: String,
    val mode: String,
    val stake: String,
    val balance: String,
    val selections: List<SelectionDto>,
    val expect: SlipValidationExpect,
) {
    fun toSlip() = slip(mode, selections, stake)
}

@Serializable
private data class SlipValidationExpect(val errors: List<String>)

@Serializable
private data class SettlementRoot(val cases: List<SettlementCase>)

@Serializable
private data class SettlementCase(
    val id: String,
    val mode: String,
    val stake: String,
    val selections: List<SelectionDto>,
    val voidedBouts: List<String>? = null,
    val expect: SettlementExpect,
) {
    fun toSlip() = slip(mode, selections, stake)
}

@Serializable
private data class SettlementExpect(
    val legs: List<SettlementLegExpect>,
    val returned: String,
    val profit: String,
    val status: String,
)

@Serializable
private data class SettlementLegExpect(
    val boutId: String,
    val fighterId: String,
    val outcome: String,
)

@Serializable
private data class CashOutRoot(val cases: List<CashOutCase>)

@Serializable
private data class CashOutCase(
    val id: String,
    val mode: String,
    val stake: String,
    val selections: List<SelectionDto>,
    val settledBouts: List<String>,
    val expect: CashOutExpect,
) {
    fun toSlip() = slip(mode, selections, stake)
}

@Serializable
private data class CashOutExpect(
    val available: Boolean,
    val amount: String,
    val reason: String? = null,
)

@Serializable
private data class SelectionDto(
    @SerialName("boutId") val boutId: String,
    @SerialName("fighterId") val fighterId: String,
    val odds: String,
) {
    fun toSelection() = Selection(boutId, fighterId, Money.parse(odds))
}

/** A transpiled Swift array, so the fixture selections cannot be handed over as a List. */
private fun slip(mode: String, selections: List<SelectionDto>, stake: String) = BetSlip(
    BetMode.valueOf(mode),
    SkipArray(selections.map { it.toSelection() }),
    Money.parse(stake),
)

@Serializable
private data class EventsFile(val events: List<EventDto>)

@Serializable
private data class EventDto(val bouts: List<BoutDto>)

@Serializable
private data class BoutDto(
    val id: String,
    val redCorner: CornerDto,
    val blueCorner: CornerDto,
    val result: ResultDto,
)

@Serializable
private data class CornerDto(@SerialName("fighterId") val fighterId: String)

@Serializable
private data class ResultDto(@SerialName("winnerId") val winnerId: String)
