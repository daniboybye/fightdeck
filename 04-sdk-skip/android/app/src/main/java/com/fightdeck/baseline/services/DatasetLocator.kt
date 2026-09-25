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
        return extractBundledDataset(context)
    }

    private fun extractBundledDataset(context: Context): File {
        val cache = File(context.filesDir, "dataset")
        if (cache.resolve("events.json").exists()) {
            return cache
        }
        cache.mkdirs()
        listOf("events.json", "fighters.json", "news.json", "media.json", "tokens.json").forEach { name ->
            runCatching {
                context.assets.open(name).use { input ->
                    cache.resolve(name).outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        val assetImages = File(cache, "assets")
        assetImages.mkdirs()
        context.assets.list("assets")?.forEach { name ->
            runCatching {
                context.assets.open("assets/$name").use { input ->
                    assetImages.resolve(name).outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
        return cache
    }
}
