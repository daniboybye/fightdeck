package com.fightdeck.swiftcore.catalog

import com.fightdeck.fightevents.EventCatalogBridge

// FightEvents' presentation models, as Compose holds them. Every value is already worded and
// formatted on the Swift side; each read below is one JNI call returning a tuple of plain Java
// values, and all this file does is turn its parallel arrays back into rows.

data class EventCard(
    val id: String,
    val name: String,
    /** `yyyy-MM-dd`; the screen formats it for the device locale. */
    val date: String,
    val locationLine: String,
    val boutCount: Int,
    val posterPath: String,
)

data class CornerCard(
    val fighterId: String,
    val name: String,
    val record: String,
    val portraitPath: String,
    /** The closing price as the dataset writes it: what a tap puts on the slip. */
    val odds: String,
    val oddsLabel: String,
)

data class BoutCard(
    val id: String,
    val headline: String,
    val weightClass: String,
    val titleFight: Boolean,
    val red: CornerCard,
    val blue: CornerCard,
    val resultLine: String,
    val winnerName: String,
    val method: String,
    val detail: String,
    val endedLine: String,
)

data class CardSectionCard(val title: String, val bouts: List<BoutCard>)

data class FighterCard(
    val id: String,
    val name: String,
    val nickname: String?,
    val record: String,
    val portraitPath: String,
    val profileRows: List<Pair<String, String>>,
    /** Only what the dataset has. */
    val physicalRows: List<Pair<String, String>>,
)

data class TapeRowCard(val label: String, val red: String, val blue: String)

data class LegContext(val fighterName: String, val subtitle: String)

data class NewsItem(
    val id: String,
    val eventId: String,
    val headline: String,
    val body: String,
    val readMinutes: Int,
    val source: String,
    val heroImage: String,
)

data class MediaItem(
    val id: String,
    val eventId: String,
    val title: String,
    val kind: String,
    val url: String,
    val poster: String,
    /** `3:24`. */
    val duration: String,
    val note: String?,
)

// jextract widens Swift's Int to Java's long, so every count arrives as a Long.
fun EventCatalogBridge.eventCards(): List<EventCard> {
    val events = events()
    return events.ids().indices.map {
        EventCard(
            id = events.ids()[it],
            name = events.names()[it],
            date = events.dates()[it],
            locationLine = events.locations()[it],
            boutCount = events.boutCounts()[it].toInt(),
            posterPath = events.posters()[it],
        )
    }
}

/** One call for the sections, then one per bout. */
fun EventCatalogBridge.sectionCards(eventID: String): List<CardSectionCard> {
    val sections = cardSections(eventID)
    return sections.titles().indices.map { index ->
        CardSectionCard(sections.titles()[index], sections.boutIDs()[index].map(::boutCard))
    }
}

fun EventCatalogBridge.boutCard(boutID: String): BoutCard {
    val bout = bout(boutID)
    // Two corners, red first.
    val corners = (0..1).map {
        CornerCard(
            fighterId = bout.fighterIDs()[it],
            name = bout.names()[it],
            record = bout.records()[it],
            portraitPath = bout.portraits()[it],
            odds = bout.odds()[it],
            oddsLabel = bout.oddsLabels()[it],
        )
    }
    return BoutCard(
        id = bout.id(),
        headline = bout.headline(),
        weightClass = bout.weightClass(),
        titleFight = bout.titleFight(),
        red = corners[0],
        blue = corners[1],
        resultLine = bout.resultLine(),
        winnerName = bout.winnerName(),
        method = bout.method(),
        detail = bout.detail(),
        endedLine = bout.ended(),
    )
}

fun EventCatalogBridge.fighterCard(id: String): FighterCard {
    val fighter = fighter(id)
    return FighterCard(
        id = fighter.id(),
        name = fighter.name(),
        nickname = fighter.nickname().orElse(null),
        record = fighter.record(),
        portraitPath = fighter.portrait(),
        profileRows = fighter.profileLabels().zip(fighter.profileValues()),
        physicalRows = fighter.physicalLabels().zip(fighter.physicalValues()),
    )
}

fun EventCatalogBridge.tapeRows(boutID: String): List<TapeRowCard> {
    val tape = taleOfTheTape(boutID)
    return tape.labels().indices.map { TapeRowCard(tape.labels()[it], tape.red()[it], tape.blue()[it]) }
}

fun EventCatalogBridge.legContextCard(boutID: String, fighterID: String): LegContext {
    val context = legContext(boutID, fighterID)
    return LegContext(context.fighterName(), context.subtitle())
}

fun EventCatalogBridge.newsItems(): List<NewsItem> {
    val news = news()
    return news.ids().indices.map {
        NewsItem(
            id = news.ids()[it],
            eventId = news.eventIDs()[it],
            headline = news.headlines()[it],
            body = news.bodies()[it],
            readMinutes = news.readMinutes()[it].toInt(),
            source = news.sources()[it],
            heroImage = news.heroImages()[it],
        )
    }
}

fun EventCatalogBridge.mediaItems(): List<MediaItem> {
    val media = media()
    return media.ids().indices.map {
        MediaItem(
            id = media.ids()[it],
            eventId = media.eventIDs()[it],
            title = media.titles()[it],
            kind = media.kinds()[it],
            url = media.urls()[it],
            poster = media.posters()[it],
            duration = media.durations()[it],
            note = media.notes()[it].ifEmpty { null },
        )
    }
}
