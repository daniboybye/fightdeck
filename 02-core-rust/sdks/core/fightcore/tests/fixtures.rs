use fightcore::{
    decimal_to_fractional, fractional_to_decimal, implied_probability, BetMode, BetSlip,
    BoutIndex, FightCore, Selection, format, format_exact_odds, parse,
};
use serde::Deserialize;
use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../..")
        .join("contract/fixtures")
}

fn dataset_events_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../..")
        .join("dataset/events.json")
}

fn fixture_core() -> FightCore {
    let data = fs::read_to_string(dataset_events_path()).expect("events.json");
    let events: EventsFile = serde_json::from_str(&data).expect("parse events");
    let bouts = events
        .events
        .into_iter()
        .flat_map(|e| e.bouts)
        .map(|b| BoutIndex {
            id: b.id,
            red_fighter_id: b.red_corner.fighter_id,
            blue_fighter_id: b.blue_corner.fighter_id,
            winner_id: b.result.winner_id,
        })
        .collect();
    FightCore::new(bouts)
}

#[test]
fn odds_conversion_fixtures() {
    let path = fixtures_dir().join("odds-conversion.json");
    let data = fs::read_to_string(path).expect("read odds-conversion");
    let root: OddsConversionRoot = serde_json::from_str(&data).expect("parse");
    for case in &root.cases {
        let decimal = parse(&case.decimal);
        assert_eq!(
            decimal_to_fractional(decimal),
            case.fractional,
            "case {} fractional",
            case.id
        );
        assert_eq!(
            format_implied(decimal),
            case.implied_probability,
            "case {} implied",
            case.id
        );
        let round_trip = fractional_to_decimal(&case.fractional);
        assert_eq!(
            format(round_trip),
            format(decimal),
            "case {} round-trip",
            case.id
        );
    }
    assert_eq!(root.cases.len(), 40);
}

#[test]
fn slip_math_fixtures() {
    let core = fixture_core();
    let path = fixtures_dir().join("slip-math.json");
    let data = fs::read_to_string(path).expect("read slip-math");
    let root: SlipMathRoot = serde_json::from_str(&data).expect("parse");
    for case in &root.cases {
        let slip = case.slip();
        let state = core.slip_state(&slip, parse("10000.00"));
        if let Some(expected) = &case.expect.combined_odds_exact {
            assert_eq!(
                format_exact_odds(state.combined_odds_exact.unwrap()),
                *expected,
                "case {} combinedOddsExact",
                case.id
            );
        }
        if let Some(expected) = &case.expect.combined_odds_display {
            assert_eq!(
                format(state.combined_odds_display.unwrap()),
                *expected,
                "case {} combinedOddsDisplay",
                case.id
            );
        }
        assert_eq!(format(state.total_stake), case.expect.total_stake, "case {} totalStake", case.id);
        assert_eq!(
            format(state.potential_return),
            case.expect.potential_return,
            "case {} potentialReturn",
            case.id
        );
        assert_eq!(
            format(state.potential_profit),
            case.expect.potential_profit,
            "case {} potentialProfit",
            case.id
        );
    }
    assert_eq!(root.cases.len(), 6);
}

#[test]
fn slip_validation_fixtures() {
    let core = fixture_core();
    let path = fixtures_dir().join("slip-validation.json");
    let data = fs::read_to_string(path).expect("read slip-validation");
    let root: SlipValidationRoot = serde_json::from_str(&data).expect("parse");
    for case in &root.cases {
        let slip = case.slip();
        let errors = core.validate(&slip, parse(&case.balance));
        let codes: Vec<_> = errors.iter().map(|e| e.code().to_string()).collect();
        assert_eq!(codes, case.expect.errors, "case {}", case.id);
    }
    assert_eq!(root.cases.len(), 14);
}

#[test]
fn settlement_fixtures() {
    let core = fixture_core();
    let path = fixtures_dir().join("settlement.json");
    let data = fs::read_to_string(path).expect("read settlement");
    let root: SettlementRoot = serde_json::from_str(&data).expect("parse");
    for case in &root.cases {
        let slip = case.slip();
        let voided = case.voided_bout_ids();
        let result = core.settle(&slip, &voided);
        assert_eq!(format(result.returned), case.expect.returned, "case {} returned", case.id);
        assert_eq!(format(result.profit), case.expect.profit, "case {} profit", case.id);
        assert_eq!(result.status.as_str(), case.expect.status, "case {} status", case.id);
        for (leg, expected) in result.legs.iter().zip(case.expect.legs.iter()) {
            assert_eq!(leg.bout_id, expected.bout_id);
            assert_eq!(leg.fighter_id, expected.fighter_id);
            assert_eq!(leg.outcome.as_str(), expected.outcome);
        }
    }
    assert_eq!(root.cases.len(), 7);
}

#[test]
fn cash_out_fixtures() {
    let core = fixture_core();
    let path = fixtures_dir().join("cash-out.json");
    let data = fs::read_to_string(path).expect("read cash-out");
    let root: CashOutRoot = serde_json::from_str(&data).expect("parse");
    for case in &root.cases {
        let slip = case.slip();
        let settled: HashSet<String> = case.settled_bouts.iter().cloned().collect();
        let offer = core.cash_out_offer(&slip, &settled);
        assert_eq!(offer.available, case.expect.available, "case {} available", case.id);
        assert_eq!(format(offer.amount), case.expect.amount, "case {} amount", case.id);
        assert_eq!(offer.reason, case.expect.reason, "case {} reason", case.id);
    }
    assert_eq!(root.cases.len(), 5);
}

