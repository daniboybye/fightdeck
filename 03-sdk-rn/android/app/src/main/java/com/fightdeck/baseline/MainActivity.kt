package com.fightdeck.baseline

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.fightdeck.baseline.ui.FightDeckApp
import com.fightdeck.rn.runtime.FightDeckRNRuntime

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val skip = shouldSkipRNPrewarm(intent)
        MainApplication.skipRNPrewarm = skip
        if (!skip) {
            FightDeckRNRuntime.prewarm(application)
        }
        val (cold, prewarm) = FightDeckRNRuntime.startupMetrics()
        android.util.Log.i(
            "FightDeckStartup",
            "prewarm=${prewarm}ms cold=${cold}ms skipPrewarm=$skip",
        )
        enableEdgeToEdge()
        setContent {
            FightDeckApp()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun shouldSkipRNPrewarm(launchIntent: Intent?): Boolean {
        if (System.getenv("FIGHTDECK_SKIP_RN_PREWARM") == "1") {
            return true
        }
        return launchIntent?.getBooleanExtra(EXTRA_SKIP_RN_PREWARM, false) == true
    }

    companion object {
        const val EXTRA_SKIP_RN_PREWARM = "SkipRNPrewarm"
    }
}
