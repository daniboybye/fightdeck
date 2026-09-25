package com.fightdeck.baseline.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The host's one piece of slip math, against the shared fixture. Validation, settlement and
 * cash-out are the SDK's, and `sdks/core/__tests__/fixtures.test.ts` runs every fixture on them.
 */
class BetSlipTests {
    @Test
    fun potentialReturnMatchesSlipMathFixture() {
        val root = System.getProperty("fightdeck.fixtures.root") ?: error("fightdeck.fixtures.root not set")
        val fixture = Json { ignoreUnknownKeys = true }
            .decodeFromString<SlipMathRoot>(File(root, "slip-math.json").readText())
        fixture.cases.forEach { case ->
            val slip = BetSlip(
                mode = BetMode.valueOf(case.mode),
                selections = case.selections.map { Selection(it.boutId, it.fighterId, Money.parse(it.odds)) },
                stake = Money.parse(case.stake),
            )
            assertEquals(case.expect.potentialReturn, Money.format(slip.potentialReturn), case.id)
        }
    }
}

@Serializable
private data class SlipMathRoot(val cases: List<SlipMathCase>)

@Serializable
private data class SlipMathCase(
    val id: String,
    val mode: String,
    val stake: String,
    val selections: List<SelectionDto>,
    val expect: Expect,
)

@Serializable
private data class SelectionDto(val boutId: String, val fighterId: String, val odds: String)

@Serializable
private data class Expect(val potentialReturn: String)
