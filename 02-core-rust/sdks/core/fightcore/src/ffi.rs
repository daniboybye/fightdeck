//! The `fightcore` UniFFI namespace: money, odds and the shared error type.
//!
//! Amounts cross the boundary as decimal strings, never f64, so no host can round differently
//! from the kernel.

use crate::money;
use crate::odds;
use crate::types::{
    ValidationError, CASH_OUT_MARGIN, MAX_PAYOUT, MAX_SELECTIONS, MAX_STAKE, MIN_ACCA_LEGS,
    MIN_STAKE,
};

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

#[uniffi::export]
pub fn round_money(amount: String) -> Result<String, FightCoreError> {
    Ok(money::format(money::money(parse("amount", &amount)?)))
}

#[uniffi::export]
pub fn add_money(lhs: String, rhs: String) -> Result<String, FightCoreError> {
    Ok(money::format(parse("lhs", &lhs)? + parse("rhs", &rhs)?))
}

#[uniffi::export]
pub fn subtract_money(lhs: String, rhs: String) -> Result<String, FightCoreError> {
    Ok(money::format(parse("lhs", &lhs)? - parse("rhs", &rhs)?))
}

#[uniffi::export]
pub fn is_valid_money(amount: String) -> bool {
    money::try_parse(&amount).is_ok()
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

// MARK: - Contract limits
//
// Exported so a host never hard-codes a limit that the kernel could change.

#[derive(uniffi::Record, Clone, Debug)]
pub struct ContractLimits {
    pub min_stake: String,
    pub max_stake: String,
    pub max_selections: u32,
    pub min_acca_legs: u32,
    pub max_payout: String,
    pub cash_out_margin: String,
}

#[uniffi::export]
pub fn contract_limits() -> ContractLimits {
    ContractLimits {
        min_stake: MIN_STAKE.to_string(),
        max_stake: MAX_STAKE.to_string(),
        max_selections: MAX_SELECTIONS as u32,
        min_acca_legs: MIN_ACCA_LEGS as u32,
        max_payout: MAX_PAYOUT.to_string(),
        cash_out_margin: CASH_OUT_MARGIN.to_string(),
    }
}

#[uniffi::export]
pub fn validation_error_codes() -> Vec<String> {
    ValidationError::ORDER
        .iter()
        .map(|error| error.code().to_string())
        .collect()
}
