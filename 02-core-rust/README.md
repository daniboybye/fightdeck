# 02-core-rust — One Rust kernel, two Rust feature SDKs, via UniFFI

Same UFC betting product as [`00-native/`](../00-native/): event list, bout detail, bet slip, deposit. The business logic lives in Rust and ships as **three independently built binaries**; SwiftUI and Compose are thin shells that bind to them.

## Three SDKs, not one

| SDK | Crate | UniFFI namespace | Apple artifact | Android artifact | Owns |
| --- | --- | --- | --- | --- | --- |
| Kernel | `fightcore` | `fightcore` | `FightCore.xcframework` | `fightcore.aar` | Decimal money, odds conversion, contract vocabulary and limits |
| Feature one | `fightslip` | `fightslip` | `FightSlip.xcframework` | `fightslip.aar` | Bet slip store, validation, settlement, cash-out, place-bet |
| Feature two | `fightevents` | `fightevents` | `FightEvents.xcframework` | `fightevents.aar` | Dataset parsing, bout index, card ordering, tale of the tape, search |

Both feature crates depend on `fightcore` as an ordinary Rust dependency and **neither depends on the other**. `fightevents` produces the bout index, `fightslip` consumes it, and the app is the only place the two meet — four lines of mapping in each host. That is the point of the split: a feature team ships its own binary without coordinating a release with the other feature.

```
sdks/
├── Cargo.toml            # workspace: three members
├── build-apple.sh        # packages all three SwiftPM packages
├── build-android.sh      # packages all three AARs, syncs the host's jniLibs/
├── core/                 # SwiftPM package FightCore
│   ├── Package.swift     #   binary target + the C header target + the bindings target
│   ├── fightcore/        #   the kernel crate
│   └── out/              #   FightCore.xcframework(.zip), android/fightcore.aar
├── slip/                 # SwiftPM package FightSlip   → crate depends on fightcore
├── events/               # SwiftPM package FightEvents → crate depends on fightcore
└── scripts/              # one shared packaging script per platform
```

## How the SDKs are delivered

Each SDK is its own SwiftPM package with its own binary target, resolved over HTTPS against a
pinned SHA-256, the same shape `03-sdk-rn` and `04-sdk-skip` use:

| Env | Binary target resolves to |
| --- | --- |
| `FIGHTDECK_LOCAL_SDK=1` | `out/FightCore.xcframework` from a local build |
| `FIGHTDECK_RELEASE_PATH=1` | `out/FightCore.xcframework.zip`, pinned but offline |
| neither | `$FIGHTDECK_RELEASE_BASE_URL/FightCore.xcframework.zip` + checksum |

`FightSlip` and `FightEvents` read the same three variables; each package's `Package.swift`
resolves its own artifact.

The xcframework carries the Rust staticlib and nothing else. UniFFI's C header goes into a
C target and the generated Swift into a Swift target, both inside the package, so the host
gets a plain `import FightCore` with no header search paths or module-map flags. Publishing
runs through `release-sdk.yml` (`sdk: rust`) or `tools/release-sdk-local.sh rust`.

## What three static libraries actually cost

Each crate compiles to its own `staticlib`, so each `.a` embeds a full copy of `fightcore` **and** the Rust standard library — roughly 17 MB apiece on disk. The Apple linker resolves duplicate definitions across archives to the first one it pulls, so the app pays for the kernel once. Measured by linking against every exported entrypoint with `-dead_strip` (arm64 simulator):

| Linked | Binary | Marginal |
| --- | ---: | ---: |
| `fightcore` alone | 0.60 MB | — |
| `+ fightslip` | 0.89 MB | +0.29 MB |
| `+ fightevents` | 1.30 MB | +0.41 MB |

The whole app in Release, both simulator architectures, all three SDKs linked: **11.4 MB**. `nm` finds `rust_eh_personality` exactly once in it.

Android does not get that deduplication. Each AAR ships a real `.so`, dynamically loaded, carrying its own copy of the kernel and of `std`:

| `lib/arm64-v8a/` | Size |
| --- | ---: |
| `libfightcore.so` | 437 KB |
| `libfightslip.so` | 682 KB |
| `libfightevents.so` | 1048 KB |

**2.2 MB on Android against roughly 0.7 MB of marginal cost on iOS, for the same source split.** That asymmetry is the honest number for the "should we split our SDK?" conversation, and it only shows up once there is more than one feature SDK to measure.

## What moved into Rust

Splitting the crates was the excuse to move logic that both hosts were maintaining twice:

