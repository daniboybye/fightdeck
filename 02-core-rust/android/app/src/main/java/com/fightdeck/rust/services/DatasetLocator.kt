package com.fightdeck.rust.services

import android.content.Context
import java.io.File

object DatasetLocator {
    class NotFoundException : Exception(
        "Dataset not found. Push the repo dataset to /data/local/tmp/fightdeck/dataset and retry.",
    )

    fun datasetRoot(context: Context): File =
        findDatasetRoot(context) ?: throw NotFoundException()

    fun findDatasetRoot(context: Context): File? {
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
        return null
    }
}
