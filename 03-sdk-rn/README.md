# 03-sdk-rn — UI-bearing React Native SDK

Three feature screens (**deposit**, **bet slip**, **fighter profile**) ship as a black box over **one shared Hermes runtime**. The host apps are native SwiftUI and Compose; they never import React Native.

## What this demonstrates

| Decision | Implementation |
| --- | --- |
| Shared runtime + feature adapters | `FightDeckRNRuntime`, `DepositSDK`, `BetslipSDK`, `FighterSDK` (CocoaPods / Gradle modules) |
| Mockable adapter boundary | `DepositHosting` / `BetslipHosting` / `FighterHosting` protocols |
| Theme as JSON | `themeJSON` in params from `shared-ui-spec/tokens.json` |
| Runtime singleton | `FightDeckRuntime.shared` — prewarm → host |
| One typed boundary, written once | `sdks/core/src/specs/NativeFightDeckRuntimeBridge.ts` → Codegen → ObjC++ protocol, Java base class, JSI/JNI glue |
| Zero host native modules | The Turbo Module lives in the runtime SDK; the host never registers one |
| Data and chrome on separate channels | Surface props carry data only; safe areas and keyboard go through `publishLayout` |
| Prewarm | `prewarm()` with startup metrics |
| Hermes bytecode | `fightdeck.hbc` in runtime resource bundle |

## Build order

