#!/usr/bin/env python3
"""Generate the fightdeck dataset from verified source facts.

    ./tools/build-dataset.py

Why a generator instead of hand-written JSON: the odds appear in three notations
(American as published, decimal as the app's canonical form, fractional for the UK
display toggle) and every fighter's record has to be consistent with the results.
Typing that by hand across 20 bouts and 40 fighters guarantees at least one silent
error, and a silent error in the fixtures is a wrong number on a projector.

Everything in SOURCE below is a matter of public record. Provenance is in
dataset/README.md. Nothing here is invented; where a figure could not be verified it
is None and the schema allows it.
"""

from __future__ import annotations

import json
import unicodedata
from decimal import Decimal
from fractions import Fraction
from pathlib import Path
from typing import Any

DATASET_DIR = Path(__file__).resolve().parent.parent / "dataset"


# ---------------------------------------------------------------------------
# Odds conversion
# ---------------------------------------------------------------------------
# The app never shows American odds — the talk's audience is European and the core
# deliberately supports decimal and fractional only. American is kept here purely as
# the provenance trail back to the sportsbook that published it.

def american_to_decimal(american: int) -> Decimal:
    """Convert a published American moneyline to decimal, rounded to 2dp.

    Rounded because that is what a book displays and therefore what a settlement has to
    agree with. Carrying more precision than the price the punter saw would make the
    golden fixtures disagree with reality in the fourth decimal place.
    """
    if american > 0:
        raw = Decimal(american) / Decimal(100) + Decimal(1)
    else:
        raw = Decimal(100) / Decimal(-american) + Decimal(1)
    return raw.quantize(Decimal("0.01"))


def decimal_to_fractional(decimal_odds: Decimal) -> str:
    """Decimal to a reduced fraction, e.g. 4.60 -> '18/5'."""
    profit = Fraction(decimal_odds) - 1
    return f"{profit.numerator}/{profit.denominator}"


def price(american: int) -> dict[str, Any]:
    dec = american_to_decimal(american)
    return {
        "american": american,
        "decimal": f"{dec}",
        "fractional": decimal_to_fractional(dec),
    }


def slug(name: str) -> str:
    stripped = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return stripped.lower().replace("'", "").replace(".", "").replace(" ", "-")


