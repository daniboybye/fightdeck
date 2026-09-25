package com.fightdeck.baseline

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.modules.core.DefaultHardwareBackBtnHandler
import com.fightdeck.baseline.ui.FightDeckApp
import com.fightdeck.rn.runtime.FightDeckRNRuntime

class MainActivity : ComponentActivity(), DefaultHardwareBackBtnHandler {
    private val reactHost: ReactHost
        get() = requireNotNull((application as ReactApplication).reactHost) {
            "ReactHost is not configured on the host Application"
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val skip = shouldSkipRNPrewarm(intent)
        MainApplication.skipRNPrewarm = skip
        if (!skip) {
            FightDeckRNRuntime.prewarm(application)
        }
        // The cold figure is logged by the runtime once the first surface exists; here it
        // would always read zero.
        val (_, prewarm) = FightDeckRNRuntime.startupMetrics()
        android.util.Log.i("FightDeckStartup", "prewarm=${prewarm}ms skipPrewarm=$skip")
        enableEdgeToEdge()
        setContent {
            FightDeckApp()
        }
    }

    override fun onResume() {
        super.onResume()
        reactHost.onHostResume(this, this)
    }

    override fun onPause() {
        reactHost.onHostPause(this)
        super.onPause()
    }

    override fun onDestroy() {
        reactHost.onHostDestroy(this)
        super.onDestroy()
    }

    override fun invokeDefaultOnBackPressed() {
        onBackPressedDispatcher.onBackPressed()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reactHost.onNewIntent(intent)
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
