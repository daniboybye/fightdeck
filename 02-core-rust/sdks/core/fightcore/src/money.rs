//! Decimal money helpers — never f64.

use rust_decimal::Decimal;
use rust_decimal::RoundingStrategy;
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ParseError;

pub fn try_parse(s: &str) -> Result<Decimal, ParseError> {
    Decimal::from_str(s).map_err(|_| ParseError)
}

/// Infallible parse for compile-time literals and fixture inputs that must be valid.
pub fn parse_exact(s: &str) -> Decimal {
    try_parse(s).unwrap_or_else(|_| panic!("invalid money literal: {s}"))
}

pub fn round(value: Decimal, scale: u32) -> Decimal {
    value.round_dp_with_strategy(scale, RoundingStrategy::MidpointAwayFromZero)
}

/// Round to 2 dp HALF_UP — the only rounding applied to monetary amounts.
pub fn money(value: Decimal) -> Decimal {
    round(value, 2)
}

pub fn format(value: Decimal) -> String {
    format!("{:.2}", money(value))
}

pub fn format_currency(value: Decimal) -> String {
    format!("€{}", format(value))
}

pub fn format_exact_odds(value: Decimal) -> String {
    let normalized = value.normalize();
    let s = normalized.to_string();
    if s.contains('.') {
        let trimmed = s.trim_end_matches('0').trim_end_matches('.');
        trimmed.to_string()
    } else {
        s
    }
}

pub fn format_implied_probability(value: Decimal) -> String {
    format!("{:.4}", round(value, 4))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn half_up_rounding() {
        assert_eq!(format(money(parse_exact("361.105"))), "361.11");
        assert_eq!(format(money(parse_exact("361.104"))), "361.10");
    }

    #[test]
    fn rejects_garbage() {
        assert!(try_parse("10..00").is_err());
        assert!(try_parse("abc").is_err());
    }

    #[test]
    fn invalid_stake_raw_flags_validation_not_zero_stake() {
        use crate::{BetMode, BetSlip, FightCore, Selection, ValidationError};
        let slip = BetSlip {
            mode: BetMode::Single,
            selections: vec![Selection {
                bout_id: "bout-1".into(),
                fighter_id: "fighter-1".into(),
                odds: parse_exact("2.00"),
            }],
            stake: parse_exact("10.00"),
            stake_raw: "10..00".into(),
        };
        let core = FightCore::new(vec![]);
        let errors = core.validate(&slip, parse_exact("500.00"));
        assert!(errors.contains(&ValidationError::InvalidStake));
        assert!(!errors.contains(&ValidationError::StakeBelowMinimum));
    }
}
