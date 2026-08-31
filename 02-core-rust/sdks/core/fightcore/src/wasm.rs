use crate::{decimal_to_fractional, format, parse, BetMode, BetSlip, FightCore, Selection};
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn acca_seven_fold_return(stake: &str) -> String {
    let selections = [
        ("ufc-freedom-250-bout-01", "4.60"),
        ("ufc-freedom-250-bout-02", "2.05"),
        ("ufc-freedom-250-bout-03", "1.23"),
        ("ufc-freedom-250-bout-04", "1.25"),
        ("ufc-freedom-250-bout-05", "1.19"),
        ("ufc-freedom-250-bout-06", "1.30"),
        ("ufc-freedom-250-bout-07", "1.61"),
    ];
    let slip = BetSlip {
        mode: BetMode::Accumulator,
        selections: selections
            .iter()
            .map(|(bout, odds)| Selection {
                bout_id: (*bout).to_string(),
                fighter_id: "demo".to_string(),
                odds: parse(odds),
            })
            .collect(),
        stake: parse(stake),
        stake_raw: stake.to_string(),
    };
    let core = FightCore::new(vec![]);
    format(core.slip_state(&slip, parse("10000")).potential_return)
}

#[wasm_bindgen]
pub fn decimal_to_fractional_wasm(decimal_odds: &str) -> String {
    decimal_to_fractional(parse(decimal_odds))
}
