package com.fightdeck.swiftcore.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.math.BigDecimal
import kotlin.test.Test
import kotlin.test.assertEquals

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
            assertEquals(Money.format(decimal), Money.format(roundTrip), case.id)
        }
    }

    @Test
    fun slipMath() {
        val root = json.decodeFromString<SlipMathRoot>(fixture("slip-math"))
        root.cases.forEach { case ->
            val slip = case.toSlip()
            val state = core.slipState(slip, BigDecimal("10000"))
            case.expect.combinedOddsExact?.let {
                assertEquals(it, FightCore.formatExactOdds(state.combinedOddsExact!!), case.id)
            }
            case.expect.combinedOddsDisplay?.let {
                assertEquals(it, Money.format(state.combinedOddsDisplay!!), case.id)
            }
            assertEquals(case.expect.totalStake, Money.format(state.totalStake), case.id)
            assertEquals(case.expect.potentialReturn, Money.format(state.potentialReturn), case.id)
            assertEquals(case.expect.potentialProfit, Money.format(state.potentialProfit), case.id)
        }
    }

    @Test
    fun slipValidation() {
        val root = json.decodeFromString<SlipValidationRoot>(fixture("slip-validation"))
        root.cases.forEach { case ->
            val errors = core.validate(case.toSlip(), Money.parse(case.balance)).map { it.code }
            assertEquals(case.expect.errors, errors, case.id)
        }
    }

    @Test
    fun settlement() {
        val root = json.decodeFromString<SettlementRoot>(fixture("settlement"))
        root.cases.forEach { case ->
            val result = core.settle(case.toSlip(), case.voidedBouts?.toSet() ?: emptySet())
            assertEquals(case.expect.returned, Money.format(result.returned), case.id)
            assertEquals(case.expect.profit, Money.format(result.profit), case.id)
            assertEquals(case.expect.status, result.status.name, case.id)
            case.expect.legs.forEachIndexed { index, expected ->
                assertEquals(expected.boutId, result.legs[index].boutId)
                assertEquals(expected.fighterId, result.legs[index].fighterId)
                assertEquals(expected.outcome, result.legs[index].outcome.name)
            }
        }
    }

    @Test
    fun cashOut() {
        val root = json.decodeFromString<CashOutRoot>(fixture("cash-out"))
        root.cases.forEach { case ->
            val offer = core.cashOutOffer(case.toSlip(), case.settledBouts.toSet())
            assertEquals(case.expect.available, offer.available, case.id)
            assertEquals(case.expect.amount, Money.format(offer.amount), case.id)
            assertEquals(case.expect.reason, offer.reason, case.id)
        }
    }

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
        return FightCore(bouts.associateBy { it.id })
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
    fun toSlip() = BetSlip(
        mode = BetMode.valueOf(mode),
        selections = selections.map { it.toSelection() },
        stake = Money.parse(stake),
    )
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
    fun toSlip() = BetSlip(
        mode = BetMode.valueOf(mode),
        selections = selections.map { it.toSelection() },
        stake = Money.parse(stake),
    )
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
    fun toSlip() = BetSlip(
        mode = BetMode.valueOf(mode),
        selections = selections.map { it.toSelection() },
        stake = Money.parse(stake),
    )
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
    fun toSlip() = BetSlip(
        mode = BetMode.valueOf(mode),
        selections = selections.map { it.toSelection() },
        stake = Money.parse(stake),
    )
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
