package com.fightdeck.swiftcore.catalog

import com.fightdeck.fightevents.EventCatalogBridge
import com.fightdeck.fightevents.TaleOfTheTapeBridge
import com.fightdeck.fightevents.TapeRowBridge

data class EventCard(
    val id: String,
    val name: String,
    val date: String,
    val venue: String,
    val city: String,
    val boutCount: Int,
)

data class CardSectionCard(
    val title: String,
    val boutIDs: List<String>,
)

data class BoutCard(
    val id: String,
    val eventID: String,
    val headline: String,
    val weightClassDisplay: String,
    val titleFight: Boolean,
    val redFighterID: String,
    val redName: String,
    val redOddsDecimal: String,
    val redRecord: String,
    val blueFighterID: String,
    val blueName: String,
    val blueOddsDecimal: String,
    val blueRecord: String,
    val resultLine: String,
    val winnerName: String,
    val resultMethod: String,
    val resultDetail: String,
    val endRound: Int,
    val endTime: String,
)

data class FighterCard(
    val id: String,
    val name: String,
    val nickname: String,
    val country: String,
    val recordDisplay: String,
    val wins: Int,
    val losses: Int,
    val noContests: Int,
    /** Already formatted by the core; empty means the dataset carries no value. */
    val heightDisplay: String,
    val reachDisplay: String,
    val stanceDisplay: String,
    val portraitPath: String,
)

// jextract widens Swift's Int to Java's long, so every count arrives as a Long.
fun EventCatalogBridge.loadEvents(): List<EventCard> =
    (0 until eventCount).map { index ->
        val id = eventID(index)
        EventCard(
            id = id,
            name = eventName(id),
            date = eventDate(id),
            venue = eventVenue(id),
            city = eventCity(id),
            boutCount = eventBoutCount(id).toInt(),
        )
    }

fun EventCatalogBridge.cardSections(eventID: String): List<CardSectionCard> =
    (0 until cardSectionCount(eventID)).map { sectionIndex ->
        CardSectionCard(
            title = cardSectionTitle(eventID, sectionIndex),
            boutIDs = (0 until cardSectionBoutCount(eventID, sectionIndex)).map { boutIndex ->
                cardSectionBoutID(eventID, sectionIndex, boutIndex)
            },
        )
    }

// The generated bindings are Java, which carries no parameter names, so the corner
// selector has to be passed positionally.
private const val RED = true
private const val BLUE = false

fun EventCatalogBridge.boutCard(boutID: String): BoutCard =
    BoutCard(
        id = boutID,
        eventID = boutEventID(boutID),
        headline = boutHeadline(boutID),
        weightClassDisplay = boutWeightClassDisplay(boutID),
        titleFight = boutTitleFight(boutID),
        redFighterID = cornerFighterID(boutID, RED),
        redName = cornerName(boutID, RED),
        redOddsDecimal = cornerOddsDecimal(boutID, RED),
        redRecord = cornerRecordDisplay(boutID, RED),
        blueFighterID = cornerFighterID(boutID, BLUE),
        blueName = cornerName(boutID, BLUE),
        blueOddsDecimal = cornerOddsDecimal(boutID, BLUE),
        blueRecord = cornerRecordDisplay(boutID, BLUE),
        resultLine = boutResultLine(boutID),
        winnerName = boutWinnerName(boutID),
        resultMethod = boutResultMethod(boutID),
        resultDetail = boutResultDetail(boutID),
        endRound = boutEndRound(boutID).toInt(),
        endTime = boutEndTime(boutID),
    )

fun EventCatalogBridge.fighterCard(id: String): FighterCard =
    FighterCard(
        id = id,
        name = fighterName(id),
        nickname = fighterNickname(id),
        country = fighterCountry(id),
        recordDisplay = fighterRecordDisplay(id),
        wins = fighterWins(id).toInt(),
        losses = fighterLosses(id).toInt(),
        noContests = fighterNoContests(id).toInt(),
        heightDisplay = fighterHeightDisplay(id),
        reachDisplay = fighterReachDisplay(id),
        stanceDisplay = fighterStanceDisplay(id),
        portraitPath = fighterPortraitPath(id),
    )
