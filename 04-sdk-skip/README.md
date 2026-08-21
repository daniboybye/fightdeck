# 04-sdk-skip — UI-bearing Skip SDK

Two feature screens (**deposit**, **bet slip**) ship as SwiftUI source that becomes real Jetpack Compose on Android via **Skip Lite** (`skipstone`). The host apps are native SwiftUI and Compose; SDK screens mount through adapter protocols.

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
sdks/core/      — FightCore (headless, skipstone)
sdks/deposit/   — Deposit SwiftUI → Compose
sdks/betslip/   — Bet slip SwiftUI → Compose
ios/            — SwiftUI host (Events native; Slip/Deposit from SDK)
android/        — Compose host (Events native; Slip/Deposit SDK seam)
```

## Build order

```bash
# 1. Core fixtures (Swift Testing)
cd sdks/core
FIGHTDECK_FIXTURES_ROOT=../../../contract/fixtures swift test

# 2. SDK artifacts
cd sdks/core    && ./build-xcframework.sh && ./build-aar.sh
cd sdks/deposit && ./build-xcframework.sh && ./build-aar.sh
cd sdks/betslip && ./build-xcframework.sh && ./build-aar.sh

# 3. iOS host (local SDK sources)
export FIGHTDECK_LOCAL_SDK=1
cd ios
xcodegen generate   # FightDeck.xcodeproj committed after first generate
xcodebuild build -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation

# 4. Android host
cd android && ./gradlew :app:assembleDebug
```

Fresh clones without `FIGHTDECK_LOCAL_SDK=1` resolve pinned release artifacts (checksums in `Package.swift`, filled by `tools/release-sdk-local.sh`).

## Binary distribution

Same packaging shape as `03-sdk-rn` — six scripts, six artifacts, checksum manifest.

```bash
./tools/release-sdk-local.sh skip

export FIGHTDECK_LOCAL_SDK=1          # local source + skipstone
./gradlew :app:assembleDebug -PfightdeckLocalSdk=false   # pinned Android AARs
unset FIGHTDECK_LOCAL_SDK
export FIGHTDECK_RELEASE_PATH=1       # pinned iOS xcframework zips (see SPM note below)
```

## Artifact sizes (real binaries — measured 20 Aug 2026)

### iOS — `.xcframework.zip`

| Stack | Zip size |
| --- | --- |
| **Runtime / core alone** | **294 KB** (301,134 B) |
| **+ Deposit** | **2.15 MB** (2,253,282 B) |
| **+ Betslip** | **2.17 MB** (2,271,963 B) |

**Second-feature zip delta:** **+18 KB** (2,271,963 − 2,253,282 B).

### Android — `.aar` (deduped set under `tools/out/release/skip/`)

| Stack | Total |
| --- | --- |
| **Runtime / core alone** | **2.83 MB** |
| **+ Deposit** | **8.93 MB** |
| **+ Both features** | **9.03 MB** |

| Component | Size |
| --- | --- |
| `FightDeckCore-release.aar` | 116 KB |
| `SkipFoundation-release.aar` | 1.22 MB |
| `SkipLib-release.aar` | 1.54 MB |
| `SkipUnit-release.aar` | 12 KB |
| `SkipUI-release.aar` | 5.91 MB |
| `SkipModel-release.aar` | 84 KB |
| `FightDeckDeposit-release.aar` | 99 KB |
| `FightDeckBetslip-release.aar` | 94 KB |

**Second-feature module cost:** **94 KB** (`FightDeckBetslip-release.aar`).

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
    DepositComposeEntry(...).Compose()   // intended
    SideEffect { stateHolder.removeState("myKey") }
}
```

Implemented in [`android/.../SkipSDKBridge.kt`](android/app/src/main/java/com/fightdeck/baseline/sdk/SkipSDKBridge.kt). `MainActivity` calls `ProcessInfo.launch(context = applicationContext)` once at startup (required by SkipFoundation). Verified: `./gradlew :app:assembleDebug` links real AARs; APK dex contains `DepositComposeEntry`, `BetslipComposeEntry`, `DepositFlowView`, `BetSlipRootView`. iOS uses ordinary `UIHostingController` via `DepositHosting` / `BetslipHosting` — no seam there.

## Host split

| Screen | iOS | Android |
| --- | --- | --- |
| Event list / card / bout | Native SwiftUI | Native Compose |
| Bet slip | **FightDeckBetslip** SDK | **SkipSDKBridge** → `BetslipComposeEntry(...).Compose()` |
| Deposit | **FightDeckDeposit** SDK | **SkipSDKBridge** → `DepositComposeEntry(...).Compose()` |

## `skip checkup` (verbatim summary, 20 Aug 2026)

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
4. **SPM pinned iOS** — Dynamic-library xcframework modules (`FightDeckCore`) collide with the umbrella product name when consumed via SPM path binaries; pinned iOS is verified with `FIGHTDECK_LOCAL_SDK=1` (source) or after GitHub HTTPS release. Android pinned + checksum manifest verification is fully wired.
6. **`skip checkup` Kotlin test** — Robolectric / compileSdk 37 mismatch in Skip hello-world harness (environment issue, not FightDeck-specific).

## Architecture

```
Host (SwiftUI / Compose)
  │  DepositHosting / BetslipHosting  ← mockable, UIKit adapters on iOS
  ▼
FightDeckDeposit / FightDeckBetslip  (SwiftPM + skipstone)
  │  SkipUI Swift → Kotlin (Compose)
  ▼
FightDeckCore  (headless, shared fixtures)
```

On iOS, Skip costs **nothing extra** beyond SwiftUI. On Android, SkipUI + SkipFoundation + SkipLib are the price — and that price lands **only on Android**.