# ---------------------------------------------------------------------------
# Fighters — records are PRE-FIGHT, as of the event the fighter appears on
# ---------------------------------------------------------------------------
# (name, nickname, country, height_cm, reach_in, stance, record W-L-D, no_contests)
FIGHTERS: list[tuple[str, str | None, str, int | None, int | None, str | None, str, int]] = [
    # UFC Freedom 250
    ("Justin Gaethje", "The Highlight", "United States", 180, 70, "orthodox", "27-5-0", 0),
    ("Ilia Topuria", "El Matador", "Spain", 170, 69, "orthodox", "17-0-0", 0),
    ("Ciryl Gane", "Bon Gamin", "France", 193, 81, "orthodox", "13-2-0", 1),
    ("Alex Pereira", "Poatan", "Brazil", 193, 79, "orthodox", "13-3-0", 0),
    ("Sean O'Malley", "Suga", "United States", 180, 72, "switch", "19-3-0", 1),
    ("Aiemann Zahabi", None, "Canada", 173, 68, "orthodox", "14-2-0", 0),
    ("Josh Hokit", None, "United States", 185, None, None, "9-0-0", 0),
    ("Derrick Lewis", "The Black Beast", "United States", 191, 79, "orthodox", "29-13-0", 1),
    ("Maurício Ruffy", None, "Brazil", 185, 76, "orthodox", "13-2-0", 0),
    ("Michael Chandler", "Iron", "United States", 173, 71, "orthodox", "23-10-0", 0),
    ("Bo Nickal", None, "United States", 185, 77, "switch", "8-1-0", 0),
    ("Kyle Daukaus", "The D'Arce Knight", "United States", 191, 76, "orthodox", "17-4-0", 1),
    ("Diego Lopes", None, "Brazil", 180, 72, "orthodox", "27-8-0", 0),
    ("Steve Garcia", "Mean Machine", "United States", 183, 75, "orthodox", "19-5-0", 0),
    # UFC 328
    ("Sean Strickland", "Tarzan", "United States", 185, 76, "orthodox", "30-7-0", 0),
    ("Khamzat Chimaev", "Borz", "United Arab Emirates", 188, 75, "orthodox", "15-0-0", 0),
    ("Joshua Van", None, "Myanmar", 165, 65, "orthodox", "16-2-0", 0),
    ("Tatsuro Taira", None, "Japan", 170, 70, "orthodox", "18-1-0", 0),
    ("Alexander Volkov", "Drago", "Russia", 201, 80, "orthodox", "39-11-0", 0),
    ("Waldo Cortes-Acosta", "Salsa Boy", "Dominican Republic", 193, 78, "orthodox", "17-2-0", 0),
    ("Sean Brady", None, "United States", 178, 72, "orthodox", "18-2-0", 0),
    ("Joaquin Buckley", "New Mansa", "United States", 178, 76, "switch", "21-7-0", 0),
    ("King Green", None, "United States", 178, 71, "orthodox", "34-17-1", 1),
    ("Jeremy Stephens", "Lil' Heathen", "United States", 175, 71, "orthodox", "29-22-0", 1),
    ("Ateba Gautier", None, "Cameroon", 193, 79, "orthodox", "10-1-0", 0),
    ("Osman Diaz", "Ozzy", "United States", 188, None, None, "10-3-0", 0),
    ("Yaroslav Amosov", None, "Ukraine", 180, 75, "orthodox", "29-1-0", 0),
    ("Joel Álvarez", "El Terror", "Spain", 191, 77, "orthodox", "23-3-0", 0),
    ("Grant Dawson", "KGD", "United States", 178, 72, "orthodox", "23-3-1", 0),
    ("Mateusz Rębecki", None, "Poland", 170, 66, "southpaw", "20-4-0", 0),
    ("Jim Miller", None, "United States", 173, 71, "orthodox", "38-19-0", 1),
    ("Jared Gordon", "Flash", "United States", 175, 68, "orthodox", "21-8-0", 1),
    ("Roman Kopylov", None, "Russia", 183, 75, "southpaw", "14-5-0", 0),
    ("Marco Tulio", None, "Brazil", 183, 74, "orthodox", "14-2-0", 0),
    ("Pat Sabatini", None, "United States", 173, 70, "orthodox", "21-5-0", 0),
    ("William Gomis", None, "France", 183, 73, "orthodox", "15-3-0", 0),
    ("Baisangur Susurkaev", None, "Russia", 183, 73, "orthodox", "11-0-0", 0),
    ("Djorden Santos", None, "Brazil", 185, 74, "orthodox", "11-2-0", 0),
    ("Jose Ochoa", None, "Peru", 165, 65, "orthodox", "8-2-0", 1),
    ("Clayton Carpenter", None, "United States", 168, 66, "orthodox", "8-2-0", 0),
]


# ---------------------------------------------------------------------------
# Bouts
# ---------------------------------------------------------------------------
# (red, blue, weight_class, title, scheduled_rounds, winner, method, detail,
#  round, time, red_american, blue_american)
# "red" is the first-named fighter on the official card.

FREEDOM_250_BOUTS = [
    ("Ilia Topuria", "Justin Gaethje", "lightweight", "UFC Lightweight Championship", 5,
     "Justin Gaethje", "tko", "Corner stoppage", 4, "5:00", -500, 360),
    ("Alex Pereira", "Ciryl Gane", "heavyweight", "Interim UFC Heavyweight Championship", 5,
     "Ciryl Gane", "tko", "Punches", 2, "1:27", -115, 105),
    ("Sean O'Malley", "Aiemann Zahabi", "bantamweight", None, 3,
     "Sean O'Malley", "ko", "Right hand", 2, "4:02", -440, 330),
    ("Josh Hokit", "Derrick Lewis", "heavyweight", None, 3,
     "Josh Hokit", "tko", "Punches", 2, "4:09", -400, 310),
    ("Maurício Ruffy", "Michael Chandler", "lightweight", None, 3,
     "Maurício Ruffy", "tko", "Spinning wheel kick and punches", 1, "4:29", -540, 395),
    ("Bo Nickal", "Kyle Daukaus", "middleweight", None, 3,
     "Bo Nickal", "tko", "Punches and elbows", 1, "4:34", -335, 250),
    ("Diego Lopes", "Steve Garcia", "featherweight", None, 3,
     "Diego Lopes", "ko", "Punches", 2, "2:42", -165, 135),
]

