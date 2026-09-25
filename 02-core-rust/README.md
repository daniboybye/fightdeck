# 02-core-rust — One Rust kernel, two Rust feature SDKs, via UniFFI

Same UFC betting product as [`00-native/`](../00-native/): event list, bout detail, bet slip, deposit. The business logic lives in three Rust components; SwiftUI and Compose are thin shells that bind to them. Apple keeps one binary per component, while Android aggregates all three UniFFI namespaces into one `libfightdeck.so`.

## Three logical SDKs, one Android runtime

| SDK | Crate | UniFFI namespace | Apple artifact | Android artifact | Owns |
| --- | --- | --- | --- | --- | --- |
| Kernel | `fightcore` | `fightcore` | `FightCore.xcframework` | `fightdeck.aar` | Decimal money, odds conversion, contract vocabulary and limits, deposit rules |
| Feature one | `fightslip` | `fightslip` | `FightSlip.xcframework` | `fightdeck.aar` | Bet slip store, validation, settlement, cash-out, place-bet |
| Feature two | `fightevents` | `fightevents` | `FightEvents.xcframework` | `fightdeck.aar` | Dataset loading (catalogue, news, media), bout index, card ordering, tale of the tape, search, the localhost image server |

Both feature crates depend on `fightcore` as an ordinary Rust dependency and **neither depends on the other**. `fightevents` produces the bout index, `fightslip` consumes it, and the app is the only place the two meet — four lines of mapping in each host. This remains a source and API boundary, but Android is now one native release unit: changing any crate creates a new common `.so`.

```
sdks/
├── Cargo.toml            # workspace: three components + the Android aggregate
├── build-apple.sh        # packages all three SwiftPM packages
├── build-android.sh      # packages one AAR/.so, syncs the host's jniLibs/
├── android/fightdeck/    # cdylib that re-exports all three UniFFI scaffolds
├── core/                 # SwiftPM package FightCore
│   ├── Package.swift     #   binary target + the C header target + the bindings target
│   ├── fightcore/        #   the kernel crate
│   └── out/              #   FightCore.xcframework(.zip)
├── slip/                 # SwiftPM package FightSlip   → crate depends on fightcore
├── events/               # SwiftPM package FightEvents → crate depends on fightcore
└── scripts/              # shared Apple packaging helper
```

## How the SDKs are delivered

Each SDK is its own SwiftPM package with one local binary target. `build-apple.sh` creates
the three xcframeworks under `{core,slip,events}/out/`; the host package manifests always
resolve those paths.

The xcframework carries the Rust staticlib and nothing else. UniFFI's C header goes into a
C target and the generated Swift into a Swift target, both inside the package, so the host
gets a plain `import FightCore` with no header search paths or module-map flags. Publishing
and remote checksum resolution are deliberately out of scope for this demo repository.

Android publishes one `fightdeck.aar`. Its `libfightdeck.so` contains the three namespaces,
and `uniffi-bindgen --library` still emits separate `fightcore`, `fightslip`, and
`fightevents` Kotlin packages. All three generated packages load the same native library.

## What three static libraries actually cost

Each crate compiles to its own `staticlib`, so each `.a` embeds a full copy of `fightcore` **and** the Rust standard library — roughly 17 MB apiece on disk. The Apple linker resolves duplicate definitions across archives to the first one it pulls, so the app pays for the kernel once. Measured by linking against every exported entrypoint with `-dead_strip` (arm64 simulator):

| Linked | Binary | Marginal |
| --- | ---: | ---: |
| `fightcore` alone | 0.60 MB | — |
| `+ fightslip` | 0.89 MB | +0.29 MB |
| `+ fightevents` | 1.30 MB | +0.41 MB |

The whole app in Release, both simulator architectures, all three SDKs linked: **11.4 MB**. `nm` finds `rust_eh_personality` exactly once in it.

Android originally shipped one `.so` per crate. Each dynamically loaded library carried its
own copy of the kernel and the Rust support code it used:

| Previous `lib/arm64-v8a/` | Size |
| --- | ---: |
| `libfightcore.so` | 437 KB |
| `libfightslip.so` | 682 KB |
| `libfightevents.so` | 1048 KB |

The aggregate crate now uses UniFFI's `uniffi_reexport_scaffolding!` mechanism to retain all
three components in one cdylib. The current arm64 `libfightdeck.so` is **2,075,512 bytes
(2.08 MB)**, versus about 2.17 MB for the three old files: a modest saving of roughly 4%,
not a threefold reduction. Rust and the linker already discarded much unused runtime code
from each old library; the common `.so` removes only the overlap that was actually present.

