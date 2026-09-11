// SwiftPM will not build a target that has headers but no sources. Every symbol this module
// declares lives in the Rust staticlib carried by the FightCoreRust binary target.
void fightcore_ffi_shim(void);

void fightcore_ffi_shim(void) {}