UFC_328_BOUTS = [
    ("Khamzat Chimaev", "Sean Strickland", "middleweight", "UFC Middleweight Championship", 5,
     "Sean Strickland", "split_decision", "48-47, 48-47, 47-48", 5, "5:00", -500, 375),
    ("Tatsuro Taira", "Joshua Van", "flyweight", "UFC Flyweight Championship", 5,
     "Joshua Van", "tko", "Front kick to the body and punches", 5, "1:32", -152, 123),
    ("Alexander Volkov", "Waldo Cortes-Acosta", "heavyweight", None, 3,
     "Alexander Volkov", "unanimous_decision", "30-27, 29-28, 29-28", 3, "5:00", -141, 114),
    ("Joaquin Buckley", "Sean Brady", "welterweight", None, 3,
     "Sean Brady", "unanimous_decision", "30-25, 30-25, 30-27", 3, "5:00", -167, 135),
    ("King Green", "Jeremy Stephens", "catchweight_160", None, 3,
     "King Green", "submission", "Rear-naked choke", 1, "4:20", -420, 310),
    ("Ateba Gautier", "Osman Diaz", "middleweight", None, 3,
     "Ateba Gautier", "ko", "Right hand", 2, "1:10", -1430, 850),
    ("Yaroslav Amosov", "Joel Álvarez", "welterweight", None, 3,
     "Yaroslav Amosov", "submission", "Arm-triangle choke", 2, "1:13", -190, 150),
    ("Grant Dawson", "Mateusz Rębecki", "lightweight", None, 3,
     "Grant Dawson", "submission", "Rear-naked choke", 3, "4:42", -143, 115),
    ("Jared Gordon", "Jim Miller", "lightweight", None, 3,
     "Jim Miller", "submission", "Guillotine choke", 1, "3:29", -278, 215),
    ("Marco Tulio", "Roman Kopylov", "middleweight", None, 3,
     "Roman Kopylov", "unanimous_decision", "29-28, 29-28, 29-28", 3, "5:00", -186, 150),
    ("Pat Sabatini", "William Gomis", "featherweight", None, 3,
     "Pat Sabatini", "unanimous_decision", "30-27, 30-27, 29-28", 3, "5:00", -177, 140),
    ("Baisangur Susurkaev", "Djorden Santos", "middleweight", None, 3,
     "Baisangur Susurkaev", "technical_submission", "Rear-naked choke", 3, "4:12", -770, 525),
    ("Jose Ochoa", "Clayton Carpenter", "flyweight", None, 3,
     "Jose Ochoa", "unanimous_decision", "30-27, 30-27, 30-27", 3, "5:00", -182, 145),
]

SEGMENTS_7 = ["main"] + ["main_card"] * 6
SEGMENTS_13 = ["main"] + ["main_card"] * 4 + ["prelim"] * 4 + ["early_prelim"] * 4


def build_bouts(rows: list[tuple], segments: list[str], event_id: str) -> list[dict[str, Any]]:
    bouts = []
    for index, (row, segment) in enumerate(zip(rows, segments), start=1):
        (red, blue, weight, title, rounds, winner, method, detail,
         end_round, end_time, red_odds, blue_odds) = row
        bouts.append({
            "id": f"{event_id}-bout-{index:02d}",
            "order": index,
            "segment": segment,
            "weightClass": weight,
            "titleFight": title is not None,
            "title": title,
            "scheduledRounds": rounds,
            "redCorner": {"fighterId": slug(red), "name": red, "closingOdds": price(red_odds)},
            "blueCorner": {"fighterId": slug(blue), "name": blue, "closingOdds": price(blue_odds)},
            "result": {
                "winnerId": slug(winner),
                "winnerName": winner,
                "method": method,
                "detail": detail,
                "endRound": end_round,
                "endTime": end_time,
                # Precomputed so every core settles against the same value rather than
                # each reimplementing "did this go the distance?" and disagreeing.
                "wentToDecision": method.endswith("decision"),
                "finish": not method.endswith("decision"),
            },
        })
    return bouts


