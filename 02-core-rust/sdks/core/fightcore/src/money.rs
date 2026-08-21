//! Decimal money helpers — never f64.

use rust_decimal::Decimal;
use rust_decimal::RoundingStrategy;
use std::str::FromStr;

pub fn parse(s: &str) -> Decimal {
    Decimal::from_str(s).unwrap_or(Decimal::ZERO)
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
        assert_eq!(format(money(parse("361.105"))), "361.11");
        assert_eq!(format(money(parse("361.104"))), "361.10");
    }
}
