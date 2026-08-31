# 03-sdk-rn — UI-bearing React Native SDK

Two feature screens (**deposit**, **bet slip**) ship as a black box over **one shared Hermes runtime**. The host apps are native SwiftUI and Compose; they never import React Native.

## What this demonstrates

| Decision | Implementation |
| --- | --- |
| Shared runtime + feature adapters | `FightDeckRNRuntime`, `DepositSDK`, `BetslipSDK` (CocoaPods / Gradle modules) |
| Mockable adapter boundary | `DepositHosting` / `BetslipHosting` protocols |
| Launcher separate from adapter | `DepositLauncher` fetches token, pushes VC |
| Theme as JSON | `themeJSON` in params from `shared-ui-spec/tokens.json` |
| Runtime singleton | `FightDeckRNRuntime.shared` — configure → registerFeature → host |
| Zero host native modules | JS → native via `NotificationCenter`, not host-registered modules |
| Prewarm + teardown | `prewarm()`, `destroyFeature(_:)` with startup metrics |
| Hermes bytecode | `fightdeck.hbc` in runtime resource bundle |

## Build order

```bash
# 1. TypeScript core + fixtures
cd sdks/core && npm install && npm test

# 2. JS bundle + Hermes bytecode (also run automatically by pod build)
cd sdks/core && ./build-xcframework.sh   # emits Resources/fightdeck.{jsbundle,hbc}

# 3. iOS host (CocoaPods — real RN linkage)
cd ios && pod install
xcodebuild build -workspace FightDeck.xcworkspace -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO

# 4. Android host (Gradle RN plugin — real RN linkage)
cd android && ./gradlew :app:assembleDebug

# 5. Verify RN surfaces
xcodebuild test -workspace FightDeck.xcworkspace -scheme FightDeck \
  -only-testing:FightDeckUITests/RNIntegrationTests CODE_SIGNING_ALLOWED=NO
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.fightdeck.baseline.RNIntegrationTest
```

Re-measure sizes after a Release archive / release APK:

```bash
# iOS archive (unsigned)
xcodebuild archive -workspace ios/FightDeck.xcworkspace -scheme FightDeck \
  -destination 'generic/platform=iOS' -archivePath /tmp/fightdeck-rn.xcarchive \
  -configuration Release CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO

./scripts/measure-artifacts.sh /tmp/fightdeck-rn.xcarchive
```

## Binary distribution

SDKs ship as checksum-pinned `.xcframework.zip` / `.aar` artifacts. Local development uses source; release consumption uses pinned binaries.

```bash
# Build + stage all artifacts, write manifest, print Package.swift snippets
./tools/release-sdk-local.sh rn    # or: skip

# Local development (source adapters + toolchain deps)
export FIGHTDECK_LOCAL_SDK=1

# Pinned Android (AARs under tools/out/release/<approach>/)
./gradlew :app:assembleDebug -PfightdeckLocalSdk=false

# Pinned iOS — RN uses CocoaPods vendor pods; Skip uses SPM with FIGHTDECK_RELEASE_PATH=1
unset FIGHTDECK_LOCAL_SDK
export FIGHTDECK_RELEASE_PATH=1   # resolves tools/out/release/<approach>/*.xcframework.zip
```

SPM `binaryTarget` URLs require **HTTPS** (GitHub Releases in production). `file://` and `http://localhost` are rejected by SwiftPM; checksum verification is proven via manifest + `swift package compute-checksum`, and SPM checksum rejection via a deliberate mismatch against a public HTTPS artifact.

### iOS distribution zip layout (RN core)

`FightDeckRNRuntime.xcframework.zip` contains the adapter xcframework **plus** bundled RN/Hermes frameworks and `Resources/fightdeck.hbc`. See `LAYOUT.txt` inside the zip. CocoaPods vendor pods under `tools/out/release/rn/ios-vendor/` link everything for pinned iOS hosts.

## Artifact sizes (real binaries — measured 20 Aug 2026)

### iOS — `.xcframework.zip`

| Stack | RN | Skip |
| --- | --- | --- |
| **Runtime / core alone** | **154.6 MB** (162,117,764 B) | **294 KB** (301,134 B) |
| **+ Deposit** | **73 KB** (74,292 B) adapter zip | **2.15 MB** (2,253,282 B) |
| **+ Betslip** (second feature) | **49 KB** (50,096 B) adapter zip | **2.17 MB** (2,271,963 B) |

RN core zip bundles `React.xcframework`, `hermesvm.xcframework`, `ReactNativeDependencies.xcframework`, and Hermes bytecode. Feature zips are adapter-only; runtime is shared.

**Second-feature cost (zip):** RN **−24 KB** (betslip adapter smaller than deposit); Skip **+18 KB** (2,271,963 − 2,253,282 B).

### Android — distributable `.aar` set

| Stack | RN (deduped) | Skip (deduped) |
| --- | --- | --- |
| **Runtime / core alone** | **239 MB** (react 161 MB + hermes 77.5 MB + runtime 236 KB + soloader 117 KB) | **2.83 MB** |
| **+ Deposit** | **+8.8 KB** adapter | **8.93 MB** total |
| **+ Both features** | **+13.4 KB** adapters (deposit 8.8 KB + betslip 4.5 KB) | **9.03 MB** total |