| Logic | Was | Now |
| --- | --- | --- |
| Single vs accumulator mode | `syncMode()` in Swift **and** Kotlin | `SlipEngine::mode_for` |
| Place bet: validate, take stake, clear slip, compose message | 13 lines Swift + 14 lines Kotlin | `BetSlipStore::place_bet` → `PlaceBetOutcome` |
| Slip summary rows and their order | `slipSummary` in both hosts | `SlipStateRecord::summary_rows` |
| Bout index from `events.json` | `Codable` mirror + map in Swift, `@Serializable` mirror + map in Kotlin | `EventCatalog::bout_index` |
| Opponent and event lookup per slip leg | 23 lines Swift + 18 lines Kotlin | `EventCatalog::leg_context` |
| Tale of the tape, plus who holds each advantage | Five hand-written rows in each host | `EventCatalog::tale_of_the_tape` |
| `split_decision` → `Split decision`, clip durations | `displayMethod` / `formattedDuration` in both | `humanise_code`, `format_duration` |

Hand-written glue shrank accordingly:

| File | Before | After |
| --- | ---: | ---: |
| `ios/FightDeck/Core/FightCoreGlue.swift` | 125 | **78** |
| `android/.../core/FightCoreGlue.kt` | 115 | **72** |

What is left in those files is the part UniFFI genuinely cannot generate: a listener bridge republished as `@Observable` on iOS and `StateFlow` on Android. No betting rule survives in either.

## Hand-written Rust vs generated bindings

| Crate | Rust | Generated Swift | Generated Kotlin |
| --- | ---: | ---: | ---: |
| `fightcore` | 383 | 776 | 1219 |
| `fightslip` | 1255 | 1986 | 2739 |
| `fightevents` | 797 | 1563 | 2110 |
| **Total** | **2435** | **4325** | **6068** |

The generated columns are not maintained by anyone, but they are real compile time and real binary, and they scale per namespace rather than per line of logic — a third SDK costs another full scaffolding preamble.

## What UniFFI does **not** give you for free

- **Reactive UI bindings** — no `@Observable`, no `StateFlow`; you write the listener bridge (~75 lines per platform here).
- **Cross-SDK types** — `fightevents::BoutIndexEntry` and `fightslip::BoutIndexRecord` are separate types with identical shapes, because independent namespaces cannot share records without coupling their build. The host maps between them.
- **A single modulemap** — three xcframeworks each want to install `include/module.modulemap`, and Xcode copies them into one `include/`, where they collide. The xcframework ships libraries only; each package carries its header in a SwiftPM C target that gets its own include directory. UniFFI's own modulemap is discarded too, because it `use`s Darwin submodules SwiftPM does not put on the path.
- **Swift 6 concurrency** — the generated bindings do not survive strict checking, so the bindings target compiles in Swift 5 language mode. Confining that to one SwiftPM target is what lets the app itself build with `SWIFT_STRICT_CONCURRENCY: complete`, like every other approach here.
- **Simulator fat slices** — `cargo` builds one architecture at a time; the script `lipo`s `aarch64-apple-ios-sim` and `x86_64-apple-ios` together, or Release builds fail to link on x86_64.
- **Design-system UI** — screens, tokens, Kingfisher/Coil, navigation: still written per platform, mirroring `00-native/`.

## Build commands

Toolchain pins: [`versions.lock.toml`](../versions.lock.toml).

```bash
export PATH="$HOME/.cargo/bin:$PATH"
cd 02-core-rust/sdks

cargo test --workspace          # 16 tests: fixtures + unit

./build-apple.sh                # all three SPM packages: {core,slip,events}/out/*.xcframework
./build-android.sh              # all three AARs + syncs android jniLibs/ and uniffi/

./core/build-xcframework.sh     # or one SDK at a time
./slip/build-aar.sh
```

### Hosts

```bash
cd 02-core-rust/ios && xcodegen generate && xcodebuild -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

cd 02-core-rust/android && ./gradlew :app:assembleDebug
```

Set `FIGHTDECK_DATASET_ROOT` or rely on the default path to the repo `dataset/` (see `DatasetLocator`).

## Fixture coverage

| File | Cases | Status |
| --- | ---: | --- |
| `odds-conversion.json` | 40 | pass |
| `slip-math.json` | 6 | pass |
| `slip-validation.json` | 14 | pass |
| `settlement.json` | 7 | pass |
| `cash-out.json` | 5 | pass |
| **Total** | **72** | **72/72** |

The fixtures live in `slip/fightslip/tests/fixtures.rs` and run against a bout index built by `fightevents`, so they only pass when both feature SDKs agree on the same dataset. The iOS suite (`FightDeckTests`) does the same thing across the FFI boundary.

## Spec notes

- **`invalid_stake`** is a Rust-specific validation not present in `contract/fightcore-api.md`; it fires when the raw stake text will not parse, which the other approaches surface as a zero stake.
- **American odds** are explicitly out of scope per the contract; fractional display only.
- **`settle` and `cash_out_offer`** are implemented and fixture-tested but not yet on screen in either host.
