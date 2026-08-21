# 00-native — the baseline

Two apps, zero shared code. SwiftUI on iOS 26 and Jetpack Compose on Android 17, each written independently by a platform engineer who has never seen the other's source. That is the control group every other approach in this repository is measured against.

## What this demonstrates

- **Fair comparison.** The product, data, screens and golden fixtures are identical. Only the sharing mechanism differs in the other four folders.
- **Real native quality.** Not a straw man: `@Observable` and strict concurrency on iOS, Material 3 + edge-to-edge + predictive back on Android, Kingfisher and Coil for real HTTP image loads, PiP/AirPlay/Now Playing on the iOS-only video screen.
- **Duplication cost.** FightCore — odds, slip math, validation, settlement, cash-out — is implemented twice (~600 lines Swift, ~550 lines Kotlin). Deposit is hand-written twice behind the same `DepositHosting` boundary the SDK approaches use.

## Build commands

### iOS

Requires Xcode 26.6+ with iOS 26 SDK. Clone the repo so `dataset/` sits at `../../dataset` relative to `00-native/ios/`.

```bash
cd 00-native/ios
xcodegen generate   # only if project.yml changed; .xcodeproj is committed
xcodebuild build \
  -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  FIGHTDECK_DATASET_ROOT="$(cd ../.. && pwd)/dataset"
```

### Android

Requires JDK 17. Gradle wrapper is committed (9.7.1).

```bash
cd 00-native/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Unit tests read fixtures from `../../contract/fixtures` via Gradle `systemProperty` and dataset from `../../dataset`.

## Image loading

Both platforms start a **localhost HTTP server on port 8765** at launch, serving files from `dataset/assets/`. Poster and portrait URLs in JSON therefore hit Kingfisher/Coil over HTTP rather than bundled assets or `file://` URLs. Set `FIGHTDECK_DATASET_ROOT` (iOS scheme env) if the dataset is not at the default relative path.

## Fixture coverage

| File | Cases |
| --- | --- |
| `odds-conversion.json` | 40 |
| `slip-math.json` | 6 |
| `slip-validation.json` | 14 |
| `settlement.json` | 7 |
| `cash-out.json` | 5 |
| **Total** | **72** |

Both platforms load the same JSON from disk in unit tests and assert every case.

## iOS-only screens

Fighter profile, news feed and video (with PiP, AirPlay route picker, background audio session and Now Playing metadata) exist only under `00-native/ios`, per the shared UI spec.

## Honest duplication cost

Writing the product twice took roughly **2× the core logic** (FightCore + fixture tests), **2× the deposit flow**, and **1× the shared five-screen UI** on Android plus **1× the extended iOS UI**. In wall-clock terms for this demo:

| Area | Swift (lines, approx.) | Kotlin (lines, approx.) | Shared spec saved? |
| --- | --- | --- | --- |
| FightCore + tests | 900 | 850 | No — by design |
| Data + asset server | 250 | 200 | No |
| UI (five core screens) | 1,400 | 900 | No — tokens only |
| Deposit | 280 | 120 | Boundary only |
| iOS-only (news, fighter, video) | 450 | — | N/A |

The talk's headline number is not lines of code but **time to consistent behaviour**: any rule change in `contract/fightcore-api.md` must be applied in two languages, two test suites, and manually kept in sync until a shared core exists. The seven-fold accumulator (€361.11 vs €361.10) is the canonical example — one rounding mistake in either codebase fails CI independently.

## Package note (Android)

Java reserves the keyword `native`, so the Android Kotlin package is `com.fightdeck.baseline` while the application id remains `com.fightdeck.baseline` (module name `app` unchanged for CI).
