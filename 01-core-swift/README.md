# 01-core-swift — headless Swift core, cross-compiled for Android

Two host apps (SwiftUI + Compose) sharing one **Swift FightCore** package. On iOS the core is consumed directly via SPM and `@Observable` drives SwiftUI. On Android the goal is the same core cross-compiled through the **Swift SDK for Android** and bridged with **swift-java** — that path is the headline of this approach, and this README documents exactly where it stands.

## What this demonstrates

- **One Swift implementation** of `contract/fightcore-api.md` — odds, slip math (including the seven-fold €361.11 trap), validation, settlement, cash-out.
- **`@Observable` slip state** in `BetSlipStore`, tracked by SwiftUI on iOS. The Android headline is getting the same object to drive Compose recomposition (Skip route) or manual observation (swift-java route).
- **Ports across the language boundary** — `PreferencesStore` is declared in Swift, implemented in Kotlin over `SharedPreferences`.
- **Typed throws** — `FightRepository` uses `async throws(FightCoreError)` in Swift; the Android binding should surface Kotlin `suspend` with a typed domain error.
- **Honest failure mode** — the cross-compile needs an open-source toolchain, which a Mac with Xcode does not have, and the JNI bindings are unwritten. The Compose app builds with a **clearly marked stub** rather than pretending the Swift `.so` is linked.

## Build commands

### Swift core (macOS)

```bash
cd 01-core-swift/sdks/core
swift test                                    # 72 golden fixture cases
./build-xcframework.sh                        # → out/FightCore.xcframework.zip
./build-aar.sh                                # → out/fightcore.aar (see Android section)
```

### iOS host

Requires Xcode 26.6+, iOS 26 SDK. Scheme: **FightDeck**.

```bash
cd 01-core-swift/ios
xcodegen generate    # only if project.yml changed; .xcodeproj is committed
xcodebuild build \
  -scheme FightDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  FIGHTDECK_DATASET_ROOT="$(cd ../.. && pwd)/dataset"
```

The iOS app depends on `../sdks/core` as a local SPM package (not the zipped XCFramework). Set `FIGHTDECK_LOCAL_SDK=1` semantics apply when CI consumes the release artifact instead.

### Android host

Requires JDK 17. Gradle wrapper 9.7.1.

```bash
cd 01-core-swift/android
./gradlew :app:assembleDebug
```

**The Android app does not load the cross-compiled Swift today**, though the AAR now builds: the app links a Kotlin stub because the JNI bindings between Kotlin and the Swift `.so` are not written. See [Android: what worked and what didn't](#android-what-worked-and-what-didnt).

---

## Fixture results

| File | Cases |
| --- | --- |
| `odds-conversion.json` | 40 |
| `slip-math.json` | 6 |
| `slip-validation.json` | 14 |
| `settlement.json` | 7 |
| `cash-out.json` | 5 |
| **Total** | **72** |

```bash
cd 01-core-swift/sdks/core && swift test
# Test run with 5 tests in 1 suite passed
```

All five `@Test` suites load JSON from `../../contract/fixtures` and assert every case.

---

## Apple artifacts

| Artifact | Size |
| --- | --- |
| `out/FightCore.xcframework.zip` | **725 KB** |
| `out/FightCore.xcframework/` (uncompressed) | **2.4 MB** |
| Per-slice static libs (`libFightCore.a`) | ~770–783 KB each |

Built with Apple Swift 6.3.3 / Xcode 26.6 for `arm64-apple-ios`, `arm64-apple-ios-simulator`, and `x86_64-apple-ios-simulator` (lipo-merged into one simulator slice).

---

## Android: what worked and what didn't

### Route 1 — Bare Swift SDK + swift-java

The cross-compile works, and where it runs decides whether it works at all.

| Step | Result |
| --- | --- |
| Install `swift-6.3.3-RELEASE_android` SDK | ✅ `swift sdk install` with the published checksum, then `setup-android-sdk.sh` against NDK r27d |
| `swift build --swift-sdk aarch64-unknown-linux-android28` | ✅ On an **open-source** toolchain — ❌ on Xcode's |
| `./build-aar.sh` | ✅ `fightcore.aar` with both ABIs, built by `sdk-core-swift.yml` on every dispatch |

**The failure worth knowing about.** On a Mac whose `swift` is Xcode's, the same command dies at the first import:

```
BetSlipStore.swift:9:8: error: compiled module was created by an older version of the compiler;
rebuild 'Foundation' and try again:
.../swift-6.3.3-RELEASE_android.artifactbundle/.../Foundation.swiftmodule/aarch64-unknown-linux-android.swiftmodule
```

The SDK's prebuilt Foundation was compiled by the open-source Swift 6.3.3 toolchain; Xcode ships `swiftlang-6.3.3.1.3`. Same version number, different compiler build, incompatible module format. [Swift.org's guide](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html) says so outright:

> using a cross-compilation Swift SDK requires using an open-source toolchain and for the Swift SDK version to match exactly.

So the toolchain a developer already has on a Mac is the one that cannot do this. CI installs the open-source build with `swiftly` and the same script succeeds unchanged.

### Measured `.so` / `.aar` sizes