```bash
# 1. TypeScript core + fixtures
cd sdks/core && npm install && npm test

# 2. JS bundle + Hermes bytecode (also run by ./sdks/build-apple.sh)
cd sdks/core && ./build-jsbundle.sh      # emits ios/Resources/fightdeck.hbc

# Bundle only, for a different feature set — no need to rebuild three architecture slices
cd sdks/core && FIGHTDECK_FEATURES=deposit ./build-jsbundle.sh

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

## Local binary SDKs

Hosts always consume artifacts built under `sdks/*/out`; there is no source/remote switch.

```bash
cd 03-sdk-rn
npm ci --prefix sdks/core
./sdks/build-apple.sh
./sdks/build-android.sh
```

### iOS distribution zip layout (RN core)

`FightDeckRNRuntime.xcframework.zip` contains the adapter xcframework **plus** bundled
RN/Hermes frameworks and `Resources/fightdeck.hbc`. The local CocoaPods vendor wrappers
under `sdks/out/ios-vendor/` link everything into the iOS host.

## Artifact sizes (real binaries — measured 20 Aug 2026)

### iOS — `.xcframework.zip`

| Stack | RN | Skip |
| --- | --- | --- |
| **Runtime / core alone** | **154.6 MB** (162,117,764 B) | **294 KB** (301,134 B) |
| **+ Deposit** | **73 KB** (74,292 B) adapter zip | **2.15 MB** (2,253,282 B) |
| **+ Betslip** (second feature) | **49 KB** (50,096 B) adapter zip | **2.17 MB** (2,271,963 B) |
| **+ Fighter** (third feature) | *(re-measure)* | *(re-measure)* |

RN core zip bundles `React.xcframework`, `hermesvm.xcframework`, `ReactNativeDependencies.xcframework`, and Hermes bytecode. Feature zips are adapter-only; runtime is shared.

**Second-feature cost (zip):** RN **−24 KB** (betslip adapter smaller than deposit); Skip **+18 KB** (2,271,963 − 2,253,282 B). **Third-feature cost:** not yet measured — see `FightDeckHarnessAll` / `all` Android flavour.

### Android — distributable `.aar` set

| Stack | RN (deduped) | Skip (deduped) |
| --- | --- | --- |
| **Runtime / core alone** | **239 MB** (react 161 MB + hermes 77.5 MB + runtime 236 KB + soloader 117 KB) | **2.83 MB** |
| **+ Deposit** | **+8.8 KB** adapter | **8.93 MB** total |
| **+ Both features** | **+13.4 KB** adapters (deposit 8.8 KB + betslip 4.5 KB) | **9.03 MB** total |
| **+ All features** | *(re-measure)* | *(re-measure)* |

Skip core stack: `SkipFoundation` 1.22 MB + `SkipLib` 1.54 MB + `SkipUnit` 12 KB + `FightDeckCore` 116 KB. Deposit adds `SkipUI` 5.91 MB + `SkipModel` 84 KB + feature module ~100 KB.

**Second-feature cost (feature module AAR):** RN **4.5 KB** (`BetslipSDK.aar`); Skip **94 KB** (`FightDeckBetslip-release.aar`). **Third-feature cost:** not yet measured — `FighterSDK.aar` added under `sdks/fighter/`.

### JS / Hermes payload (RN only)

All-surfaces bundle (`FIGHTDECK_FEATURES=all`); the deposit-only entry is roughly 16 KB smaller than the two-feature bundle, and the two-feature entry is smaller than all three.

| Artifact | Size | Shipped |
| --- | --- | --- |
| Metro `fightdeck.jsbundle` | 924 KB | no — staged under `ios/.jsbundle-staging/`, input to hermesc |
| Hermes `fightdeck.hbc` | 1.28 MB | yes — iOS zip (Android apps bundle their own entry at build time) |

## Verification — RN is real, not a placeholder

| Platform | How verified |
| --- | --- |
| **iOS** | `RNIntegrationTests` finds RN UI text ("Balance", "No selections yet"). Host uses `FightDeckRNHost.mm` → `RCTReactNativeFactory` → `viewWithModuleName:` (Fabric surface). |
| **Android** | `RNIntegrationTest` asserts logcat `Running "DepositFeature"` / `Running "BetslipFeature"` (UiAutomator fallback). Host uses `ReactHost.createSurface()` inside `AndroidView`. |

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
| **Cold** (first surface without prior prewarm) | **7 ms** | **19 ms** |

The hooks report **synchronous host init**, not time-to-first-paint: prewarm times the call that starts the host, cold times host start plus creating the first surface. Neither waits for the JavaScript to load, which happens on the JS thread afterwards. The cold row was measured on 25 Sep 2026, one run each, by launching with `-SkipRNPrewarm` (iOS, `iPhone 17 Pro` simulator, iOS 26.5) or `--ez SkipRNPrewarm true` (Android, `Medium_Phone_API_36.1` emulator, arm64), opening the Slip tab, and reading `[FightDeckStartup] cold=` from the log. The machine was under heavy load at the time, so read it as an order of magnitude. Before that, both hosts read the clock before creating the surface and reported 0 ms. Prewarm is the production pattern; the cold path exists to measure against it.

## Host app split

| Screen | iOS | Android |
| --- | --- | --- |
| Event list / card / bout detail | Native SwiftUI | Native Compose |
| Bet slip | **BetslipSDK** (RN) | **RNBetslipScreen** (RN) |
| Deposit | **DepositSDK** (RN) | **RNDepositScreen** (RN) |
| Fighter profile | **FighterSDK** (RN) | **RNFighterProfileScreen** (RN) |

## Honest seams

1. **iOS binary host (RN)** — local CocoaPods vendor wrappers link the generated adapter,
   React and Hermes xcframeworks.
2. **Android binary host (RN)** — SDK adapter AARs come from `sdks/*/out`;
   `react-android` / `hermes-android` still resolve from Maven to avoid duplicate classes.
3. **Codegen writes the boundary, but not in the languages the hosts are written in** — `sdks/core/src/specs/NativeFightDeckRuntimeBridge.ts` is the one place the calls between React and the hosts are declared. Codegen turns it into an ObjC++ protocol with JSI glue at `pod install`, and a Java base class with JNI glue in Gradle. Swift cannot conform to a protocol whose header is C++, so `FightDeckRuntimeBridge.mm` forwards each generated method to `FeatureResults` in Swift. On Android the JNI half has to be compiled into the app's `libappmodules.so` while the Java half ships in the runtime AAR, so Codegen runs twice from the same `package.json` and the app build deletes its own copy of the Java class, which would otherwise not dex. What Codegen does not reach is a surface's own properties: React Native's root props are an untyped dictionary, so `*Params` → dictionary / `Bundle` is still written by hand on both sides.
4. **Startup metrics** — measure synchronous host init, not TTI. The cold path runs only behind the `SkipRNPrewarm` launch flag, and each runtime logs it when the first surface is created.
5. **Visual parity on RN surfaces** — deposit and bet slip render through React Native widgets (`View`, `Text`, `TextInput`), not SwiftUI Liquid Glass or Material 3 expressive components. Theme JSON aligns colours and spacing with the native host, but the toolkit seam is visible by design.
6. **iOS feature gating is a build-time concern only** — Which pods a target links is fixed by target name in the `Podfile`, so the demo app needs no conditional compilation and the four `ios/Harness/` measurement hosts each compile against exactly the SDKs they import. `FIGHTDECK_FEATURES` survives for one job the target name cannot do: picking the JS bundle's entry point when the SDK is built. Nothing ties the bundle to the host, so the `Podfile` compares the value against the `ios/.fightdeck-features` stamp and refuses a mismatch rather than producing an app whose size means nothing.
7. **Android Fabric layout specs** — `FabricLayoutSpecsBridge` reflects `ReactSurfaceImpl.updateLayoutSpecs$ReactAndroid` because bridgeless RN 0.87 exposes no public pre-start layout API. Coupled to the pinned `react_native.version` in `versions.lock.toml`; upgrade RN only after re-verifying this seam.
8. **A native fast path hides the shared code behind it** — `GlassPresetChipRow` renders a real UIKit view on iOS and a JS fallback everywhere else. The fallback row never claimed a width, so its `flex: 1` chips measured zero and the deposit screen's €10/€25/€50/€100 row arrived on Android as four hairlines — while iOS, going through the native component, looked perfect. Shared code is only as tested as its least-exercised branch, and a per-platform shortcut is exactly where that branch hides.
9. **The host owns the chrome, per platform** — the React screen draws the deposit form and nothing around it, so the title and the Close button are written twice: a `NavigationStack` toolbar on iOS, a `TopAppBar` in the Compose sheet on Android. The RN side reports `confirmed` so both hosts can drop the close affordance once the money has moved. Compare with `04-sdk-skip`, where the same two controls are declared once in Swift.
10. **Two hosts, two coordinate systems, one JS layout** — the React bar clears the keyboard using numbers the host sends it, and iOS sends points while Compose reads window insets in pixels. Nothing in between converts, so on a 2.6× screen the bet slip's "Place bet" row asked for a lift almost three times too deep; JS clamped it at 400 and the bar came to rest in the middle of the form. The insets also measure from the window edge, while the surface stops above the tab bar, so the whole tab bar's height was counted a second time. `RNSurfaceLayoutHost.kt` now scales to density-independent units and reports only the slice of an inset that reaches the surface. A bridge that passes bare numbers has no way to say which units they are in, and the receiving side cannot tell a plausible number from a wrong one.
11. **The JS bundle is found by name, so nothing checks that it is there** — `FightDeckRNHost.mm` resolves the Hermes bytecode by asking for `FightDeckRNRuntime.bundle` and then `fightdeck.hbc` inside it. The source podspec ships that as a `resource_bundles` entry, but the vendored binary podspec `sdks/build-apple.sh` generates had declared it as a plain `s.resources`, which copies the file to the app bundle root instead. Both spellings build clean and both put a 1.3 MB `.hbc` in the app; the lookup simply returned `nil`, fell through to `RCTBundleURLProvider`, found no Metro packager and killed the app on launch with *No script URL provided*. Resource wiring across a binary pod boundary has no compiler on either side of it, so a demo app can pass a full build and still not start.
12. **A typed call still arrives on somebody else's thread** — Android delivers Turbo Module methods on React Native's native-modules thread, and the host answers "Add funds" by navigating, which Compose only allows on the main thread. The untyped bridge used the same thread and crashed the same way. `FightDeckRuntimeBridgeModule` now posts every result to the main thread, which is what the iOS module's `methodQueue` does.

## Architecture sketch

```
Host (SwiftUI / Compose)
  │  DepositHosting / BetslipHosting / FighterHosting  ← mockable, no RN import
  ▼
DepositSDK / BetslipSDK / FighterSDK  (feature pod/AAR)
  │  props = data only; unchanged params never reach React
  ▼
FightDeckRNRuntime  (RCTReactNativeFactory / ReactHost, one Hermes, bundle in Resources/)
  │  FightDeckRuntimeBridge — Turbo Module, Codegen from NativeFightDeckRuntimeBridge.ts
  │    JS → host: typed results      host → JS: surfaceLayout() + onSurfaceLayout
  ▼
JS: DepositFeature / BetslipFeature / FighterFeature + shared FightCore (decimal.js)
```
