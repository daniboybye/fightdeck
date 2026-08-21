#!/usr/bin/env python3
"""Generate the FightCore golden fixtures.

    ./tools/build-fixtures.py

Contains a reference implementation of the rules in contract/fightcore-api.md, used
solely to compute expected values. It is not shipped to any app — it exists so that
every expectation in fixtures/ is derived from the stated rules rather than typed in
by hand. A hand-typed expectation is a second implementation with no tests of its own,
and when it disagrees with the first you cannot tell which one is wrong.
"""

from __future__ import annotations

import json
from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = ROOT / "dataset"
FIXTURES_DIR = ROOT / "contract" / "fixtures"

# Limits — must match section 4 of the contract exactly.
MIN_STAKE = Decimal("1.00")
MAX_STAKE = Decimal("5000.00")
MAX_SELECTIONS = 12
MIN_ACCA_LEGS = 2
MAX_PAYOUT = Decimal("100000.00")
CASH_OUT_MARGIN = Decimal("0.05")

ERROR_ORDER = [
    "empty_slip",
    "stake_below_minimum",
    "stake_above_maximum",
    "insufficient_balance",
    "too_many_selections",
    "accumulator_needs_two_legs",
    "duplicate_bout",
    "unknown_bout",
    "fighter_not_in_bout",
    "payout_exceeds_limit",
]


def money(value: Decimal) -> Decimal:
    """Round to a monetary amount. HALF_UP, applied exactly once, at the end."""
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def to_fractional(decimal_odds: Decimal) -> str:
    profit = Fraction(decimal_odds) - 1
    return f"{profit.numerator}/{profit.denominator}"


def implied_probability(decimal_odds: Decimal) -> Decimal:
    return (Decimal(1) / decimal_odds).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)


# ---------------------------------------------------------------------------
# Dataset access
# ---------------------------------------------------------------------------

def load_dataset() -> tuple[dict[str, dict], dict[str, dict]]:
    events = json.loads((DATASET_DIR / "events.json").read_text(encoding="utf-8"))["events"]
    bouts: dict[str, dict] = {}
    for event in events:
        for bout in event["bouts"]:
            bouts[bout["id"]] = bout
    fighters = json.loads((DATASET_DIR / "fighters.json").read_text(encoding="utf-8"))["fighters"]
    return bouts, {fighter["id"]: fighter for fighter in fighters}


BOUTS, FIGHTERS = load_dataset()


def odds_for(bout_id: str, fighter_id: str) -> Decimal:
    bout = BOUTS[bout_id]
    for corner in ("redCorner", "blueCorner"):
        if bout[corner]["fighterId"] == fighter_id:
            return Decimal(bout[corner]["closingOdds"]["decimal"])
    raise KeyError(f"{fighter_id} is not in {bout_id}")


def winner_of(bout_id: str) -> str:
    return BOUTS[bout_id]["result"]["winnerId"]


def selection(bout_id: str, fighter_id: str) -> dict[str, Any]:
    return {
        "boutId": bout_id,
        "fighterId": fighter_id,
        "odds": f"{odds_for(bout_id, fighter_id)}",
    }


# ---------------------------------------------------------------------------
# Reference implementation
# ---------------------------------------------------------------------------

def combined_odds_exact(selections: list[dict]) -> Decimal:
    product = Decimal(1)
    for sel in selections:
        product *= Decimal(sel["odds"])
    return product


def slip_state(mode: str, selections: list[dict], stake: Decimal) -> dict[str, Any]:
    if mode == "accumulator":
        exact = combined_odds_exact(selections)
        total_stake = stake
        potential_return = money(stake * exact)
        state: dict[str, Any] = {
            "combinedOddsExact": f"{exact.normalize():f}",
            "combinedOddsDisplay": f"{exact.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)}",
        }
    else:
        total_stake = stake * len(selections)
        # Each single is its own bet, so each is rounded on its own. Rounding the sum
        # instead gives a different number, and it is the wrong one.
        potential_return = sum(
            (money(stake * Decimal(sel["odds"])) for sel in selections), Decimal(0)
        )
        state = {}

    state.update({
        "totalStake": f"{money(total_stake)}",
        "potentialReturn": f"{money(potential_return)}",
        "potentialProfit": f"{money(potential_return - total_stake)}",
    })
    return state


