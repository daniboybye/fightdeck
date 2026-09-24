package com.fightdeck.swiftcore.core

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fightdeck.fightcore.FightCoreJava
import com.fightdeck.fightevents.EventCatalogBridge
import com.fightdeck.fightslip.SlipEngine
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import kotlin.test.assertEquals

/**
 * The contract fixtures, evaluated by the cross-compiled Swift core on the device.
 *
 * This is the same JSON that `swift test` runs on macOS and that the iOS app links
 * statically. Push the inputs first:
 *
 *   adb push contract/fixtures /data/local/tmp/fightdeck/fixtures
 *   adb push dataset /data/local/tmp/fightdeck/dataset
 */
@RunWith(AndroidJUnit4::class)
class SwiftCoreFixtureTests {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun oddsConversion() {
        val root = json.decodeFromString<OddsConversionRoot>(fixture("odds-conversion"))
        root.cases.forEach { case ->
            assertEquals(case.fractional, FightCoreJava.decimalToFractional(case.decimal), case.id)
            assertEquals(
                case.impliedProbability,
                FightCoreJava.impliedProbability(case.decimal),
                case.id,
            )
            val roundTrip = FightCoreJava.fractionalToDecimal(case.fractional)
            assertEquals(FightCoreJava.formatMoney(case.decimal), roundTrip, case.id)
        }
    }

    @Test
    fun slipMath() {
        val root = json.decodeFromString<SlipMathRoot>(fixture("slip-math"))
        root.cases.forEach { case ->
            val engine = engineForFixtures()
            case.load(engine, balance = "10000")
            case.expect.combinedOddsExact?.let {
                assertEquals(it, engine.combinedOddsExactText, case.id)
            }
            case.expect.combinedOddsDisplay?.let {
                assertEquals(it, engine.combinedOddsText, case.id)
            }
            assertEquals(case.expect.totalStake, engine.totalStakeText, case.id)
            assertEquals(case.expect.potentialReturn, engine.potentialReturnText, case.id)
            assertEquals(case.expect.potentialProfit, engine.potentialProfitText, case.id)
        }
    }

    @Test
    fun slipValidation() {
        val root = json.decodeFromString<SlipValidationRoot>(fixture("slip-validation"))
        root.cases.forEach { case ->
            val engine = engineForFixtures()
            case.load(engine, balance = case.balance)
            assertEquals(case.expect.errors, engine.errorCodes.toList(), case.id)
        }
    }

    @Test
    fun settlement() {
        val root = json.decodeFromString<SettlementRoot>(fixture("settlement"))
        root.cases.forEach { case ->
            val engine = engineForFixtures()
            case.load(engine, balance = "10000")
            val result = engine.settle((case.voidedBouts ?: emptyList()).toTypedArray())
            assertEquals(case.expect.returned, result.returnedText, case.id)
            assertEquals(case.expect.profit, result.profitText, case.id)
            assertEquals(case.expect.status, result.status, case.id)
            case.expect.legs.forEachIndexed { index, expected ->
                assertEquals(expected.outcome, result.legOutcomes[index], "${case.id} leg $index")
            }
        }
    }

    @Test
    fun cashOut() {
        val root = json.decodeFromString<CashOutRoot>(fixture("cash-out"))
        root.cases.forEach { case ->
            val engine = engineForFixtures()
            case.load(engine, balance = "10000")
            val offer = engine.cashOutOffer(case.settledBouts.toTypedArray())
            assertEquals(case.expect.available, offer.isAvailable, case.id)
            assertEquals(case.expect.amount, offer.amountText, case.id)
            assertEquals(case.expect.reason ?: "", offer.reason, case.id)
        }
    }

    /** The seven-fold that turns €10 into €361.11 — the number the talk puts on two phones. */
    @Test
    fun sevenFoldAccumulator() {
        val root = json.decodeFromString<SlipMathRoot>(fixture("slip-math"))
        val case = root.cases.first { it.selections.size == 7 }
        val engine = engineForFixtures()
        case.load(engine, balance = "10000")
        assertEquals("361.11", engine.potentialReturnText)
    }

    private fun engineForFixtures(): SlipEngine =
        SlipEngine.init(EventCatalogBridge.`init`(DATASET_ROOT).boutIndexJSON)

    private fun fixture(name: String): String {
        val file = File(FIXTURES_ROOT, "$name.json")
        check(file.exists()) { "Missing $file — adb push contract/fixtures to $FIXTURES_ROOT" }
        return file.readText()
    }

    private companion object {
        const val FIXTURES_ROOT = "/data/local/tmp/fightdeck/fixtures"
        const val DATASET_ROOT = "/data/local/tmp/fightdeck/dataset"
    }
}

private fun SlipEngine.loadCase(
    mode: String,
    stake: String,
    balance: String,
    selections: List<SelectionDto>,
) {
    resetSlip(mode, stake, balance)
    selections.forEach { addSelection(it.boutId, it.fighterId, it.odds) }
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
    fun load(engine: SlipEngine, balance: String) = engine.loadCase(mode, stake, balance, selections)
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
    fun load(engine: SlipEngine, balance: String) = engine.loadCase(mode, stake, balance, selections)
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
    fun load(engine: SlipEngine, balance: String) = engine.loadCase(mode, stake, balance, selections)
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
    fun load(engine: SlipEngine, balance: String) = engine.loadCase(mode, stake, balance, selections)
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
)
