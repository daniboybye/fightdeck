package com.fightdeck.baseline.sdk

import android.content.Context
import com.fightdeck.baseline.services.DatasetLocator

object ThemeLoader {
    fun tokensJSON(context: Context): String = DatasetLocator.tokensJSON(context)
}