def validate(mode: str, selections: list[dict], stake: Decimal, balance: Decimal) -> list[str]:
    errors: set[str] = set()

    if not selections:
        errors.add("empty_slip")
    if stake < MIN_STAKE:
        errors.add("stake_below_minimum")
    if stake > MAX_STAKE:
        errors.add("stake_above_maximum")
    if len(selections) > MAX_SELECTIONS:
        errors.add("too_many_selections")
    if mode == "accumulator" and 0 < len(selections) < MIN_ACCA_LEGS:
        errors.add("accumulator_needs_two_legs")

    bout_ids = [sel["boutId"] for sel in selections]
    if len(bout_ids) != len(set(bout_ids)):
        errors.add("duplicate_bout")

    for sel in selections:
        bout = BOUTS.get(sel["boutId"])
        if bout is None:
            errors.add("unknown_bout")
            continue
        corners = {bout["redCorner"]["fighterId"], bout["blueCorner"]["fighterId"]}
        if sel["fighterId"] not in corners:
            errors.add("fighter_not_in_bout")

    if selections and "unknown_bout" not in errors:
        state = slip_state(mode, selections, stake)
        if Decimal(state["totalStake"]) > balance:
            errors.add("insufficient_balance")
        if Decimal(state["potentialReturn"]) > MAX_PAYOUT:
            errors.add("payout_exceeds_limit")
    elif stake > balance:
        errors.add("insufficient_balance")

    return [code for code in ERROR_ORDER if code in errors]


def leg_outcome(sel: dict, voided: set[str]) -> str:
    if sel["boutId"] in voided:
        return "void"
    return "won" if winner_of(sel["boutId"]) == sel["fighterId"] else "lost"


def settle(mode: str, selections: list[dict], stake: Decimal,
           voided: set[str] | None = None) -> dict[str, Any]:
    voided = voided or set()
    outcomes = [leg_outcome(sel, voided) for sel in selections]

    if mode == "accumulator":
        total_stake = stake
        if "lost" in outcomes:
            returned, status = Decimal("0.00"), "lost"
        else:
            # A void leg contributes 1.00: it falls out of the accumulator without
            # killing it, which is the standard rule everywhere.
            product = Decimal(1)
            for sel, outcome in zip(selections, outcomes):
                product *= Decimal(1) if outcome == "void" else Decimal(sel["odds"])
            returned, status = money(stake * product), "won"
    else:
        total_stake = stake * len(selections)
        returned = Decimal(0)
        for sel, outcome in zip(selections, outcomes):
            if outcome == "won":
                returned += money(stake * Decimal(sel["odds"]))
            elif outcome == "void":
                returned += stake
        won = outcomes.count("won")
        if won == len(outcomes):
            status = "won"
        elif won == 0:
            status = "lost"
        else:
            status = "partially_won"

    return {
        "legs": [
            {"boutId": sel["boutId"], "fighterId": sel["fighterId"], "outcome": outcome}
            for sel, outcome in zip(selections, outcomes)
        ],
        "returned": f"{money(returned)}",
        "profit": f"{money(returned - total_stake)}",
        "status": status,
    }


def cash_out(mode: str, selections: list[dict], stake: Decimal,
             settled_bouts: set[str]) -> dict[str, Any]:
    if mode != "accumulator":
        return {"available": False, "amount": "0.00", "reason": "not_an_accumulator"}

    outcomes = {
        sel["boutId"]: leg_outcome(sel, set())
        for sel in selections if sel["boutId"] in settled_bouts
    }
    if "lost" in outcomes.values():
        return {"available": False, "amount": "0.00", "reason": "bet_already_lost"}
    if len(settled_bouts & {sel["boutId"] for sel in selections}) == len(selections):
        return {"available": False, "amount": "0.00", "reason": "bet_already_settled"}

    fair_value = stake
    for sel in selections:
        if outcomes.get(sel["boutId"]) == "won":
            fair_value *= Decimal(sel["odds"])

    return {
        "available": True,
        "amount": f"{money(fair_value * (Decimal(1) - CASH_OUT_MARGIN))}",
        "reason": None,
    }


# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

def fixture_odds_conversion() -> dict[str, Any]:
    cases = []
    for bout_id, bout in BOUTS.items():
        for corner in ("redCorner", "blueCorner"):
            odds = bout[corner]["closingOdds"]
            dec = Decimal(odds["decimal"])
            cases.append({
                "id": f"{bout_id}-{corner}",
                "decimal": odds["decimal"],
                "fractional": to_fractional(dec),
                "impliedProbability": f"{implied_probability(dec)}",
            })
    return {
        "description": "Every published price in the dataset, in all supported notations. "
                       "Fractional values must be fully reduced: 36/10 is a failure, not a variant.",
        "cases": cases,
    }


FREEDOM_WINNERS = [
    ("ufc-freedom-250-bout-01", "justin-gaethje"),
    ("ufc-freedom-250-bout-02", "ciryl-gane"),
    ("ufc-freedom-250-bout-03", "sean-omalley"),
    ("ufc-freedom-250-bout-04", "josh-hokit"),
    ("ufc-freedom-250-bout-05", "mauricio-ruffy"),
    ("ufc-freedom-250-bout-06", "bo-nickal"),
    ("ufc-freedom-250-bout-07", "diego-lopes"),
]


def fixture_slip_math() -> dict[str, Any]:
    cases = []

    def case(case_id: str, note: str, mode: str, picks: list[tuple[str, str]], stake: str):
        selections = [selection(bout, fighter) for bout, fighter in picks]
        cases.append({
            "id": case_id,
            "note": note,
            "mode": mode,
            "stake": stake,
            "selections": selections,
            "expect": slip_state(mode, selections, Decimal(stake)),
        })

    case("single-gaethje",
         "One outsider at 4.60.",
         "single", [("ufc-freedom-250-bout-01", "justin-gaethje")], "10.00")

    case("single-three-legs",
         "Single mode places the stake on each leg separately, so the outlay is 3x and "
         "each return is rounded on its own.",
         "single", FREEDOM_WINNERS[:3], "5.00")

    case("acca-two-legs",
         "The smallest legal accumulator.",
         "accumulator", FREEDOM_WINNERS[:2], "20.00")

    case("acca-seven-fold-double-rounding",
         "THE trap. Combined odds are 36.11129032875 exactly. Multiply the stake by that "
         "and round once and you get 361.11. Round the odds to 36.11 first and you get "
         "361.10. An implementation that rounds intermediates fails here and nowhere else.",
         "accumulator", FREEDOM_WINNERS, "10.00")

    case("acca-heavy-favourites",
         "Five short prices compounding. Exercises precision on repeated multiplication "
         "of values close to 1.",
         "accumulator", [
             ("ufc-328-bout-06", "ateba-gautier"),
             ("ufc-328-bout-12", "baisangur-susurkaev"),
             ("ufc-freedom-250-bout-05", "mauricio-ruffy"),
             ("ufc-freedom-250-bout-03", "sean-omalley"),
             ("ufc-328-bout-05", "king-green"),
         ], "100.00")

    case("acca-longshots",
         "Four outsiders. The return is large, which puts it near the payout ceiling "
         "checked in slip-validation.",
         "accumulator", [
             ("ufc-freedom-250-bout-01", "justin-gaethje"),
             ("ufc-328-bout-01", "sean-strickland"),
             ("ufc-328-bout-09", "jim-miller"),
             ("ufc-328-bout-10", "roman-kopylov"),
         ], "2.00")

    return {
        "description": "Combined odds, stake handling and the double-rounding trap.",
        "cases": cases,
    }


