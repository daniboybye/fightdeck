package com.fightdeck.baseline

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.fightdeck.baseline.ui.FightDeckApp
import skip.foundation.ProcessInfo

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProcessInfo.launch(context = applicationContext)
        enableEdgeToEdge()
        setContent {
            FightDeckApp()
        }
    }
}
