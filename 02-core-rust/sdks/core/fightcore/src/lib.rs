//! FightCore — the shared kernel.
//!
//! Decimal money, odds conversion, the deposit rules and the contract vocabulary. No feature
//! logic lives here: the bet slip is `fightslip`, the catalogue is `fightevents`. Both depend
//! on this crate as an ordinary Rust dependency and ship as their own xcframework.

pub mod deposit;
pub mod money;
pub mod odds;
pub mod types;

mod ffi;

pub use money::{format, format_exact_odds, parse_exact as parse};
pub use odds::{decimal_to_fractional, fractional_to_decimal, implied_probability};
pub use types::*;

pub use ffi::*;

uniffi::setup_scaffolding!("fightcore");
