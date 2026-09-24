//! FightEvents — the catalogue feature SDK.
//!
//! Loads the dataset, orders a fight card, builds the tale of the tape, answers the lookups
//! the slip screen needs and serves the dataset's images. Depends on `fightcore` for money
//! and odds, and ships as its own `FightEvents.xcframework` / `fightevents.aar`.

mod assets;
pub mod catalog;
pub mod dataset;
pub mod display;
mod ffi;
pub mod tape;

pub use assets::*;
pub use catalog::Catalog;
pub use ffi::*;

uniffi::setup_scaffolding!("fightevents");
