package com.fightdeck.baseline

import android.content.Intent
import android.os.SystemClock
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RNColdStartBenchmark {
    private val device: UiDevice
        get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun unprewarmedFirstDepositSurface() {
        measureFirstDepositSurface(skipPrewarm = true)
    }

    @Test
    fun prewarmedFirstDepositSurface() {
        measureFirstDepositSurface(skipPrewarm = false)
    }

    private fun measureFirstDepositSurface(skipPrewarm: Boolean) {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        Runtime.getRuntime().exec(arrayOf("logcat", "-c")).waitFor()
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            if (skipPrewarm) {
                putExtra(MainActivity.EXTRA_SKIP_RN_PREWARM, true)
            }
        }
        val launchAt = SystemClock.elapsedRealtime()
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            scenario.onActivity { }
            assertTrue(device.wait(Until.hasObject(By.text("Slip")), 15_000))
            device.findObject(By.text("Slip")).click()
            assertTrue(device.wait(Until.hasObject(By.text("Deposit")), 10_000))
            device.findObject(By.text("Deposit")).click()
            val rnMountedMs = waitForDepositFeatureLog(sinceElapsedMs = launchAt, timeoutMs = 45_000)
            val uiReady = device.wait(Until.hasObject(By.textContains("Balance")), 5_000)
                || device.wait(Until.hasObject(By.textContains("Amount")), 3_000)
            val elapsed = if (rnMountedMs >= 0) rnMountedMs else SystemClock.elapsedRealtime() - launchAt
            android.util.Log.i(
                "FightDeckBenchmark",
                "mode=${if (skipPrewarm) "unprewarmed" else "prewarmed"} " +
                    "firstSurfaceMs=$elapsed rnMounted=${rnMountedMs >= 0} uiReady=$uiReady",
            )
            assertTrue(
                "DepositFeature must mount in RN (rnMounted=${rnMountedMs >= 0}, ui=$uiReady)",
                rnMountedMs >= 0 || uiReady,
            )
        }
    }

    private fun readReactNativeLog(): String =
        Runtime.getRuntime()
            .exec(arrayOf("logcat", "-d"))
            .inputStream
            .bufferedReader()
            .readText()

    private fun depositFeatureMounted(log: String): Boolean =
        log.contains("Running \"DepositFeature\"")

    private fun waitForDepositFeatureLog(sinceElapsedMs: Long, timeoutMs: Long): Long {
        val deadline = sinceElapsedMs + timeoutMs
        while (SystemClock.elapsedRealtime() < deadline) {
            if (depositFeatureMounted(readReactNativeLog())) {
                return SystemClock.elapsedRealtime() - sinceElapsedMs
            }
            Thread.sleep(100)
        }
        return -1
    }
}