EVENTS = [
    {
        "id": "ufc-freedom-250",
        "name": "UFC Freedom 250",
        "alsoKnownAs": ["UFC White House", "UFC at the White House"],
        "date": "2026-06-14",
        "venue": "South Lawn of the White House",
        "city": "Washington, D.C.",
        "country": "United States",
        # Not officially announced. ~4,300 invite-only was widely reported; an estimate
        # dressed up as a fact is exactly the kind of thing that gets challenged from the
        # floor, so it stays null with the estimate in a sibling field.
        "attendance": None,
        "attendanceNote": "Not officially announced; approximately 4,300 invite-only guests reported",
        "bouts": build_bouts(FREEDOM_250_BOUTS, SEGMENTS_7, "ufc-freedom-250"),
    },
    {
        "id": "ufc-328",
        "name": "UFC 328: Chimaev vs. Strickland",
        "alsoKnownAs": [],
        "date": "2026-05-09",
        "venue": "Prudential Center",
        "city": "Newark, New Jersey",
        "country": "United States",
        "attendance": 17783,
        "gateUsd": 7518918,
        "bouts": build_bouts(UFC_328_BOUTS, SEGMENTS_13, "ufc-328"),
    },
]


# ---------------------------------------------------------------------------
# News feed
# ---------------------------------------------------------------------------
# Written for this demo. The underlying facts (results, records, milestones) are real;
# the prose is not a reproduction of anybody's article, and every item is stamped with
# source "fightdeck-demo" so nothing here can be mistaken for reporting.

NEWS = [
    ("gaethje-unifies", "ufc-freedom-250",
     "Gaethje unifies at the White House as Topuria's corner calls it",
     "Justin Gaethje entered as interim champion and left as the undisputed one. Ilia "
     "Topuria's corner stopped the fight between the fourth and fifth rounds, ending the "
     "first unbeaten run at lightweight in years.",
     "2026-06-14T23:40:00Z", 4),
    ("all-seven-finish", "ufc-freedom-250",
     "Seven fights, seven knockouts, no judges required",
     "Every bout on the South Lawn card ended by knockout or technical knockout. No UFC "
     "event had previously gone an entire card without a single fight reaching the "
     "scorecards by way of KO or TKO alone.",
     "2026-06-15T08:15:00Z", 3),
    ("gane-interim", "ufc-freedom-250",
     "Gane stops Pereira in the second to take the interim heavyweight belt",
     "In a bout the books could not separate, Ciryl Gane needed less than seven minutes. "
     "Alex Pereira's move up to heavyweight ends with his first stoppage loss in the "
     "division.",
     "2026-06-14T22:05:00Z", 3),
    ("ruffy-wheel-kick", "ufc-freedom-250",
     "Ruffy ends Chandler with a spinning wheel kick",
     "Maurício Ruffy was a heavy favourite and still found the most spectacular way "
     "available, landing a spinning wheel kick late in the opening round.",
     "2026-06-14T21:20:00Z", 2),
    ("strickland-upset", "ufc-328",
     "Strickland outpoints Chimaev to take the middleweight title",
     "Two judges saw it 48-47 for Sean Strickland and one saw it the other way. Khamzat "
     "Chimaev's undefeated record ends in Newark at the hands of a fighter the books "
     "priced at better than 4/1.",
     "2026-05-10T04:30:00Z", 5),
    ("miller-milestone", "ufc-328",
     "Jim Miller submits Gordon in the first, extends a record that may never fall",
     "A guillotine at 3:29 of the opening round adds another line to the longest tenure "
     "in UFC history. Miller was the underdog on the night.",
     "2026-05-10T03:10:00Z", 3),
    ("van-defends", "ufc-328",
     "Joshua Van defends the flyweight title with a fifth-round stoppage",
     "Tatsuro Taira was ahead on the cards for long stretches before a front kick to the "
     "body changed the fight ninety seconds into the final round.",
     "2026-05-10T02:45:00Z", 4),
    ("brady-shutout", "ufc-328",
     "Brady hands Buckley a pair of 30-25 cards",
     "Sean Brady controlled all three rounds against a favoured Joaquin Buckley, taking "
     "two 10-8 rounds on two of the three scorecards.",
     "2026-05-10T01:55:00Z", 2),
]