def fixture_slip_validation() -> dict[str, Any]:
    cases = []

    def case(case_id: str, note: str, mode: str, picks: list[tuple[str, str]],
             stake: str, balance: str, raw_selections: list[dict] | None = None):
        selections = raw_selections if raw_selections is not None else [
            selection(bout, fighter) for bout, fighter in picks
        ]
        cases.append({
            "id": case_id,
            "note": note,
            "mode": mode,
            "stake": stake,
            "balance": balance,
            "selections": selections,
            "expect": {"errors": validate(mode, selections, Decimal(stake), Decimal(balance))},
        })

    case("valid-single", "Baseline: no errors.",
         "single", [FREEDOM_WINNERS[0]], "10.00", "100.00")

    case("valid-acca", "Baseline accumulator: no errors.",
         "accumulator", FREEDOM_WINNERS[:3], "25.00", "100.00")

    case("empty", "Nothing selected.", "single", [], "10.00", "100.00")

    case("stake-below-minimum", "Stake under 1.00.",
         "single", [FREEDOM_WINNERS[0]], "0.50", "100.00")

    case("stake-above-maximum", "Stake over 5000.00.",
         "single", [FREEDOM_WINNERS[0]], "5000.01", "10000.00")

    case("insufficient-balance", "Stake exceeds the balance.",
         "single", [FREEDOM_WINNERS[0]], "50.00", "20.00")

    case("insufficient-balance-singles",
         "Balance covers one leg but not three, because single mode multiplies the outlay.",
         "single", FREEDOM_WINNERS[:3], "20.00", "50.00")

    case("acca-one-leg", "Accumulator with a single leg.",
         "accumulator", [FREEDOM_WINNERS[0]], "10.00", "100.00")

    case("duplicate-bout", "Both corners of the same bout.",
         "accumulator", [
             ("ufc-freedom-250-bout-01", "justin-gaethje"),
             ("ufc-freedom-250-bout-01", "ilia-topuria"),
         ], "10.00", "100.00")

    all_bouts = [(bout_id, winner_of(bout_id)) for bout_id in list(BOUTS)[:13]]
    case("too-many-selections", "Thirteen legs, one over the limit.",
         "accumulator", all_bouts, "1.00", "100.00")

    case("payout-exceeds-limit",
         "A seven-fold at the maximum stake pays far more than the 100,000.00 ceiling.",
         "accumulator", FREEDOM_WINNERS, "5000.00", "10000.00")

    case("multiple-errors",
         "Below minimum stake AND over the balance AND a duplicate bout. All three come "
         "back, in the documented order — not just the first one found.",
         "accumulator", [], "0.10", "0.05", raw_selections=[
             selection("ufc-freedom-250-bout-01", "justin-gaethje"),
             selection("ufc-freedom-250-bout-01", "ilia-topuria"),
         ])

    case("unknown-bout", "A bout id that is not in the dataset.",
         "single", [], "10.00", "100.00", raw_selections=[
             {"boutId": "ufc-999-bout-01", "fighterId": "justin-gaethje", "odds": "2.00"},
         ])

    case("fighter-not-in-bout", "A real bout, but the pick fought on a different card.",
         "single", [], "10.00", "100.00", raw_selections=[
             {"boutId": "ufc-328-bout-01", "fighterId": "justin-gaethje", "odds": "2.00"},
         ])

    return {
        "description": "Every error code, plus a slip that trips three at once.",
        "cases": cases,
    }


