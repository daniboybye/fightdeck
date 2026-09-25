//! The `fightcore` UniFFI namespace: money, odds, the deposit rules and the shared error type.
//!
//! Amounts cross the boundary as decimal strings, never f64, so no host can round differently
//! from the kernel.

use crate::deposit;
use crate::money;
use crate::odds;
use rust_decimal::Decimal;

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FightCoreError {
    #[error("decoding")]
    Decoding { field: String },
}

impl FightCoreError {
    pub fn decoding(field: &str) -> Self {
        Self::Decoding { field: field.to_string() }
    }
}

fn parse(field: &str, value: &str) -> Result<Decimal, FightCoreError> {
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

// MARK: - Deposit

#[derive(uniffi::Record, Clone, Debug)]
pub struct DepositMethod {
    pub id: String,
    pub title: String,
    pub fee_note: String,
}

/// Everything the deposit form shows, worked out from what has been typed so far.
#[derive(uniffi::Record, Clone, Debug)]
pub struct DepositQuote {
    /// Two places, ready for `BetSlipStore::deposit`.
    pub amount: String,
    pub amount_display: String,
    pub fee_display: String,
    pub total_display: String,
    pub new_balance_display: String,
    pub validation_message: Option<String>,
    pub can_confirm: bool,
}

#[uniffi::export]
pub fn deposit_methods() -> Vec<DepositMethod> {
    deposit::METHODS
        .iter()
        .map(|method| DepositMethod {
            id: method.id.to_string(),
            title: method.title.to_string(),
            fee_note: method.fee_note.to_string(),
        })
        .collect()
}

#[uniffi::export]
pub fn deposit_presets() -> Vec<String> {
    deposit::PRESETS.iter().map(|preset| preset.to_string()).collect()
}

/// Infallible on purpose: the amount is whatever is in the text field, and text that is not
/// a number is a deposit of nothing, which the minimum already turns away.
#[uniffi::export]
pub fn deposit_quote(amount_text: String, method_id: String, balance: String) -> DepositQuote {
    let balance = money::try_parse(&balance).unwrap_or(Decimal::ZERO);
    let quote = deposit::quote(&amount_text, &method_id, balance);
    DepositQuote {
        amount: money::format(quote.amount),
        amount_display: money::format_currency(quote.amount),
        fee_display: money::format_currency(quote.fee),
        total_display: money::format_currency(quote.total),
        new_balance_display: money::format_currency(quote.new_balance),
        validation_message: quote.validation_message.map(str::to_string),
        can_confirm: quote.can_confirm,
    }
}
