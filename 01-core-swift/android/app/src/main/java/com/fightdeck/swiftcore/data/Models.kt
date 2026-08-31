package com.fightdeck.swiftcore.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.math.BigDecimal

@Serializable
data class Event(
    val id: String,
    val name: String,
    val date: String,
    val venue: String,
    val city: String,
    val bouts: List<Bout>,
)

@Serializable
data class Bout(
    val id: String,
    val order: Int,
    val segment: String,
    val weightClass: String,
    val titleFight: Boolean,
    val scheduledRounds: Int,
    val redCorner: Corner,
    val blueCorner: Corner,
    val result: BoutResult,
)

@Serializable
data class Corner(
    @SerialName("fighterId") val fighterId: String,
    val name: String,
    val closingOdds: OddsQuote,
)

@Serializable
data class OddsQuote(val decimal: String, val fractional: String)

@Serializable
data class BoutResult(
    @SerialName("winnerId") val winnerId: String,
    val winnerName: String,
    val method: String,
    val detail: String,
    val endRound: Int,
    val endTime: String,
)

@Serializable
data class Fighter(
    val id: String,
    val name: String,
    val nickname: String? = null,
    val country: String? = null,
    val heightCm: Int? = null,
    val reachIn: Int? = null,
    val stance: String? = null,
    val record: FighterRecord,
    val portrait: String,
) {
    val recordDisplay: String get() = record.display
}

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

interface FightRepository {
    suspend fun loadEvents(): List<Event>
    suspend fun loadFighters(): List<Fighter>
}

class JsonFileRepository(
    private val datasetRoot: java.io.File,
    private val json: kotlinx.serialization.json.Json = kotlinx.serialization.json.Json {
        ignoreUnknownKeys = true
    },
) : FightRepository {
    suspend fun loadNews(): List<NewsItem> = load("news.json", "news")
    suspend fun loadMedia(): List<MediaItem> = load("media.json", "media")

    override suspend fun loadEvents(): List<Event> = load("events.json", "events")

    override suspend fun loadFighters(): List<Fighter> = load("fighters.json", "fighters")

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

fun com.fightdeck.swiftcore.core.FightCore.Companion.fromEvents(events: List<Event>): com.fightdeck.swiftcore.core.FightCore {
    val bouts = events.flatMap { it.bouts }.map {
        com.fightdeck.swiftcore.core.BoutIndex(
            it.id,
            it.redCorner.fighterId,
            it.blueCorner.fighterId,
            it.result.winnerId,
        )
    }
    return com.fightdeck.swiftcore.core.FightCore(bouts.associateBy { bout -> bout.id })
}
