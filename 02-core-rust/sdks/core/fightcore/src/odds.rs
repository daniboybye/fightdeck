//! Odds conversion — decimal, fractional, implied probability.

use crate::money;
use rust_decimal::Decimal;

pub fn decimal_to_fractional(decimal_odds: Decimal) -> String {
    let profit = decimal_odds - Decimal::ONE;
    let scaled = (profit * Decimal::from(10_000)).trunc();
    let scaled_i: i64 = scaled.try_into().unwrap_or(0);
    let abs_scaled: u32 = scaled_i.unsigned_abs().try_into().unwrap_or(0);
    let divisor = gcd(abs_scaled, 10_000);
    format!("{}/{}", scaled_i / divisor as i64, 10_000 / divisor)
}

pub fn fractional_to_decimal(fractional: &str) -> Decimal {
    let parts: Vec<&str> = fractional.split('/').collect();
    if parts.len() != 2 {
        return Decimal::ZERO;
    }
    let numerator: i64 = parts[0].parse().unwrap_or(0);
    let denominator: i64 = parts[1].parse().unwrap_or(0);
    if denominator <= 0 {
        return Decimal::ZERO;
    }
    let profit = Decimal::from(numerator) / Decimal::from(denominator);
    money::money(profit + Decimal::ONE)
}

pub fn implied_probability(decimal_odds: Decimal) -> Decimal {
    money::round(Decimal::ONE / decimal_odds, 4)
}

fn gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 {
        let temp = b;
        b = a % b;
        a = temp;
    }
    a.max(1)
}
