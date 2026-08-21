mod core;
mod money;
mod odds;

#[cfg(not(target_arch = "wasm32"))]
mod ffi;

#[cfg(target_arch = "wasm32")]
mod wasm;

pub use core::*;
pub use money::{format, format_currency, format_exact_odds, format_implied_probability, money, parse, round};
pub use odds::{decimal_to_fractional, fractional_to_decimal, implied_probability};

#[cfg(not(target_arch = "wasm32"))]
pub use ffi::*;

#[cfg(not(target_arch = "wasm32"))]
uniffi::setup_scaffolding!("fightcore");
