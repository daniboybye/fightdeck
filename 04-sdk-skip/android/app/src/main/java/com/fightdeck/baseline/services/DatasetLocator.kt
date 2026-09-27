package com.fightdeck.baseline.services

import android.content.Context
import java.io.File

object DatasetLocator {
    fun datasetRoot(context: Context): File {
        System.getProperty("fightdeck.dataset.root")?.let { return File(it) }
        listOf(
            File("/data/local/tmp/fightdeck/dataset"),
            File(context.filesDir, "dataset"),
            File(context.applicationInfo.dataDir).resolve("../../../fightdeck/dataset"),
            File(System.getProperty("user.dir") ?: ".", "../../dataset"),
        ).forEach { candidate ->
            if (candidate.resolve("events.json").exists()) {
                return candidate
            }
        }
        // Where pushDataset puts it; the view model reports the missing events.json from here.
        return File("/data/local/tmp/fightdeck/dataset")
    }
}
