package com.fightdeck.baseline.sdk

import android.content.Context
import com.fightdeck.baseline.services.DatasetLocator

object ThemeLoader {
    fun tokensJSON(context: Context): String {
        val path = DatasetLocator.datasetRoot(context)
            .resolve("../shared-ui-spec/tokens.json")
            .normalize()
        return runCatching { path.readText() }.getOrDefault("{}")
    }
}