def fixture_settlement() -> dict[str, Any]:
    cases = []

    def case(case_id: str, note: str, mode: str, picks: list[tuple[str, str]],
             stake: str, voided: set[str] | None = None):
        selections = [selection(bout, fighter) for bout, fighter in picks]
        entry = {
            "id": case_id,
            "note": note,
            "mode": mode,
            "stake": stake,
            "selections": selections,
            "expect": settle(mode, selections, Decimal(stake), voided),
        }
        if voided:
            entry["voidedBouts"] = sorted(voided)
        cases.append(entry)

    case("single-winner", "Gaethje at 4.60 came in.",
         "single", [("ufc-freedom-250-bout-01", "justin-gaethje")], "10.00")

    case("single-loser", "Topuria at 1.20 did not.",
         "single", [("ufc-freedom-250-bout-01", "ilia-topuria")], "10.00")

    case("acca-seven-fold-won",
         "Every winner on the Freedom 250 card. The headline settlement of the demo.",
         "accumulator", FREEDOM_WINNERS, "10.00")

    case("acca-one-leg-lost",
         "Four correct legs and Chimaev. One wrong leg zeroes the whole thing, which is "
         "the entire emotional content of an accumulator.",
         "accumulator", [
             ("ufc-freedom-250-bout-01", "justin-gaethje"),
             ("ufc-freedom-250-bout-02", "ciryl-gane"),
             ("ufc-328-bout-01", "khamzat-chimaev"),
             ("ufc-328-bout-09", "jim-miller"),
         ], "25.00")

    case("singles-mixed",
         "Three singles: two winners and a loser. Partially won, and the profit is "
         "negative even though two legs came in.",
         "single", [
             ("ufc-328-bout-01", "sean-strickland"),
             ("ufc-328-bout-02", "tatsuro-taira"),
             ("ufc-328-bout-03", "alexander-volkov"),
         ], "20.00")

    case("acca-favourites-won",
         "Five short prices, all correct.",
         "accumulator", [
             ("ufc-328-bout-06", "ateba-gautier"),
             ("ufc-328-bout-12", "baisangur-susurkaev"),
             ("ufc-freedom-250-bout-05", "mauricio-ruffy"),
             ("ufc-freedom-250-bout-03", "sean-omalley"),
             ("ufc-328-bout-05", "king-green"),
         ], "100.00")

    case("acca-with-void-leg",
         "SYNTHETIC. No real bout on either card was a draw or a no contest, so the void "
         "rule is exercised here with an invented void on bout 02. The leg's odds become "
         "1.00 and the accumulator survives.",
         "accumulator", FREEDOM_WINNERS[:4], "10.00",
         voided={"ufc-freedom-250-bout-02"})

    return {
        "description": "Settlement against the real results. One synthetic case covers the "
                       "void rule, which no real bout on these cards reaches.",
        "cases": cases,
    }


def fixture_cash_out() -> dict[str, Any]:
    cases = []

    def case(case_id: str, note: str, mode: str, picks: list[tuple[str, str]],
             stake: str, settled: set[str]):
        selections = [selection(bout, fighter) for bout, fighter in picks]
        cases.append({
            "id": case_id,
            "note": note,
            "mode": mode,
            "stake": stake,
            "selections": selections,
            "settledBouts": sorted(settled),
            "expect": cash_out(mode, selections, Decimal(stake), settled),
        })

    case("nothing-settled",
         "No leg resolved yet, so the offer is simply the stake less the margin.",
         "accumulator", FREEDOM_WINNERS[:4], "10.00", set())

    case("two-legs-won",
         "Gaethje and Gane are in, two legs still to run. The offer tracks the value "
         "already banked.",
         "accumulator", FREEDOM_WINNERS[:4], "10.00",
         {"ufc-freedom-250-bout-01", "ufc-freedom-250-bout-02"})

    case("one-leg-lost",
         "A losing leg means there is nothing left to sell.",
         "accumulator", [
             ("ufc-freedom-250-bout-01", "ilia-topuria"),
             ("ufc-freedom-250-bout-02", "ciryl-gane"),
             ("ufc-freedom-250-bout-03", "sean-omalley"),
         ], "10.00", {"ufc-freedom-250-bout-01"})

    case("fully-settled",
         "Every leg resolved: settle it, do not price it.",
         "accumulator", FREEDOM_WINNERS[:3], "10.00",
         {bout for bout, _ in FREEDOM_WINNERS[:3]})

    case("single-mode",
         "Cash-out is an accumulator feature.",
         "single", [FREEDOM_WINNERS[0]], "10.00", set())

    return {
        "description": "Deterministic cash-out model with a 5% margin, as defined in "
                       "section 6 of the contract.",
        "cases": cases,
    }


def main() -> None:
    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    builders = {
        "odds-conversion.json": fixture_odds_conversion,
        "slip-math.json": fixture_slip_math,
        "slip-validation.json": fixture_slip_validation,
        "settlement.json": fixture_settlement,
        "cash-out.json": fixture_cash_out,
    }
    for filename, builder in builders.items():
        payload = builder()
        path = FIXTURES_DIR / filename
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"  {filename}: {len(payload['cases'])} cases")


if __name__ == "__main__":
    main()
