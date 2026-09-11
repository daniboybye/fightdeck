//! Browser demo surface. Not part of the mobile SDKs.

use crate::money;
use crate::odds;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn decimal_to_fractional_wasm(decimal_odds: &str) -> String {
    match money::try_parse(decimal_odds) {
        Ok(value) => odds::decimal_to_fractional(value),
        Err(_) => String::new(),
    }
}

#[wasm_bindgen]
pub fn format_currency_wasm(amount: &str) -> String {
    match money::try_parse(amount) {
        Ok(value) => money::format_currency(value),
        Err(_) => String::new(),
    }
}
