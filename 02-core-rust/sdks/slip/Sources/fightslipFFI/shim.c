// SwiftPM will not build a target that has headers but no sources. Every symbol this module
// declares lives in the Rust staticlib carried by the FightSlipRust binary target.
void fightslip_ffi_shim(void);

void fightslip_ffi_shim(void) {}
