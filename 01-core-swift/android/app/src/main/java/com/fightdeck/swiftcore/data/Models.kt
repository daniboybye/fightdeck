package com.fightdeck.swiftcore.data

import android.content.Context
import com.fightdeck.swiftcore.services.DatasetLocator
import com.fightdeck.swiftcore.services.LocalAssetServer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.math.BigDecimal

interface FightRepository {
    suspend fun loadEvents(): List<EventItem>
    suspend fun loadFighters(): List<FighterItem>
}

class JsonFileRepository(
    private val datasetRoot: File,
    private val json: Json = Json { ignoreUnknownKeys = true },
) : FightRepository {
    var shouldFail: Boolean = false

    suspend fun loadNews(): List<NewsItem> = load("news.json", "news")
    suspend fun loadMedia(): List<MediaItem> = load("media.json", "media")

    override suspend fun loadEvents(): List<EventItem> = load("events.json", "events")

    override suspend fun loadFighters(): List<FighterItem> = load("fighters.json", "fighters")

    fun imageUrl(path: String): String = "http://127.0.0.1:${LocalAssetServer.PORT}/$path"

    private suspend inline fun <reified T> load(fileName: String, key: String): List<T> =
        withContext(Dispatchers.IO) {
            if (shouldFail) error("network")
            val text = datasetRoot.resolve(fileName).readText()
            val wrapper = json.decodeFromString<Map<String, List<T>>>(text)
            wrapper[key] ?: error("missing $key")
        }

    companion object {
        fun create(context: Context): JsonFileRepository =
            JsonFileRepository(DatasetLocator.datasetRoot(context))
    }
}

@Serializable
data class EventItem(
    val id: String,
    val name: String,
    val date: String,
    val venue: String,
    val city: String,
    val bouts: List<BoutItem>,
)

@Serializable
data class BoutItem(
    val id: String,
    val order: Int,
    val segment: String,
    val weightClass: String,
    val titleFight: Boolean,
    val scheduledRounds: Int,
    val redCorner: CornerItem,
    val blueCorner: CornerItem,
    val result: BoutResultItem,
)

@Serializable
data class CornerItem(
    @SerialName("fighterId") val fighterId: String,
    val name: String,
    val closingOdds: OddsItem,
)

@Serializable
data class OddsItem(val decimal: String, val fractional: String)

@Serializable
data class BoutResultItem(
    @SerialName("winnerId") val winnerId: String,
    val winnerName: String,
    val method: String,
    val detail: String,
    val endRound: Int,
    val endTime: String,
)

@Serializable
data class FighterItem(
    val id: String,
    val name: String,
    val nickname: String? = null,
    val country: String? = null,
    val heightCm: Int? = null,
    val reachIn: Int? = null,
    val stance: String? = null,
    val record: FighterRecord,
    val portrait: String,
)

@Serializable
data class FighterRecord(
    val display: String,
    val wins: Int = 0,
    val losses: Int = 0,
    val draws: Int = 0,
    val noContests: Int = 0,
)

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
