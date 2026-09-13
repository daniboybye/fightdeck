package com.fightdeck.swiftcore.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class NewsItem(
    val id: String,
    @SerialName("eventId") val eventId: String,
    val headline: String,
    val body: String,
    val source: String,
    val heroImage: String,
    val publishedAt: String,
    val readMinutes: Int,
)

@Serializable
data class MediaItem(
    val id: String,
    @SerialName("eventId") val eventId: String,
    val title: String,
    val kind: String,
    val url: String,
    val poster: String,
    val durationSeconds: Int,
    /**
     * Says which public test stream stands in for the licensed footage, so the demo never
     * passes a cartoon trailer off as a press conference.
     */
    val note: String? = null,
)

class JsonFileRepository(
    private val datasetRoot: java.io.File,
    private val json: kotlinx.serialization.json.Json = kotlinx.serialization.json.Json {
        ignoreUnknownKeys = true
    },
) {
    suspend fun loadNews(): List<NewsItem> = load("news.json", "news")
    suspend fun loadMedia(): List<MediaItem> = load("media.json", "media")

    fun imageUrl(path: String): String? =
        if (com.fightdeck.swiftcore.services.LocalAssetServer.port > 0) {
            "http://127.0.0.1:${com.fightdeck.swiftcore.services.LocalAssetServer.port}/$path"
        } else {
            null
        }

    private suspend inline fun <reified T> load(fileName: String, key: String): List<T> =
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val text = datasetRoot.resolve(fileName).readText()
            val wrapper = json.decodeFromString<Map<String, List<T>>>(text)
            wrapper[key] ?: error("missing $key")
        }

    companion object {
        fun create(context: android.content.Context): JsonFileRepository =
            JsonFileRepository(com.fightdeck.swiftcore.services.DatasetLocator.datasetRoot(context))
    }
}
