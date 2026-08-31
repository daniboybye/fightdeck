package com.fightdeck.baseline.sdk

import android.content.Context
import com.fightdeck.baseline.services.DatasetLocator
import fight.deck.core.BoutIndex
import fight.deck.core.FightCore
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import skip.lib.Array as SkipArray

object SdkFightCoreFactory {
    private val json = Json { ignoreUnknownKeys = true }

    fun build(context: Context): FightCore {
        val events = json
            .decodeFromString<EventsEnvelope>(
                DatasetLocator.datasetRoot(context).resolve("events.json").readText(),
            )
        val bouts = events.events.flatMap { it.bouts }.map {
            BoutIndex(
                id = it.id,
                redFighterID = it.redCorner.fighterId,
                blueFighterID = it.blueCorner.fighterId,
                winnerID = it.result.winnerId,
            )
        }
        return FightCore(bouts = SkipArray(bouts))
    }
}

@Serializable
private data class EventsEnvelope(val events: List<EventEnvelope>)

@Serializable
private data class EventEnvelope(val bouts: List<BoutEnvelope>)

@Serializable
private data class BoutEnvelope(
    val id: String,
    val redCorner: CornerEnvelope,
    val blueCorner: CornerEnvelope,
    val result: ResultEnvelope,
)

@Serializable
private data class CornerEnvelope(@SerialName("fighterId") val fighterId: String)

@Serializable
private data class ResultEnvelope(@SerialName("winnerId") val winnerId: String)
