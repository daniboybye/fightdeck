package com.fightdeck.baseline.core

import java.math.BigDecimal
import java.math.RoundingMode

object Money {
    private val SCALE = 2

    fun money(value: BigDecimal): BigDecimal = value.setScale(SCALE, RoundingMode.HALF_UP)

    fun parse(string: String): BigDecimal = BigDecimal(string)

    fun format(value: BigDecimal): String = money(value).toPlainString()

    fun formatCurrency(value: BigDecimal): String = "€${format(value)}"

    fun round(value: BigDecimal, scale: Int): BigDecimal = value.setScale(scale, RoundingMode.HALF_UP)
}