Skip core stack: `SkipFoundation` 1.22 MB + `SkipLib` 1.54 MB + `SkipUnit` 12 KB + `FightDeckCore` 116 KB. Deposit adds `SkipUI` 5.91 MB + `SkipModel` 84 KB + feature module ~100 KB.

**Second-feature cost (feature module AAR):** RN **4.5 KB** (`BetslipSDK.aar`); Skip **94 KB** (`FightDeckBetslip-release.aar`).

### JS / Hermes payload (RN only)

| Artifact | Size |
| --- | --- |
| Metro `fightdeck.jsbundle` | 914 KB |
| Hermes `fightdeck.hbc` | 1.30 MB (embedded in iOS zip + runtime AAR assets) |

## Verification — RN is real, not a placeholder

| Platform | How verified |
| --- | --- |
| **iOS** | `RNIntegrationTests` finds RN UI text ("Balance", "No selections yet"). Host uses `FightDeckRNHost.mm` → `RCTReactNativeFactory` → `viewWithModuleName:` (Fabric surface). |
| **Android** | `RNIntegrationTest` asserts logcat `Running "DepositFeature"` / `Running "BetslipFeature"` (UiAutomator fallback). Host uses `ReactHost.createSurface()` inside `AndroidView`. |

The Swift-only placeholder in `sdks/core/ios/Sources/FightDeckRNRuntime/RNHostEngineImpl.swift` is **not** used when building via CocoaPods — the ObjC++ pod target is the production path.

## Fixture coverage (TypeScript FightCore)

| File | Cases |
| --- | --- |
| `odds-conversion.json` | 40 |
| `slip-math.json` | 6 |
| `slip-validation.json` | 14 |
| `settlement.json` | 7 |
| `cash-out.json` | 5 |
| **Total** | **72** |

Money uses `decimal.js` — never JavaScript `number`.

## Cold vs prewarmed startup

| Path | iOS simulator | Android emulator (arm64) |
| --- | --- | --- |
| **Prewarm** (`ReactHost.start()` / `initializeReactHostWithLaunchOptions`) | **12–37 ms** | **113 ms** |
| **Cold** (first surface without prior prewarm) | **0 ms** in current host | **0 ms** in current host |

The hooks report **synchronous host init**, not time-to-first-paint. The cold path is intentionally not exercised — prewarm is the production pattern. A `-SkipRNPrewarm` launch flag would be needed to quote a meaningful cold-vs-warm delta on stage.

## Host app split

| Screen | iOS | Android |
| --- | --- | --- |
| Event list / card / bout detail | Native SwiftUI | Native Compose |
| Bet slip | **BetslipSDK** (RN) | **RNBetslipScreen** (RN) |
| Deposit | **DepositSDK** (RN) | **RNDepositScreen** (RN) |

## Honest seams

1. **iOS pinned host (RN)** — Vendor CocoaPods from `tools/out/release/rn/ios-vendor/` link bundled RN xcframeworks. SPM binary targets resolve the adapter module from the zip; full runtime linking uses the vendor pod layout documented in `LAYOUT.txt`.
2. **Android pinned host (RN)** — SDK adapter AARs are pinned from release; `react-android` / `hermes-android` still resolve from Maven to avoid duplicate-class conflicts with the RN Gradle plugin. Full self-contained AARs (161 MB + 77.5 MB) ship in `sdks/core/out/` for foreign hosts.
3. **SPM URL scheme** — Production checksum pins require HTTPS (GitHub Releases). Local bootstrap uses `FIGHTDECK_RELEASE_PATH=1` (path binary) plus manifest checksum verification.
4. **Fabric badge + Turbo `PreferencesStore`** — TypeScript specs and native stub files exist; codegen + ObjC++ Fabric wrapper not linked.
5. **Startup metrics** — measure host init, not TTI; cold path not wired in production hosts.
6. **Visual parity on RN surfaces** — deposit and bet slip render through React Native widgets (`View`, `Text`, `TextInput`), not SwiftUI Liquid Glass or Material 3 expressive components. Theme JSON aligns colours and spacing with the native host, but the toolkit seam is visible by design.
7. **iOS ships both `.hbc` and `.jsbundle`** in local Pods path — Release should prefer `.hbc` only to save ~914 KB.
8. **Android Fabric layout specs** — `FabricLayoutSpecsBridge` reflects `ReactSurfaceImpl.updateLayoutSpecs$ReactAndroid` because bridgeless RN 0.84 exposes no public pre-start layout API. Coupled to the pinned `react_native.version` in `versions.lock.toml`; upgrade RN only after re-verifying this seam.

## Architecture sketch

```
Host (SwiftUI / Compose)
  │  DepositHosting / BetslipHosting  ← mockable, no RN import
  ▼
DepositSDK / BetslipSDK  (feature pod/AAR)
  │  registerFeature("deposit", moduleName: "DepositFeature")
  ▼
FightDeckRNRuntime  (RCTReactNativeFactory / ReactHost, one Hermes, bundle in Resources/)
  │  NotificationCenter bridge (no host native modules)
  ▼
JS: DepositFeature / BetslipFeature + shared FightCore (decimal.js)
```
