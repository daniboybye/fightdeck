fn main() {
    if std::env::var("CARGO_CFG_TARGET_ARCH") == Ok("wasm32".to_string()) {
        return;
    }
    uniffi::generate_scaffolding("./src/fightcore.udl").unwrap();
}