The trade-off is release granularity: Cargo recompiles only the changed crate and the small
aggregate crate, but every Android SDK update replaces and versions the common
`libfightdeck.so`. The three Rust crates and Kotlin namespaces remain separate APIs.

## What moved into Rust

Splitting the crates was the excuse to move logic that both hosts were maintaining twice:

| Logic | Was | Now |
| --- | --- | --- |
| Single vs accumulator mode | `syncMode()` in Swift **and** Kotlin | `SlipEngine::mode_for` |
| Place bet: validate, take stake, clear slip, compose message | 13 lines Swift + 14 lines Kotlin | `BetSlipStore::place_bet` |
| The "Bet placed" copy, and clearing it when the legs change | `betPlacedMessage` in `AppState` and `MainViewModel`, reset by hand in toggle and remove | `SlipSnapshot::confirmation` |
| Slip summary rows and their order | `slipSummary` in both hosts | `SlipStateRecord::summary_rows` |
| Bout index from `events.json` | `Codable` mirror + map in Swift, `@Serializable` mirror + map in Kotlin | `EventCatalog::bout_index` |
| Opponent and event lookup per slip leg | 23 lines Swift + 18 lines Kotlin | `EventCatalog::leg_context` |
| Tale of the tape, plus who holds each advantage | Five hand-written rows in each host | `EventCatalog::tale_of_the_tape` |
| `split_decision` → `Split decision`, clip durations | `displayMethod` / `formattedDuration` in both | `humanise_code`, `format_duration` |
| Deposit limits, method fees, fee rounding, preset amounts | `DepositFlowView` + `DepositMoney` in Swift, `DepositScreen` in Kotlin | `deposit_methods`, `deposit_presets`, `deposit_quote` |
| Reading the dataset, news and media | Each host read the files, and kept a JSON repository and news/media models | `EventCatalog::load`, `news`, `media` |
| Serving dataset images over localhost | `LocalAssetServer` on Network.framework and on `ServerSocket` | `start_asset_server`, `asset_url` |
| Balance, potential return, odds labels, validation messages | `formatCurrency` / `formatMoney` / `humaniseCode(validationErrorCode(…))` across FFI on every body pass | `SlipSnapshot::balance_display`, `SlipStateRecord::potential_return_display`, `ValidationIssue::message`, `CornerSummary::odds_decimal` |

Hand-written glue shrank accordingly:

| File | Before the split | After the split | One snapshot |
| --- | ---: | ---: | ---: |
| `ios/FightDeck/Core/FightCoreGlue.swift` | 125 | 74 | **56** |
| `android/.../core/FightCoreGlue.kt` | 115 | 61 | **41** |

Non-blank lines. What is left in those files is the part UniFFI genuinely cannot generate: a listener bridge republished as `@Observable` on iOS and `StateFlow` on Android. No betting rule survives in either.

The bridge carries one value. `BetSlipStore` hands every listener a `SlipSnapshot` — the slip, its
derived state, the balance and the "Bet placed" confirmation — after each change, so applying an update is
one assignment. It used to hand over only the derived state, and each host then called
`current_slip()` and `balance()`: three crossings, three locks and three copies per tap instead of
one. Registering a listener does not replay the current value; a host reads
`current_snapshot()` once when it starts and hears about every change after that. Whether an odds
button shows as selected is read off the same snapshot's legs, so nothing on screen can answer
from a newer state than the rest of it.

## Hand-written Rust vs generated bindings

| Crate | Rust | Generated Swift | Generated Kotlin |
| --- | ---: | ---: | ---: |
| `fightcore` | 383 | 776 | 1219 |
| `fightslip` | 1255 | 1986 | 2739 |
| `fightevents` | 797 | 1563 | 2110 |
| **Total** | **2435** | **4325** | **6068** |

The generated columns are not maintained by anyone, but they are real compile time and real binary, and they scale per namespace rather than per line of logic — a third SDK costs another full scaffolding preamble.

Each component has its own `uniffi.toml`. `generate_immutable_records = true` applies to
every UniFFI `Record` in that component: Swift receives `let` fields and Kotlin receives
`val` fields. It is a per-component and per-target-language setting, not a per-file or
per-struct annotation; individual exceptions can be listed under `mutable_records`.

## What UniFFI does **not** give you for free

- **Reactive UI bindings** — no `@Observable`, no `StateFlow`; you write the listener bridge (~50 lines per platform here).
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

cargo test --workspace          # 30 tests: fixtures, store + unit

./build-apple.sh                # all three SPM packages: {core,slip,events}/out/*.xcframework
./build-android.sh              # one fightdeck.aar/.so + three generated Kotlin packages

./core/build-xcframework.sh     # Apple can still build one SDK at a time
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
