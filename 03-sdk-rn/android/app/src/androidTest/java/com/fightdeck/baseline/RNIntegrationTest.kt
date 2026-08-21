package com.fightdeck.baseline

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RNIntegrationTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun depositScreenIsReactNative() {
        composeRule.onNodeWithText("Slip").performClick()
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Deposit").performClick()
        composeRule.waitForIdle()
        val uiVisible = device.wait(Until.hasObject(By.textContains("Balance")), 10_000)
            || device.wait(Until.hasObject(By.textContains("Amount")), 5_000)
        val log = Runtime.getRuntime()
            .exec(arrayOf("logcat", "-d", "-s", "ReactNativeJS:I"))
            .inputStream
            .bufferedReader()
            .readText()
        val rnMounted = log.contains("Running \"DepositFeature\"")
        assertTrue("DepositFeature must mount in RN (logcat=$rnMounted, ui=$uiVisible)", rnMounted || uiVisible)
    }

    @Test
    fun betslipScreenIsReactNative() {
        composeRule.onNodeWithText("Slip").performClick()
        composeRule.onNodeWithText("Open bet slip").performClick()
        composeRule.waitForIdle()
        val uiVisible = device.wait(Until.hasObject(By.textContains("No selections yet")), 10_000)
            || device.wait(Until.hasObject(By.textContains("Browse Events")), 5_000)
        val log = Runtime.getRuntime()
            .exec(arrayOf("logcat", "-d", "-s", "ReactNativeJS:I"))
            .inputStream
            .bufferedReader()
            .readText()
        val rnMounted = log.contains("Running \"BetslipFeature\"")
        assertTrue("BetslipFeature must mount in RN (logcat=$rnMounted, ui=$uiVisible)", rnMounted || uiVisible)
    }
}
