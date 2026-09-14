//! Android packages every UniFFI component into one shared library.
//!
//! The iOS SDKs remain independent static libraries. Android uses one `libfightdeck.so` so
//! `fightcore`, Rust's standard library and shared dependencies appear once in the app.

fightcore::uniffi_reexport_scaffolding!();
fightslip::uniffi_reexport_scaffolding!();
fightevents::uniffi_reexport_scaffolding!();
