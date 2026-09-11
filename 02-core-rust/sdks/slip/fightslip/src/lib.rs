//! FightSlip — the bet slip feature SDK.
//!
//! Depends on `fightcore` for money and the contract vocabulary, and ships as its own
//! `FightSlip.xcframework` / `fightslip.aar`.

pub mod engine;
mod ffi;
mod store;

pub use engine::SlipEngine;
pub use ffi::*;
pub use store::*;

uniffi::setup_scaffolding!("fightslip");
