package com.fightdeck.baseline.core

import java.math.BigDecimal
import java.math.RoundingMode

object Money {
    private val SCALE = 2

    fun money(value: BigDecimal): BigDecimal = value.setScale(SCALE, RoundingMode.HALF_UP)

    fun parse(string: String): BigDecimal =
        runCatching { BigDecimal(string.trim()) }.getOrDefault(BigDecimal.ZERO)

    fun format(value: BigDecimal): String = money(value).toPlainString()

    fun formatCurrency(value: BigDecimal): String = "€${format(value)}"
}
