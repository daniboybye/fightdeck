// SwiftPM will not build a target that has headers but no sources. Every symbol this module
// declares lives in the Rust staticlib carried by the FightEventsRust binary target.
void fightevents_ffi_shim(void);

void fightevents_ffi_shim(void) {}
