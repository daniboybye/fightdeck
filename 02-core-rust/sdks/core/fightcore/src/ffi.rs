//! The `fightcore` UniFFI namespace: money, odds and the shared error type.
//!
//! Amounts cross the boundary as decimal strings, never f64, so no host can round differently
//! from the kernel.

use crate::money;
use crate::odds;

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FightCoreError {
    #[error("network")]
    Network { retryable: bool },
    #[error("decoding")]
    Decoding { field: String },
    #[error("validation")]
    Validation { codes: Vec<String> },
}

impl FightCoreError {
    pub fn decoding(field: &str) -> Self {
        Self::Decoding { field: field.to_string() }
    }
}

fn parse(field: &str, value: &str) -> Result<rust_decimal::Decimal, FightCoreError> {
    money::try_parse(value).map_err(|_| FightCoreError::decoding(field))
}

// MARK: - Money

#[uniffi::export]
pub fn format_money(amount: String) -> Result<String, FightCoreError> {
    Ok(money::format(parse("amount", &amount)?))
}

#[uniffi::export]
pub fn format_currency(amount: String) -> Result<String, FightCoreError> {
    Ok(money::format_currency(parse("amount", &amount)?))
}

#[uniffi::export]
pub fn format_exact_odds(amount: String) -> Result<String, FightCoreError> {
    Ok(money::format_exact_odds(parse("amount", &amount)?))
}

// MARK: - Odds

#[uniffi::export]
pub fn decimal_to_fractional(decimal_odds: String) -> Result<String, FightCoreError> {
    Ok(odds::decimal_to_fractional(parse("decimal_odds", &decimal_odds)?))
}

#[uniffi::export]
pub fn fractional_to_decimal(fractional: String) -> Result<String, FightCoreError> {
    Ok(money::format(odds::fractional_to_decimal(&fractional)))
}

#[uniffi::export]
pub fn implied_probability(decimal_odds: String) -> Result<String, FightCoreError> {
    let value = odds::implied_probability(parse("decimal_odds", &decimal_odds)?);
    Ok(money::format_implied_probability(value))
}
