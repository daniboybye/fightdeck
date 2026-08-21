# 02-core-rust — Headless Rust core via UniFFI

Same UFC betting product as [`00-native/`](../00-native/): event list, bout detail, bet slip, deposit. All **business logic** lives in Rust; SwiftUI and Compose are thin shells that implement **ports** and bind to observable slip state.

## What this approach demonstrates

| Talking point | Where it lives |
| --- | --- |
| `rust_decimal` for money (never `f64`) | `sdks/core/fightcore/src/money.rs`, `core.rs` |
| HALF_UP rounding once at the end | `money::round`, seven-fold trap in fixtures |
| UniFFI **foreign traits** (`with_foreign`) | `Clock`, `PreferencesStore`, `SlipStateListener`, `FightRepository` in `ffi.rs` |
| Async across FFI (`async_runtime = "tokio"`) | `FightRepository` → Swift `async` / Kotlin `suspend` |
| Typed errors (`#[derive(uniffi::Error)]`) | `FightCoreError` in `ffi.rs` |
| Rust defines ports; platform fills them | `UserDefaultsPreferencesStore` (Swift), `SharedPreferencesStore` (Kotlin) |
| Observable state glue by hand | `ios/.../FightCoreGlue.swift`, `android/.../FightCoreGlue.kt` |

Rust deliberately **does not reach into** `UserDefaults` or `SharedPreferences`. The core declares `PreferencesStore`; each host implements it over native storage. That contrast with approaches that call platform APIs from C++/JNI is intentional.

## Hand-written glue line count

Measured in the clearly named glue files (observable slip republishing + platform port helpers):

| File | Observable state glue | Port + display helpers | Total |
| --- | ---: | ---: | ---: |
| `ios/FightDeck/Core/FightCoreGlue.swift` | 44 | 45 | **89** |
| `android/.../core/FightCoreGlue.kt` | 39 | 56 | **95** |
| **Combined** | **83** | **101** | **184** |

Observable glue = `ObservableBetSlipStore` / `StateFlowBetSlipStore` plus the `SlipStateListener` bridge. UniFFI generates neither `@Observable` nor `StateFlow`; that cost is real and counted here.

## What UniFFI does **not** give you for free

- **Reactive UI bindings** — no `@Observable`, no `StateFlow`; you write listener → wrapper glue (~83 lines here).
- **Swift 6 strict concurrency on generated async glue** — UniFFI 0.32 emits `Task { @MainActor in … }` with non-Sendable C callbacks; we post-process with `patch-swift-bindings.sh` (~30 lines of Python).
- **Repository wiring** — `FightRepository` is exported, but loading JSON from the bundled dataset stays in the host (`JSONFileRepository` / `JsonFileRepository`) unless you pass a foreign impl into Rust.
- **Design-system UI** — screens, tokens, Kingfisher/Coil, navigation: still written per platform (mirroring `00-native/`).
- **Binary size / cold start** — measured separately in CI; the xcframework ships Tokio + UniFFI scaffolding.

## Build commands

Toolchain pins: [`versions.lock.toml`](../versions.lock.toml) (Rust 1.97.1, UniFFI 0.32.0, etc.).

```bash
export PATH="$HOME/.cargo/bin:$PATH"
cd 02-core-rust/sdks/core

# Unit tests (loads contract/fixtures/*.json from repo root)
cargo test

# Wasm core (release target required by CI)
cargo build --release --target wasm32-unknown-unknown

# Optional browser demo (slip math in wasm/)
./build-wasm.sh
# then: cd wasm && python3 -m http.server 8080

# iOS SDK artifact
./build-xcframework.sh    # → out/FightCore.xcframework.zip

# Android SDK artifact
./build-aar.sh            # → out/fightcore.aar (+ syncs Kotlin bindings to android/app)
```

### iOS host

```bash
cd 02-core-rust/ios
xcodebuild -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  build
```

Regenerate Xcode project after editing `project.yml`: `xcodegen generate`.

### Android host

```bash
cd 02-core-rust/android
./gradlew :app:assembleDebug
```

Set `FIGHTDECK_DATASET_ROOT` or rely on default path to repo `dataset/` (see `DatasetLocator`).

## Fixture coverage

| File | Cases | Status |
| --- | ---: | --- |
| `odds-conversion.json` | 40 | pass |
| `slip-math.json` | 6 | pass |
| `slip-validation.json` | 14 | pass |
| `settlement.json` | 7 | pass |
| `cash-out.json` | 5 | pass |
| **Total** | **72** | **72/72** |

Run: `cd sdks/core && cargo test` — five test functions, one per fixture file.

## Artifact sizes (local build, Aug 2026)

| Artifact | Size |
| --- | ---: |
| `out/FightCore.xcframework.zip` | ~20 MB |
| `out/fightcore.aar` | ~713 KB |

## Layout

```
02-core-rust/
├── sdks/core/           # Rust workspace + UniFFI + build scripts
│   ├── fightcore/       # library (pure core + ffi + wasm)
│   ├── wasm/            # tiny browser demo
│   └── out/             # xcframework zip, aar (CI artifact names)
├── ios/                 # SwiftUI host, scheme FightDeck
└── android/             # Compose host, module app
```

## Spec notes / ambiguities

- **FightRepository in hosts**: the port is exported and async, but these demo hosts still load JSON directly for clarity and to mirror screen code from `00-native/`. Production would implement `FightRepository` in Swift/Kotlin and optionally call into Rust with it.
- **UniFFI + Swift 6**: generated bindings need `patch-swift-bindings.sh` after every `uniffi-bindgen` run; this is a known gap until UniFFI ships Sendable-safe async glue.
- **American odds**: explicitly out of scope per contract; fractional display only.