From the `swift-core-aar` artifact, per ABI, uncompressed:

| Library | Size |
| --- | --- |
| `libfightcore.so` — the shared business logic | **615 KB** |
| `lib_FoundationICU.so` | 41.5 MB |
| `libFoundationEssentials.so` | 10.0 MB |
| `libswiftCore.so` | 9.7 MB |
| `libFoundation.so` | 8.9 MB |
| 13 more runtime libraries | 10.7 MB |
| **Total, 18 libraries** | **81.4 MB** (26.6 MB compressed in the AAR) |

Those 18 are the ELF `NEEDED` closure of the core, not the whole runtime directory — nothing here is padding. The ratio is the number to argue about: **615 KB of shared logic arrives with 81 MB of runtime**, three quarters of it ICU, because the core touches `Decimal` and date formatting. A core written against nothing but the standard library links a fraction of this, and that is a design decision, not a toolchain limitation.

Android App Bundle splits per ABI, so a device downloads one column rather than both.

### Route 2 — Skip `--native-model` (not attempted)

Skip would provide `skip export` → `.aar`, transparent `@Observable` → Compose tracking, and `async` → `suspend`. Approach 04 demonstrates the transpiled mode of the same tool; the native mode is a variation on it, not a separate discovery.

### Android app stub

Because no Swift artifact exists, the Compose host wires **`SwiftCoreBridge.isStub = true`** and uses the Kotlin port in `com.fightdeck.swiftcore.core` (copied from the native baseline for UI parity). Files marked **STUB — NOT THE SWIFT CORE**:

- `android/.../bridge/SwiftCoreBridge.kt`
- All of `android/.../core/` (Kotlin FightCore, not Swift)

`SharedPreferencesStore` **is** the real ports-and-adapters implementation of the Swift `PreferencesStore` protocol shape — ready for swift-java JNI callbacks when bindings exist.

---

## Debugging experience

| Platform | Swift breakpoints? | Notes |
| --- | --- | --- |
| iOS (SPM / Xcode) | ✅ Yes | Standard LLDB on `BetSlipStore`, `FightCore`, host views |
| Android (cross-compiled Swift) | ❌ **No** | No LLDB/studio integration for Swift inside a `.so` on ART. Debugging is `adb logcat`, `printf`, and rebuilding the `.so`. This is a real cost of the approach. |
| Android (Kotlin stub) | ✅ Yes | Standard Android Studio debugging on the stub layer only — not the Swift core |

We did not confirm whether future swift-java tooling adds a debugger; as of Swift SDK 6.3.3 + swift-java 0.4.2 pre-1.0, treat native Swift on Android as **printf-debugging only**.

---

## Rough edges hit

1. **Two Swifts with the same version number** — Apple Xcode 6.3.3 ≠ open-source 6.3.3-RELEASE for Android SDK module compatibility.
2. **NDK version drift** — Spec pins r27d; local install is r27.1. Setup script accepted it; r29 compatibility unconfirmed.
3. **swift-java pre-1.0** — Not installed; JNI packaging untested.
4. **Skip not installed** — Route 2 fallback unavailable without `skipstone` 1.9.6.
5. **`@Observable` + Observation on Android** — Requires Skip bridge or hand-rolled `StateFlow` glue; neither is wired yet.
6. **XCFramework from SPM** — No linked `.dylib` from `swift build` alone; script uses `libtool -static` on `.o` files, then `xcodebuild -create-xcframework`.
7. **Android Gradle OOM** — First `./gradlew` failed on dex merge; fixed by copying `gradle.properties` heap settings from `00-native`.

---

## Ambiguities in frozen specs

None blocking. One observation:

- `versions.lock.toml` pins NDK `27.3.13750724`; CI Ubuntu runners may have it preinstalled. Local macOS Android SDK had `27.1.12297006` only. The Swift SDK setup script accepted it; whether r27.1 vs r27d affects Foundation cross-compilation is untested.

---

## Layout

```
01-core-swift/
├── sdks/core/           SwiftPM FightCore + tests + build scripts
├── ios/                 SwiftUI host (scheme FightDeck)
├── android/             Compose host (module app) — Kotlin stub core
└── README.md            this file
```

## What we could not do, and what we did instead

| Intended | Actual |
| --- | --- |
| Swift `.so` + swift-java JNI `.aar` on Android | `.so` and `.aar` ✅ in CI; the JNI bindings that would let Kotlin call into them ❌ |
| `@Observable` driving Compose recomposition | iOS ✅ via `BetSlipStore`; Android uses Kotlin `StateFlow` stub |
| `PreferencesStore` in Swift, Kotlin JNI impl | Swift protocol ✅; Kotlin `SharedPreferencesStore` ✅; JNI bridge ❌ |
| Skip fallback AAR | Not attempted; approach 04 covers the same tool |
| Android app consuming Swift core | **Stub** — app builds, UI matches baseline, logic is Kotlin marked STUB |

The talk can show two phones with identical €361.11 on iOS (real Swift core) and Android (Kotlin stub with the same fixtures), and be honest about where the Swift story stops on Android: not at the compiler, which does the job on an open-source toolchain, but at the binding layer and at 81 MB of runtime for 615 KB of logic.