// MARK: - Fixture models

fn format_implied(decimal: rust_decimal::Decimal) -> String {
    fightcore::format_implied_probability(implied_probability(decimal))
}

#[derive(Deserialize)]
struct OddsConversionRoot {
    cases: Vec<OddsConversionCase>,
}

#[derive(Deserialize)]
struct OddsConversionCase {
    id: String,
    decimal: String,
    fractional: String,
    #[serde(rename = "impliedProbability")]
    implied_probability: String,
}

#[derive(Deserialize)]
struct SlipMathRoot {
    cases: Vec<SlipMathCase>,
}

#[derive(Deserialize)]
struct SlipMathCase {
    id: String,
    mode: String,
    stake: String,
    selections: Vec<SelectionFixture>,
    expect: SlipMathExpect,
}

impl SlipMathCase {
    fn slip(&self) -> BetSlip {
        BetSlip {
            mode: BetMode::from_str(&self.mode),
            selections: self.selections.iter().map(|s| s.to_selection()).collect(),
            stake: parse(&self.stake),
            stake_raw: self.stake.clone(),
        }
    }
}

#[derive(Deserialize)]
struct SlipMathExpect {
    #[serde(rename = "combinedOddsExact")]
    combined_odds_exact: Option<String>,
    #[serde(rename = "combinedOddsDisplay")]
    combined_odds_display: Option<String>,
    #[serde(rename = "totalStake")]
    total_stake: String,
    #[serde(rename = "potentialReturn")]
    potential_return: String,
    #[serde(rename = "potentialProfit")]
    potential_profit: String,
}

#[derive(Deserialize)]
struct SlipValidationRoot {
    cases: Vec<SlipValidationCase>,
}

#[derive(Deserialize)]
struct SlipValidationCase {
    id: String,
    mode: String,
    stake: String,
    balance: String,
    selections: Vec<SelectionFixture>,
    expect: SlipValidationExpect,
}

impl SlipValidationCase {
    fn slip(&self) -> BetSlip {
        BetSlip {
            mode: BetMode::from_str(&self.mode),
            selections: self.selections.iter().map(|s| s.to_selection()).collect(),
            stake: parse(&self.stake),
            stake_raw: self.stake.clone(),
        }
    }
}

#[derive(Deserialize)]
struct SlipValidationExpect {
    errors: Vec<String>,
}

#[derive(Deserialize)]
struct SettlementRoot {
    cases: Vec<SettlementCase>,
}

#[derive(Deserialize)]
struct SettlementCase {
    id: String,
    mode: String,
    stake: String,
    selections: Vec<SelectionFixture>,
    #[serde(rename = "voidedBouts")]
    voided_bouts: Option<Vec<String>>,
    expect: SettlementExpect,
}

impl SettlementCase {
    fn slip(&self) -> BetSlip {
        BetSlip {
            mode: BetMode::from_str(&self.mode),
            selections: self.selections.iter().map(|s| s.to_selection()).collect(),
            stake: parse(&self.stake),
            stake_raw: self.stake.clone(),
        }
    }

    fn voided_bout_ids(&self) -> HashSet<String> {
        self.voided_bouts.clone().unwrap_or_default().into_iter().collect()
    }
}

#[derive(Deserialize)]
struct SettlementExpect {
    legs: Vec<SettlementLegExpect>,
    returned: String,
    profit: String,
    status: String,
}

#[derive(Deserialize)]
struct SettlementLegExpect {
    #[serde(rename = "boutId")]
    bout_id: String,
    #[serde(rename = "fighterId")]
    fighter_id: String,
    outcome: String,
}

#[derive(Deserialize)]
struct CashOutRoot {
    cases: Vec<CashOutCase>,
}

#[derive(Deserialize)]
struct CashOutCase {
    id: String,
    mode: String,
    stake: String,
    selections: Vec<SelectionFixture>,
    #[serde(rename = "settledBouts")]
    settled_bouts: Vec<String>,
    expect: CashOutExpect,
}

impl CashOutCase {
    fn slip(&self) -> BetSlip {
        BetSlip {
            mode: BetMode::from_str(&self.mode),
            selections: self.selections.iter().map(|s| s.to_selection()).collect(),
            stake: parse(&self.stake),
            stake_raw: self.stake.clone(),
        }
    }
}

#[derive(Deserialize)]
struct CashOutExpect {
    available: bool,
    amount: String,
    reason: Option<String>,
}

#[derive(Deserialize)]
struct SelectionFixture {
    #[serde(rename = "boutId")]
    bout_id: String,
    #[serde(rename = "fighterId")]
    fighter_id: String,
    odds: String,
}

impl SelectionFixture {
    fn to_selection(&self) -> Selection {
        Selection {
            bout_id: self.bout_id.clone(),
            fighter_id: self.fighter_id.clone(),
            odds: parse(&self.odds),
        }
    }
}

#[derive(Deserialize)]
struct EventsFile {
    events: Vec<EventDTO>,
}

#[derive(Deserialize)]
struct EventDTO {
    bouts: Vec<BoutDTO>,
}

#[derive(Deserialize)]
struct BoutDTO {
    id: String,
    #[serde(rename = "redCorner")]
    red_corner: CornerDTO,
    #[serde(rename = "blueCorner")]
    blue_corner: CornerDTO,
    result: ResultDTO,
}

#[derive(Deserialize)]
struct CornerDTO {
    #[serde(rename = "fighterId")]
    fighter_id: String,
}

#[derive(Deserialize)]
struct ResultDTO {
    #[serde(rename = "winnerId")]
    winner_id: String,
}
