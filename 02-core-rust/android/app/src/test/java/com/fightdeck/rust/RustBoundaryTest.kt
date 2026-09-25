package com.fightdeck.rust

import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.fightcore.FightCoreException
import uniffi.fightcore.decimalToFractional
import uniffi.fightcore.formatExactOdds
import uniffi.fightcore.formatMoney
import uniffi.fightcore.fractionalToDecimal
import uniffi.fightcore.impliedProbability
import uniffi.fightevents.EventCatalog
import uniffi.fightevents.EventsException
import uniffi.fightslip.BetModeRecord
import uniffi.fightslip.BetSlipRecord
import uniffi.fightslip.SelectionRecord
import uniffi.fightslip.SlipException
import uniffi.fightslip.SlipHandle
import uniffi.fightslip.validationErrorCode

/**
 * The Kotlin bindings and the aggregate libfightdeck, called on the JVM against a host build
 * of the same crates. One case from each contract file, picked for what it sends across the
 * boundary; the Rust tests already run all 72 against the rules themselves.
 */
class RustBoundaryTest {
    private val catalog = EventCatalog.load(System.getProperty("fightdeck.dataset.root"))

    // fightevents builds the index and fightslip takes it as it is: BoutIndex is fightcore's
    // record, so no host code maps one SDK's type onto the other's.
    private val slip = SlipHandle(catalog.boutIndex())

    @Test
    fun oddsCrossAsStrings() {
        val case = case("odds-conversion", "ufc-freedom-250-bout-01-redCorner")
        val decimal = case.getString("decimal")
        assertEquals(case.getString("fractional"), decimalToFractional(decimal))
        assertEquals(case.getString("impliedProbability"), impliedProbability(decimal))
        assertEquals(formatMoney(decimal), formatMoney(fractionalToDecimal(case.getString("fractional"))))
    }

    @Test
    fun theSevenFoldKeepsEveryDigitOfItsOdds() {
        val case = case("slip-math", "acca-seven-fold-double-rounding")
        val expect = case.getJSONObject("expect")
        val state = slip.slipState(case.slip(), "10000.00")
        assertEquals(expect.getString("combinedOddsExact"), formatExactOdds(state.combinedOddsExact!!))
        assertEquals(expect.getString("combinedOddsDisplay"), state.combinedOddsDisplay)
        assertEquals(expect.getString("potentialReturn"), state.potentialReturn)
        assertEquals(expect.getString("potentialProfit"), state.potentialProfit)
    }

    @Test
    fun errorsArriveAsEnumsInContractOrder() {
        val case = case("slip-validation", "multiple-errors")
        val errors = slip.validate(case.slip(), case.getString("balance"))
        assertEquals(
            case.getJSONObject("expect").getJSONArray("errors").strings(),
            errors.map(::validationErrorCode),
        )
    }

    @Test
    fun aVoidLegSettlesAsVoid() {
        val case = case("settlement", "acca-with-void-leg")
        val expect = case.getJSONObject("expect")
        val result = slip.settle(case.slip(), case.getJSONArray("voidedBouts").strings())
        assertEquals(expect.getString("returned"), result.returned)
        assertEquals(expect.getString("profit"), result.profit)
        assertEquals(expect.getString("status"), result.status.name.lowercase())
        assertEquals(
            expect.getJSONArray("legs").objects().map { it.getString("outcome") },
            result.legs.map { it.outcome.name.lowercase() },
        )
    }

    @Test
    fun aCashOutReasonIsNullOnlyWhenAnOfferStands() {
        val open = case("cash-out", "nothing-settled")
        val offer = slip.cashOutOffer(open.slip(), open.getJSONArray("settledBouts").strings())
        assertTrue(offer.available)
        assertEquals(open.getJSONObject("expect").getString("amount"), offer.amount)
        assertNull(offer.reason)

        val lost = case("cash-out", "one-leg-lost")
        val refused = slip.cashOutOffer(lost.slip(), lost.getJSONArray("settledBouts").strings())
        assertFalse(refused.available)
        assertEquals(lost.getJSONObject("expect").getString("reason"), refused.reason)
    }

    @Test
    fun errorsCrossTyped() {
        assertEquals("amount", assertThrows(FightCoreException.Decoding::class.java) { formatMoney("ten") }.field)
        assertEquals("balance", assertThrows(SlipException.Decoding::class.java) { slip.validate(emptySlip(), "lots") }.field)
        assertEquals("nobody", assertThrows(EventsException.NotFound::class.java) { catalog.fighter("nobody") }.id)
    }

    @Test
    fun missingFighterFieldsStayNull() {
        val fighters = catalog.boutIndex().flatMap { listOf(it.redFighterId, it.blueFighterId) }
            .map { catalog.fighter(it) }
        assertTrue(fighters.any { it.reachIn == null })
        assertTrue(fighters.any { it.reachIn != null })
    }

    private fun case(file: String, id: String): JSONObject {
        val root = File(System.getProperty("fightdeck.fixtures.root"), "$file.json")
        return JSONObject(root.readText()).getJSONArray("cases").objects().single { it.getString("id") == id }
    }

    private fun JSONObject.slip() = BetSlipRecord(
        mode = if (getString("mode") == "accumulator") BetModeRecord.ACCUMULATOR else BetModeRecord.SINGLE,
        selections = getJSONArray("selections").objects().map {
            SelectionRecord(it.getString("boutId"), it.getString("fighterId"), it.getString("odds"))
        },
        stake = getString("stake"),
    )

    private fun emptySlip() = BetSlipRecord(BetModeRecord.SINGLE, emptyList(), "10.00")

    private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }

    private fun JSONArray.strings() = (0 until length()).map { getString(it) }
}
