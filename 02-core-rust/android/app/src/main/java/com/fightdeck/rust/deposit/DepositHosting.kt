package com.fightdeck.rust.deposit

import java.math.BigDecimal

data class DepositParams(
    val accessToken: String,
    val environment: String,
    val locale: String,
    val themeJSON: String,
    val currentBalance: BigDecimal,
)

sealed class DepositResult {
    data class Completed(val amount: BigDecimal) : DepositResult()
    data object Cancelled : DepositResult()
    data class Failed(val reason: String) : DepositResult()
}

interface DepositHosting {
    fun configure()
}

class NativeDepositHosting : DepositHosting {
    override fun configure() = Unit
}
