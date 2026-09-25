# 04-sdk-skip — UI-bearing Skip SDK

Three feature screens (**deposit**, **bet slip**, **fighter profile**) ship as SwiftUI source that becomes real Jetpack Compose on Android via **Skip Lite** (`skipstone`). The host apps are native SwiftUI and Compose; SDK screens mount through adapter protocols.

## What Skip actually does (read this before the README elsewhere)

**Skip never renders SwiftUI on Android.** [`SkipUI`](https://github.com/skiptools/skip-ui) is a reimplementation of the SwiftUI API, written in Swift but **always transpiled to Kotlin** (`skip.ui`), which calls Jetpack Compose. On iOS the same Swift is real SwiftUI — zero bridge, zero runtime tax.

## Lite vs Fuse — we chose **Lite**

| Mode | Android output | Swift on device | Typical baseline | Debugging on Android |
| --- | --- | --- | --- | --- |
| **Lite** (`skipstone`) | Kotlin via SwiftSyntax transpile | No | ~5 MB (Skip docs) | Full Android Studio |
| **Fuse** (`SkipFuseUI`) | Native Swift `.so` + JNI bridge | Yes | ~60 MB (Skip docs) | Almost none |

**Choice: Lite.** This demo optimises for a brownfield SDK story: the host Gradle project stays a normal Compose app, CI can diff transpiled Kotlin, and binary size stays in single-digit megabytes rather than Fuse’s ~60 MB native Swift runtime. We did **not** ship Fuse in this repo — see [Fuse size note](#fuse-size-note) below.

### Licensing (people trip over this)

| Component | License |
| --- | --- |
| Skip frameworks (`skip-ui`, `skip-foundation`, …) | **MPL-2.0** |
| `skipstone` build engine | **AGPL-3.0** |

Skip has been free and open source since 21 January 2026 (v1.7).

## Layout

```
sdks/core/      — FightCore (headless, skipstone): betting logic, DTOs, design tokens
sdks/events/    — Fight catalogue (headless): dataset loading and display formatting
sdks/deposit/   — Deposit SwiftUI → Compose
sdks/betslip/   — Bet slip SwiftUI → Compose
sdks/fighter/   — Fighter profile SwiftUI → Compose
ios/            — SwiftUI host (Events native; Slip/Deposit/Fighter from SDK)
android/        — Compose host (Events native; Slip/Deposit/Fighter SDK seam)
```

## Build order

```bash
# 1. Core fixtures (Swift Testing)
cd sdks/core
FIGHTDECK_FIXTURES_ROOT=../../../contract/fixtures swift test

# 2. Local binary SDK artifacts
cd sdks
./build-apple.sh
./build-aars.sh

# 3. iOS host
cd ios
xcodegen generate   # FightDeck.xcodeproj committed after first generate
xcodebuild build -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation

# 4. Android host
cd android && ./gradlew :app:assembleDebug
```

The package manifests expose source targets only while an SDK build script runs with
`FIGHTDECK_BUILDING_SDK=1`. Normal host builds always resolve the local xcframeworks and
the local Maven repository; there is no source/remote consumption switch.

## Artifact sizes (real binaries — measured 20 Aug 2026)

### iOS — `.xcframework.zip`

| Stack | Zip size |
| --- | --- |
| **Runtime / core alone** | **294 KB** (301,134 B) |
| **+ Deposit** | **2.15 MB** (2,253,282 B) |
| **+ Betslip** | **2.17 MB** (2,271,963 B) |

**Second-feature zip delta:** **+18 KB** (2,271,963 − 2,253,282 B).

### Android — `.aar` (deduped local Maven set, re-measured 12 Sep 2026 on Skip 1.9.8)

| Stack | Total |
| --- | --- |
| **Runtime / core alone** | **2.84 MB** |
| **+ Deposit** | **8.94 MB** |
| **+ Both features** | **9.07 MB** |

| Component | Size |
| --- | --- |
| `FightDeckCore-release.aar` | 123 KB |
| `SkipFoundation-release.aar` | 1.22 MB |
| `SkipLib-release.aar` | 1.54 MB |
| `SkipUnit-release.aar` | 12 KB |
| `SkipUI-release.aar` | 5.93 MB |
| `SkipModel-release.aar` | 84 KB |
| `FightDeckDeposit-release.aar` | 96 KB |
| `FightDeckBetslip-release.aar` | 129 KB |

**Second-feature module cost:** **129 KB** (`FightDeckBetslip-release.aar`).

## Fixture coverage (Swift FightCore)

| File | Cases |
| --- | --- |
| `odds-conversion.json` | 40 |
| `slip-math.json` | 6 |
| `slip-validation.json` | 14 |
| `settlement.json` | 7 |
| `cash-out.json` | 5 |
| **Total** | **72** |

```bash
cd sdks/core
FIGHTDECK_FIXTURES_ROOT=../../../contract/fixtures swift test
# 5 suites, 72 fixture assertions — all pass
```

Money uses `Decimal` with explicit HALF_UP via `#if SKIP` (`BigDecimal.setScale`) / `#else` (`NSDecimalRound`).

## Fuse size note

We did **not** build Fuse (`SkipFuseUI` + native Swift `.so`). Skip’s docs still quote **~60 MB** baseline for Fuse; we cannot confirm improvement from this repo. Lite measured **~2.8 MB** core / **~8.7 MB** with SkipUI — well under 60 MB, at the cost of transpilation constraints.

## Embedding seam — `SaveableStateProvider`

Skip warns that SwiftUI state (`@AppStorage`, `NavigationPath`, etc.) **does not participate in Android Activity state restoration**. The documented fix when mounting inside a **foreign** Compose host:

```kotlin
val stateHolder = rememberSaveableStateHolder()
stateHolder.SaveableStateProvider("myKey") {
    DepositComposeEntry(...).Compose()
    DisposableEffect("myKey") {
        onDispose { stateHolder.removeState("myKey") }
    }
}
```

Implemented in [`android/.../SkipSDKBridge.kt`](android/app/src/all/java/com/fightdeck/baseline/sdk/SkipSDKBridge.kt). Cleanup runs when the provider leaves composition — not on every recomposition, which would delete the slot `SaveableStateProvider` just wrote. `MainActivity` calls `ProcessInfo.launch(context = applicationContext)` once at startup (required by SkipFoundation). Verified: `./gradlew :app:assembleAllDebug` links real AARs; APK dex contains `DepositComposeEntry`, `BetslipComposeEntry`, `FighterComposeEntry`, `DepositFlowView`, `BetSlipRootView`, `FighterRootView`. iOS has no seam at all: the host puts `DepositFlowView`, `BetSlipRootView` and `FighterRootView` straight into its own SwiftUI tree, so there is nothing to bridge and nothing to wrap.

## Host split

| Screen | iOS | Android |
| --- | --- | --- |
| Event list / card / bout | Native SwiftUI | Native Compose |
| Bet slip | **FightDeckBetslip** SDK → `BetSlipRootView` | **SkipSDKBridge** → `BetslipComposeEntry(...).Compose()` |
| Deposit | **FightDeckDeposit** SDK → `DepositFlowView` | **SkipSDKBridge** → `DepositComposeEntry(...).Compose()` |
| Fighter profile | **FightDeckFighter** SDK → `FighterRootView` | **SkipSDKBridge** → `FighterComposeEntry(...).Compose()` |

## `skip checkup` (verbatim summary, captured 20 Aug 2026 against Skip 1.9.6)

The pin has since moved to 1.9.11; this block is the original capture and has not been
re-run, so read the version lines as historical. What *was* re-verified — on 12 Sep 2026
for 1.9.8 and on 25 Sep 2026 for 1.9.11 — is the thing that matters here: every AAR
exports cleanly from a clean `.build`.

```
[✓] Skip version 1.9.6 (= 1.9.6)
[✓] macOS version 26.6.2 (> 13.5.0)
[✓] macOS architecture: ARM
[✓] Swift version 6.3.3 (> 5.9.0)
[✓] Swiftly version 1.1.3 (> 1.0.0)
[✓] Xcode version 26.6 (> 15.0.0)
[✓] Xcode tools SDKs: 5
[✓] Homebrew version 6.0.18 (> 4.1.0)
[✓] Gradle version 9.7.1 (> 8.6.0)
[✓] Java version 17.0.18 (> 17.0.0)
[✓] Android Debug Bridge version 1.0.41 (> 1.0.40)
[✓] Android SDK version 37.0.0 (> 29.0.0)
[✓] Resolve dependencies (13.45s)
[✓] Build hello-skip (21.92s)
[✓] Test Swift (12.44s)
[✗] Test Kotlin (39.1s)
[✗] Skip 1.9.6 checkup failed with 2 errors
```

Kotlin test failure: Robolectric in Skip’s hello-world cannot verify `compileSdk 37` (`HelloSkipTests.classMethod`). Environment/tooling mismatch, not FightDeck-specific. Full log: `/tmp/skip-checkup-2026-08-20T16:52:38Z.txt`.

Install: `brew install skiptools/skip/skip`

## Honest rough edges

1. **Skip Lite Swift subset** — `#if SKIP` workarounds throughout core (`Money`, `OddsEngine`, `FightCoreDisplay`) and UI (`ThemeColor.fromHex` string filtering, `Typography`, no `Color` extensions, `Money.parse` instead of decimal literals, string stake binding). Not all SwiftUI sugar transpiles.
2. **Transpilation fixes applied (20 Aug 2026)** — `ThemeTokens`/`BetslipTheme` hex parsing (`filtered += String(character)` not `append(Char)`); `BetSlipStore`/`DepositFlowView`/`BetSlipRootView` use `Money.parse` not float-derived `Decimal` literals or int fallbacks.
3. **Xcode + skipstone** — Host build needs `-skipPackagePluginValidation` until the Skip plugin is trusted in Xcode 26.
4. **SPM local binary iOS** — SDK build scripts use dynamic source products to create the
   xcframeworks; normal host builds consume those local binary targets through the umbrella
   packages.
5. **Android Maven consumption** — `./sdks/{core,events,deposit,betslip,fighter}/build-aar.sh` publishes to `sdks/out/maven` with transitive POM metadata (`kotlin-reflect`, `commonmark`, Compose Material via SkipUI). Hosts point at that repo in `android/settings.gradle.kts`; do not re-declare those runtime deps. Verify with `sdks/consumer-verify/android` (`../../android/gradlew :app:assembleAllDebug` after building fighter AARs).
6. **`skip checkup` Kotlin test** — Robolectric / compileSdk 37 mismatch in Skip hello-world harness (environment issue, not FightDeck-specific).
7. **Division does not transpile the way you would assume** — Kotlin lowers `BigDecimal /` to
   `divide(other, RoundingMode)`, which keeps the *dividend's* scale. `Money.one` has scale 0,
   so `Money.one / decimalOdds` was `1` on Android and `0.8333…` on iOS from one Swift source.
   `impliedProbability` and `fractionalToDecimal` were both wrong on Android until
   `Money.divide` started naming the precision explicitly. Anything dividing `Decimal` in
   shared code needs the same treatment; multiplication and addition are safe.

   It stayed hidden because the Android host kept its own hand-written Kotlin core, so the
   transpiled one was never exercised by the app or by a test. It surfaced the same day the
   host started using the SDK core. Duplicated logic does not just cost lines — it hides
   whether the shared copy is right.
8. **The shared core is not JVM-testable** — `Money.format` goes through skip-foundation's
   `NumberFormatter` onto `android.icu.text.NumberFormat`, which a plain unit test does not
   provide. The contract fixtures therefore assert rounding (pure `BigDecimal`) rather than
   formatted strings; formatting stays covered by the SDK's Swift tests. Robolectric would
   close the gap but does not support `compileSdk 37` yet. Business logic shared this way is
   not as environment-free as the Swift original.
9. **Consuming transpiled Swift from hand-written Kotlin** — a `BetSlip` reaching the host is
   a `MutableStruct` with emulated value semantics: `selections` is a `skip.lib.Array` so
   `size`/`isNotEmpty()` do not apply, fields keep Swift `ID` casing, there is no generated
   `copy()`, and the property getter hands back a write-back reference. Anything stored in a
   `StateFlow` has to be rebuilt rather than mutated. Cheaper than a mapper, but not free.
10. **Shared code is written against a narrower Swift** — two limits showed up the moment the
    catalogue moved into `sdks/events`. A generic `load<T: Decodable>` compiles on iOS and then
    fails as Kotlin with `Cannot use 'T' as reified type parameter`, so each file gets its own
    concrete decode. And `FormatStyle` exists only for numbers in skip-foundation: dates need
    `DateFormatter`/`RelativeDateTimeFormatter` and durations `String(format:)`, not
    `.formatted(date:time:)` or `Duration`. Both are fine to write — but you find them by
    building for Android, not by reading Swift.

    The date one is not only a spelling difference. `DateFormatter` and `Date.FormatStyle`
    disagree about region overrides, so on a simulator set to English with a Bulgarian region
    the four apps using the modern API print `Jun 14, 2026` and this one prints `14 Jun 2026`.
    Neither is wrong; the shared path is simply the one you cannot change, and the constraint
    that forces it is skip-foundation's, not yours.
11. **Sharing presentation exposes divergence too** — the two apps had been formatting the same
    dataset differently: `split_decision` was `Split Decision` on iOS (`localizedCapitalized`)
    and `Split decision` on Android (`replaceFirstChar`), and the iOS news list showed a
    relative date the Android list never rendered. One shared `Display` settles both. The
    Android news row is still missing its date — that is a UI gap, not a formatting one.
12. **R8 cannot see through transpiled Swift** — a `Codable` conformance becomes
    `container.decode(String::class, forKey: CodingKeys.boutID)`, which names its type and its
    key at runtime, and SkipUI reads part of the SwiftUI shape through `kotlin-reflect`. So
    `fight.deck.**` and `skip.**` have to be kept whole: 12.82 MB of dex against about 3 MB
    for every other approach in the repo. Narrowing it to keep members while letting R8 drop
    unreferenced classes saves 1.70 MB and produces an app that launches, shows *Something
    went wrong* on the events screen, and logs nothing at all — the decode failure arrives as
    a caught error, not a crash. The shrinker is the one place where sharing more source costs
    real bytes rather than saving them.
13. **Chrome is not shared until something hosts it** — `DepositFlowView` declares a
    `navigationTitle` and a toolbar with a Close button. On iOS the host sheet wraps it in a
    `NavigationStack`, so both appear; on Android `DepositComposeEntry` handed the view
    straight to a Compose bottom sheet, and a toolbar with no bar to live in renders nothing
    at all — no title, no way out but the system back gesture. The entry point now carries its
    own `NavigationStack`, which is one line of shared code instead of a Compose top bar per
    host. Two follow-ons surfaced immediately: `navigationBarTitleDisplayMode(.inline)`
    silently suppresses the title on Android (it is `#if !SKIP` now, so Android gets the large
    one), and a `ToolbarItemGroup(placement: .keyboard)` — written for a keyboard accessory —
    was rendered as a sliver clipped to the trailing edge of the navigation bar, because
    SkipUI has nowhere to put keyboard placement.
14. **The Android app links AARs, not sources** — `android/app/build.gradle.kts` consumes
    `fightdeck.skip:FightDeck*Binary` from `sdks/out/maven`, so editing Swift and pressing Run
    builds and installs happily while shipping the previous transpile. The deposit screen ran
    two days behind its source this way. `./sdks/<module>/build-aar.sh` is not optional after
    touching an SDK, and `.build/plugins/outputs/**/skipstone/**/*.kt` is where to check what
    Android is actually getting.
15. **SF Symbols leak into accessibility** — `Button("Close", systemImage: "xmark")` announces
    as *xmark* on Android, because SkipUI uses the symbol name as the content description
    instead of the button's label. Symbols it cannot map at all (the radio circles in the
    deposit method rows) draw as a warning triangle described as *missing icon*.
16. **Keyboard avoidance is free on iOS and absent on Android** — the slip's `safeAreaBar`
    rides above the keyboard on iOS without a line about it, while the transpiled screen has
    no keyboard awareness at all: the `ZStack`'s bottom-aligned bar stayed where it was and
    the keys covered *Place bet* outright. The host now lifts the whole surface
    (`Modifier.imePadding()` on the slip destination in `FightDeckScreens.kt`), which is glue
    per screen rather than per control, and the SDK's own `ToolbarItemGroup(placement:
    .keyboard)` still renders nowhere — so Android has no *Done* button beside *Place bet*
    where the other four apps do. What SwiftUI gives you implicitly is exactly what does not
    survive transpilation, because there is no API call to translate.
17. **A scroll view that does not grow for the keyboard** — the deposit form's *Confirm
    deposit* button sat inline at the end of a `ScrollView`, which is the natural way to write
    it and works on iOS: the keyboard shrinks the scroll viewport and the button scrolls into
    reach. On Android the transpiled `ScrollView` kept its old content height, so the last
    rows were behind the keys with nothing left to scroll. The button is now pinned in a
    `ZStack(alignment: .bottom)` like the slip's action bar — a layout the SDK did not need
    for its own sake, adopted so one platform can reach it.

## Architecture

```
Host (SwiftUI / Compose)
  │  iOS: the SwiftUI view directly · Android: *ComposeEntry via SkipSDKBridge
  ▼
FightDeckDeposit / FightDeckBetslip / FightDeckFighter  (SwiftPM + skipstone)
  │  SkipUI Swift → Kotlin (Compose)
  ▼
FightDeckCore  (headless, shared fixtures)
```

On iOS, Skip costs **nothing extra** beyond SwiftUI. On Android, SkipUI + SkipFoundation + SkipLib are the price — and that price lands **only on Android**.
