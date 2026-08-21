package com.fightdeck.baseline.core

import java.math.BigDecimal
import java.math.RoundingMode
import kotlin.math.abs

object OddsEngine {
    fun decimalToFractional(decimalOdds: BigDecimal): String {
        val profit = decimalOdds.subtract(BigDecimal.ONE)
        val scaled = profit.multiply(BigDecimal(10_000)).toLong()
        val divisor = gcd(abs(scaled), 10_000)
        return "${scaled / divisor}/${10_000 / divisor}"
    }

    fun fractionalToDecimal(fractional: String): BigDecimal {
        val parts = fractional.split("/")
        require(parts.size == 2)
        val numerator = parts[0].toInt()
        val denominator = parts[1].toInt()
        val profit = BigDecimal(numerator).divide(BigDecimal(denominator), 12, RoundingMode.HALF_UP)
        return Money.money(profit.add(BigDecimal.ONE))
    }

    fun impliedProbability(decimalOdds: BigDecimal): BigDecimal =
        Money.round(BigDecimal.ONE.divide(decimalOdds, 12, RoundingMode.HALF_UP), 4)

    private fun gcd(a: Long, b: Int): Long {
        var x = a
        var y = b.toLong()
        while (y != 0L) {
            val temp = y
            y = x % y
            x = temp
        }
        return maxOf(x, 1)
    }
}