def build_news() -> list[dict[str, Any]]:
    return [
        {
            "id": news_id,
            "eventId": event_id,
            "headline": headline,
            "body": body,
            "publishedAt": published,
            "readMinutes": minutes,
            "source": "fightdeck-demo",
            "heroImage": f"assets/events/{event_id}.jpg",
        }
        for news_id, event_id, headline, body, published, minutes in NEWS
    ]


# ---------------------------------------------------------------------------
# Video
# ---------------------------------------------------------------------------
# A YouTube link is not usable here: playing it in AVPlayer means extracting the stream,
# which breaks YouTube's terms, and the compliant alternative is an iframe in a WebView,
# which would defeat the entire point of the "never share this screen" argument. So the
# video screen plays genuine HLS and MP4 from long-lived public test hosts.
#
# Apple's BipBop is the reference HLS stream AVPlayer is tested against and ExoPlayer
# handles it without configuration. The W3C-hosted MP4 is the progressive-download
# fallback for anything that cannot do HLS.

MEDIA = [
    {
        "id": "freedom-250-presser",
        "eventId": "ufc-freedom-250",
        "title": "Post-fight press conference",
        "kind": "hls",
        "url": "https://devstreaming-cdn.apple.com/videos/streaming/examples/"
               "img_bipbop_adv_example_fmp4/master.m3u8",
        "poster": "assets/events/ufc-freedom-250.jpg",
        "durationSeconds": 1800,
        "note": "Public HLS test stream standing in for licensed footage",
    },
    {
        "id": "ufc-328-presser",
        "eventId": "ufc-328",
        "title": "Post-fight press conference",
        "kind": "mp4",
        "url": "https://media.w3.org/2010/05/sintel/trailer.mp4",
        "poster": "assets/events/ufc-328.jpg",
        "durationSeconds": 52,
        "note": "Public MP4 test asset standing in for licensed footage",
    },
]


def build_fighters() -> list[dict[str, Any]]:
    out = []
    for name, nickname, country, height, reach, stance, record, no_contests in FIGHTERS:
        wins, losses, draws = (int(part) for part in record.split("-"))
        out.append({
            "id": slug(name),
            "name": name,
            "nickname": nickname,
            "country": country,
            "heightCm": height,
            "reachIn": reach,
            "stance": stance,
            "record": {
                "wins": wins,
                "losses": losses,
                "draws": draws,
                "noContests": no_contests,
                "display": record + (f" ({no_contests} NC)" if no_contests else ""),
            },
            "portrait": f"assets/fighters/{slug(name)}.jpg",
        })
    return out


def write(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  wrote {path.relative_to(DATASET_DIR.parent)}")


def main() -> None:
    fighters = build_fighters()

    # Sanity: every fighter referenced by a bout must exist, and vice versa. A dangling
    # reference here becomes a blank portrait in five apps at once.
    known = {fighter["id"] for fighter in fighters}
    referenced: set[str] = set()
    for event in EVENTS:
        for bout in event["bouts"]:
            for corner in ("redCorner", "blueCorner"):
                referenced.add(bout[corner]["fighterId"])
            assert bout["result"]["winnerId"] in (
                bout["redCorner"]["fighterId"], bout["blueCorner"]["fighterId"]
            ), f"{bout['id']}: winner is not in either corner"

    missing = referenced - known
    orphans = known - referenced
    assert not missing, f"bouts reference unknown fighters: {sorted(missing)}"
    assert not orphans, f"fighters appear in no bout: {sorted(orphans)}"

    news = build_news()
    event_ids = {event["id"] for event in EVENTS}
    for item in news:
        assert item["eventId"] in event_ids, f"{item['id']} points at an unknown event"
    for item in MEDIA:
        assert item["eventId"] in event_ids, f"{item['id']} points at an unknown event"

    write(DATASET_DIR / "fighters.json", {"fighters": fighters})
    write(DATASET_DIR / "events.json", {"events": EVENTS})
    write(DATASET_DIR / "news.json", {"news": news})
    write(DATASET_DIR / "media.json", {"media": MEDIA})

    total_bouts = sum(len(event["bouts"]) for event in EVENTS)
    finishes = sum(
        1 for event in EVENTS for bout in event["bouts"] if bout["result"]["finish"]
    )
    print(
        f"\n  {len(fighters)} fighters, {total_bouts} bouts, {finishes} finishes, "
        f"{len(news)} news items, {len(MEDIA)} videos"
    )


if __name__ == "__main__":
    main()
