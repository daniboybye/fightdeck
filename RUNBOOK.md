# fightdeck runbook

Get all **five iOS host apps** on one simulator and all **five Android host apps** on one emulator, side by side. Every command below was run successfully against this repository on 22 August 2026, and the `01-core-swift` and `02-core-rust` sections were re-verified on 11 September 2026 after those approaches changed shape.

Toolchain pins live in [`versions.lock.toml`](versions.lock.toml). Read values with `./tools/versions.py <dotted.key>` (for example `./tools/versions.py apple.xcode` → `26.6`).

---

## Prerequisites

Install the pinned toolchain, then run the **Verify** column before continuing.

| Tool | Pinned version (`versions.lock.toml`) | Install | Verify |
| --- | --- | --- | --- |
| **Xcode** | `[apple] xcode = 26.6` (build `17F113`) | Mac App Store / [developer.apple.com](https://developer.apple.com/xcode/) | `xcodebuild -version` |
| **iOS Simulator runtime** | `[apple] ios_device = 26.6.1` (SDK `26.5` on simulators) | Xcode → Settings → Platforms | `xcrun simctl list runtimes \| grep 26.5` |
| **xcodegen** | (not pinned; 2.46.0 worked) | `brew install xcodegen` | `xcodegen --version` |
| **JDK** | `[android] jdk = 17` | Azul/Temurin 17, or Android Studio bundled JRE | `/usr/libexec/java_home -v 17` |
| **Android SDK** | `[android] compile_sdk = 37`, `platform_version = 17` | Android Studio **Quail 3 (2026.1.3 Patch 1)** → SDK Manager → API 37 | `adb version` and `$ANDROID_HOME/platforms/android-37` exists |
| **Android NDK** | `[android] ndk = 27.3.13750724` | SDK Manager → NDK **27.3.13750724** (Side by side) | `ls "$ANDROID_HOME/ndk/27.3.13750724"` |
| **Gradle / AGP** | `[android] gradle = 9.7.1`, `agp = 9.3.1` | Committed `./gradlew` in each `*/android/` | `./gradlew --version` |
| **swiftly** | (not pinned; 1.2.0 worked) | `curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh \| bash` | `swiftly --version` |
| **Open-source Swift** | `[apple] swift = 6.3.3` | `swiftly install 6.3.3` — Xcode's own Swift **cannot** cross-compile for Android | `swiftly run swift +6.3.3 --version` |
| **Swift SDK for Android** | `[apple.swift_sdks] android` | `swiftly run swift +6.3.3 sdk install <url> --checksum <sha>` | `swiftly run swift +6.3.3 sdk list` |
| **Rust** | `[rust] toolchain = 1.97.1` | `rustup toolchain install 1.97.1` | `rustc --version` |
| **Rust Apple targets** | `[rust.targets] apple` | `rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios` | `rustup target list --installed \| grep apple` |
| **Rust Android targets** | `[rust.targets] android` | `rustup target add aarch64-linux-android x86_64-linux-android` | `rustup target list --installed \| grep android` |
| **cargo-ndk** | `[rust] cargo_ndk = 4.1.2` | `cargo install cargo-ndk --version 4.1.2 --locked` | `cargo ndk --version` |
| **Node.js** | `[react_native] node = 24.19.0` | `nvm install 24.19.0` / `mise install` | `node --version` |
| **Skip (skipstone)** | `[skip] skipstone = 1.9.8` | `brew install skiptools/skip/skip` | `skip version` |
| **CocoaPods** | (RN host only) | `gem install cocoapods` or `brew install cocoapods` | `pod --version` |

Set these once per shell session:

```bash
export REPO="$(git rev-parse --show-toplevel)"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export PATH="$HOME/.cargo/bin:$PATH"
```

---

## One-time setup (after clone)

### 1. Dataset

The dataset is **not bundled** inside the apps. JSON and generated art live under `dataset/` at the repo root.

Regenerate if needed:

```bash
cd "$REPO"
python3 tools/build-dataset.py
python3 tools/fetch-real-art.py   # real Wikimedia photos + placeholders for gaps
```

`fetch-real-art.py` generates placeholders first, then overlays photographs listed in
`tools/image-sources.json`. Credits and fallbacks are recorded in `dataset/image-credits.json`.
To revert art only: `swift tools/generate-placeholder-art.swift`.

Regenerate launcher icons after changing approach colours or numbering:

```bash
swift tools/generate-app-icons.swift
```

Confirm:

```bash
test -f "$REPO/dataset/events.json" && echo OK
```

### 2. Generate Xcode projects

Every `*/ios/project.yml` is the source of truth. **Run `xcodegen generate` before the first build and again after adding or removing source files.** Deployment target is **iOS 26.1** (required by `tabViewBottomAccessory(isEnabled:)`).

```bash
for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
  (cd "$REPO/$approach/ios" && xcodegen generate)
done
```

Committed `.xcodeproj` files exist for convenience, but stale projects are a common failure mode — regenerate when in doubt.

### 3. Rust core (`02-core-rust`)

UniFFI bindings and native libraries are **build output**, not committed. Package once:

```bash
cd "$REPO/02-core-rust/sdks"
./build-apple.sh          # → {core,slip,events}/out/*.xcframework, bindings into each package
./build-android.sh        # → {core,slip,events}/out/android/*.aar (+ syncs jniLibs/ and uniffi/)
```

### 3b. Swift core for Android (`01-core-swift`)

The Compose host has no Kotlin fallback — it links the cross-compiled Swift core, and
`app/build.gradle.kts` fails the configuration phase if `sdks/core/out/fightcore.aar` is
missing. The AAR is build output, not committed. Package once:

```bash
cd "$REPO/01-core-swift/sdks/core"
swiftly run ./build-aar.sh +6.3.3    # ~12 min: both ABIs, jextract, SwiftKitCore jar
```

`swiftly run … +6.3.3` is not optional. Xcode's Swift cannot read the Android SDK's
prebuilt Foundation even at the same version number; see `01-core-swift/README.md`.

The iOS host needs nothing here — it consumes the package through SPM.

### 4. SDK approaches (`03-sdk-rn`, `04-sdk-skip`)

Host apps normally consume **checksum-pinned release binaries**. For a fresh clone without GitHub Releases, use either:

| Mode | When | What to do |
| --- | --- | --- |
| **Local SDK sources** | Working on SDK code; simplest bootstrap | `export FIGHTDECK_LOCAL_SDK=1` before iOS/Android SDK builds |
| **Local pinned binaries** | Testing the release consumption path | `./tools/release-sdk-local.sh rn` and/or `./tools/release-sdk-local.sh skip`, then `export FIGHTDECK_RELEASE_PATH=1` (iOS Skip SPM) and **unset** `FIGHTDECK_LOCAL_SDK` (Android Gradle reads `tools/out/release/<approach>/`) |

**React Native (`03-sdk-rn`) — local SDK**

```bash
export FIGHTDECK_LOCAL_SDK=1
cd "$REPO/03-sdk-rn"
npm install                                    # host + RN gradle plugin
cd sdks/core && npm install && npm test        # TypeScript FightCore fixtures
cd "$REPO/03-sdk-rn/ios" && pod install        # must use workspace, not bare xcodeproj
```

**Skip (`04-sdk-skip`) — local SDK**

```bash
export FIGHTDECK_LOCAL_SDK=1
# Optional: build distributable artifacts (also run by tools/release-sdk-local.sh skip)
for module in core deposit betslip; do
  (cd "$REPO/04-sdk-skip/sdks/$module" && ./build-xcframework.sh && ./build-aar.sh)
done
```

iOS schemes for `03-sdk-rn` and `04-sdk-skip` already set `FIGHTDECK_LOCAL_SDK=1` for **Run** in Xcode; you still need the env var (or staged release artifacts) at **build** time for CocoaPods / SPM resolution.

---

## Boot one simulator and one emulator

```bash
# iOS — iPhone 17 Pro on iOS 26.5 (adjust name/OS to match `xcrun simctl list devices`)
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator

# Android — any API 37 emulator (example)
adb devices    # must show one device/emulator
```

---

## Install dataset on Android

Apps read **`/data/local/tmp/fightdeck/dataset`** (see `DatasetLocator` in each Android app). Push from the repo root:

```bash
adb shell rm -rf /data/local/tmp/fightdeck/dataset
adb push "$REPO/dataset" /data/local/tmp/fightdeck/dataset
adb shell test -f /data/local/tmp/fightdeck/dataset/events.json && echo OK
```

**Do not** run `adb push dataset /data/local/tmp/fightdeck/dataset` when the destination already exists — Android creates `/data/local/tmp/fightdeck/dataset/dataset/` and the app silently keeps reading stale files. Always remove the destination first (see [Troubleshooting](#troubleshooting)).

---

## Build and install all five iOS apps

Uses one shared DerivedData tree under `$REPO/DerivedData/` (gitignored). Simulator destination must match a booted device.

```bash
export REPO="$(git rev-parse --show-toplevel)"
SIM='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
DD="$REPO/DerivedData/all-ios"
mkdir -p "$DD"

# SDK hosts: local sources (see One-time setup for alternatives)
export FIGHTDECK_LOCAL_SDK=1
(cd "$REPO/03-sdk-rn/ios" && pod install)

build_ios() {
  local approach="$1"
  echo "=== iOS build $approach ==="
  cd "$REPO/$approach/ios"
  local dd="$DD/$approach"
  if [[ "$approach" == "03-sdk-rn" ]]; then
    xcodebuild build \
      -workspace FightDeck.xcworkspace \
      -scheme FightDeck \
      -destination "$SIM" \
      -derivedDataPath "$dd" \
      CODE_SIGNING_ALLOWED=NO
  elif [[ "$approach" == "04-sdk-skip" ]]; then
    xcodebuild build \
      -project FightDeck.xcodeproj \
      -scheme FightDeck \
      -destination "$SIM" \
      -derivedDataPath "$dd" \
      CODE_SIGNING_ALLOWED=NO \
      -skipPackagePluginValidation \
      -skipMacroValidation
  else
    xcodebuild build \
      -project FightDeck.xcodeproj \
      -scheme FightDeck \
      -destination "$SIM" \
      -derivedDataPath "$dd" \
      CODE_SIGNING_ALLOWED=NO
  fi
  xcrun simctl install booted "$dd/Build/Products/Debug-iphonesimulator/FightDeck.app"
}

for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
  build_ios "$approach"
done
```

**Notes verified in this repo:**

- **`03-sdk-rn` builds from `FightDeck.xcworkspace`**, not the `.xcodeproj`, because CocoaPods links React Native and the SDK pods.
- **`04-sdk-skip` requires** `-skipPackagePluginValidation -skipMacroValidation`. Without them, `xcodebuild` fails at `Validate plug-in "skipstone" in package "skip"`.

---

## Build and install all five Android apps

Use the **`both`** product flavour for `03-sdk-rn` and `04-sdk-skip` — that is the default demo configuration (deposit + bet slip SDK screens). Flavours `runtime` and `deposit` exist only for size measurements.

`01-core-swift` needs its AAR built first (§3b) and `02-core-rust` needs its AARs (§3); both fail at configuration time otherwise.

```bash
export REPO="$(git rev-parse --show-toplevel)"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export FIGHTDECK_LOCAL_SDK=1

adb shell rm -rf /data/local/tmp/fightdeck/dataset
adb push "$REPO/dataset" /data/local/tmp/fightdeck/dataset

build_android() {
  local approach="$1"
  local task="$2"
  echo "=== Android build $approach ==="
  cd "$REPO/$approach/android"
  ./gradlew --no-daemon "$task"
  adb install -r "$3"
}

build_android 00-native        ':app:assembleDebug'      "$REPO/00-native/android/app/build/outputs/apk/debug/app-debug.apk"
build_android 01-core-swift    ':app:assembleDebug'      "$REPO/01-core-swift/android/app/build/outputs/apk/debug/app-debug.apk"
build_android 02-core-rust     ':app:assembleDebug'      "$REPO/02-core-rust/android/app/build/outputs/apk/debug/app-debug.apk"
build_android 03-sdk-rn        ':app:assembleBothDebug'  "$REPO/03-sdk-rn/android/app/build/outputs/apk/both/debug/app-both-debug.apk"
build_android 04-sdk-skip      ':app:assembleBothDebug'  "$REPO/04-sdk-skip/android/app/build/outputs/apk/both/debug/app-both-debug.apk"
```

Build **all measurement flavours** (optional):

```bash
cd "$REPO/03-sdk-rn/android"
./gradlew :app:assembleRuntimeDebug :app:assembleDepositDebug :app:assembleBothDebug
cd "$REPO/04-sdk-skip/android"
./gradlew :app:assembleRuntimeDebug :app:assembleDepositDebug :app:assembleBothDebug
```

---

## App identifiers and launch commands

All five pairs use **distinct** bundle IDs / application IDs so they co-install. No collisions (verified from `project.yml` and `app/build.gradle.kts`).

| Approach | iOS bundle ID | Launch iOS |
| --- | --- | --- |
| `00-native` | `com.fightdeck.native` | `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted com.fightdeck.native` |
| `01-core-swift` | `com.fightdeck.coreswift` | `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted com.fightdeck.coreswift` |
| `02-core-rust` | `com.fightdeck.rust` | `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted com.fightdeck.rust` |
| `03-sdk-rn` | `com.fightdeck.sdk.rn` | `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted com.fightdeck.sdk.rn` |
| `04-sdk-skip` | `com.fightdeck.sdk.skip` | `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted com.fightdeck.sdk.skip` |

| Approach | Android `applicationId` | Launcher activity |
| --- | --- | --- |
| `00-native` | `com.fightdeck.baseline` | `com.fightdeck.baseline/.MainActivity` |
| `01-core-swift` | `com.fightdeck.coreswift` | `com.fightdeck.coreswift/com.fightdeck.swiftcore.MainActivity` |
| `02-core-rust` | `com.fightdeck.rust` | `com.fightdeck.rust/.MainActivity` |
| `03-sdk-rn` | `com.fightdeck.sdk.rn` | `com.fightdeck.sdk.rn/com.fightdeck.baseline.MainActivity` |
| `04-sdk-skip` | `com.fightdeck.sdk.skip` | `com.fightdeck.sdk.skip/com.fightdeck.baseline.MainActivity` |

**`applicationId` is not the Kotlin package.** Three hosts kept their original package after
the ids were made distinct, so the `<applicationId>/.MainActivity` shorthand resolves to a
class that does not exist and `am start` fails with `Error type 3`. Use the full component
above, or let the package manager resolve it:

```bash
adb shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1
adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER <applicationId>
```

**iOS dataset env:** Xcode **Run** schemes set `FIGHTDECK_DATASET_ROOT=$(SRCROOT)/../../dataset`. When launching via `simctl`, pass `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT` as shown above.

**Android dataset path:** fixed at `/data/local/tmp/fightdeck/dataset` on device/emulator (not the repo path).

Launch every installed app:

```bash
for bid in com.fightdeck.native com.fightdeck.coreswift com.fightdeck.rust com.fightdeck.sdk.rn com.fightdeck.sdk.skip; do
  SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT="$REPO/dataset" xcrun simctl launch booted "$bid"
done

for component in \
  com.fightdeck.baseline/.MainActivity \
  com.fightdeck.coreswift/com.fightdeck.swiftcore.MainActivity \
  com.fightdeck.rust/.MainActivity \
  com.fightdeck.sdk.rn/com.fightdeck.baseline.MainActivity \
  com.fightdeck.sdk.skip/com.fightdeck.baseline.MainActivity; do
  adb shell am start -n "$component"
done
```

---

## Running tests

### Golden fixture cores (shared contract)

| Core | Command |
| --- | --- |
| Swift (`01-core-swift/sdks/core`) | `cd 01-core-swift/sdks/core && swift test` |
| Rust (`02-core-rust/sdks`) | `cd 02-core-rust/sdks && cargo test --workspace --release` |
| TypeScript RN (`03-sdk-rn/sdks/core`) | `cd 03-sdk-rn/sdks/core && npm test` |
| Skip Swift (`04-sdk-skip/sdks/core`) | `cd 04-sdk-skip/sdks/core && FIGHTDECK_FIXTURES_ROOT="$REPO/contract/fixtures" swift test` |

### iOS host unit / UI tests (`xcodebuild test`)

| Approach | Host test target | Command |
| --- | --- | --- |
| `00-native` | `FightDeckTests` | `cd 00-native/ios && xcodebuild test -scheme FightDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO` |
| `01-core-swift` | `FightDeckTests` | same pattern under `01-core-swift/ios` |
| `02-core-rust` | `FightDeckTests` | same pattern under `02-core-rust/ios` |
| `03-sdk-rn` | **`FightDeckUITests` only** (RN integration; no unit test target) | `cd 03-sdk-rn/ios && xcodebuild test -workspace FightDeck.xcworkspace -scheme FightDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO` |
| `04-sdk-skip` | **None** — no test target in `project.yml` | SDK fixtures: `04-sdk-skip/sdks/core` `swift test` (above) |

### Android host unit tests

Plain apps (`00-native`, `02-core-rust`):

```bash
cd "$REPO/00-native/android" && ./gradlew :app:testDebugUnitTest
# repeat for 02-core-rust/android
```

CI uses `:app:testReleaseUnitTest` (same tests, Release variant).

**`01-core-swift` has no JVM unit tests at all** — `app/src/test/` is empty, so
`:app:testDebugUnitTest` passes without asserting anything. Its fixture suite is an
**instrumented** test, because a JVM on macOS cannot load an Android `.so` and only a
device can run the Swift core:

```bash
adb push "$REPO/contract/fixtures" /data/local/tmp/fightdeck/fixtures
adb push "$REPO/dataset/events.json" /data/local/tmp/fightdeck/dataset/events.json
cd "$REPO/01-core-swift/android" && ./gradlew :app:connectedDebugAndroidTest
```

SDK apps — run per flavour or all three:

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export FIGHTDECK_LOCAL_SDK=1
cd "$REPO/03-sdk-rn/android"
./gradlew :app:testRuntimeDebugUnitTest :app:testDepositDebugUnitTest :app:testBothDebugUnitTest
cd "$REPO/04-sdk-skip/android"
./gradlew :app:testRuntimeDebugUnitTest :app:testDepositDebugUnitTest :app:testBothDebugUnitTest
```

### Instrumented / integration (optional)

```bash
# RN Android integration (requires booted emulator)
cd "$REPO/03-sdk-rn/android"
./gradlew :app:connectedBothDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.fightdeck.baseline.RNIntegrationTest
```

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Xcode project out of date / missing files | `project.yml` changed but `.xcodeproj` not regenerated | `cd <approach>/ios && xcodegen generate` |
| `Validate plug-in "skipstone" in package "skip"` | Skip SPM plugin not trusted in Xcode 26 | Add `-skipPackagePluginValidation -skipMacroValidation` to every `04-sdk-skip` `xcodebuild` invocation |
| RN iOS link errors / missing React | Built `.xcodeproj` instead of workspace | Use `-workspace FightDeck.xcworkspace` after `pod install` in `03-sdk-rn/ios` |
| `02-core-rust` iOS: missing `FightCore`/`FightSlip`/`FightEvents.xcframework`, or no generated Swift under `sdks/{core,slip,events}/Sources/` | Rust artifacts not built | `cd 02-core-rust/sdks && ./build-apple.sh` |
| App shows empty events / 404 images | Dataset env/path wrong | **iOS:** set `FIGHTDECK_DATASET_ROOT` or `SIMCTL_CHILD_FIGHTDECK_DATASET_ROOT`. **Android:** push to `/data/local/tmp/fightdeck/dataset` |
| Updated dataset but UI unchanged | `adb push` nested into `.../dataset/dataset/` | `adb shell rm -rf /data/local/tmp/fightdeck/dataset` then push again |
| Regenerated art, images still old | Coil / Kingfisher cache by URL | `adb shell pm clear <applicationId>`; iOS: `xcrun simctl uninstall booted <bundleId>` then reinstall |
| `03-sdk-rn` / `04-sdk-skip` Gradle: missing AARs | No release artifacts and `FIGHTDECK_LOCAL_SDK` unset | `export FIGHTDECK_LOCAL_SDK=1` or run `./tools/release-sdk-local.sh {rn\|skip}` |
| CocoaPods: pinned RN vendor missing | `FIGHTDECK_LOCAL_SDK` unset and no local release tree | `tools/release-sdk-local.sh rn` or build with `FIGHTDECK_LOCAL_SDK=1` |
| `01-core-swift` Gradle: missing `fightcore.aar` | The Android app has no Kotlin fallback; it needs the cross-compiled core | `cd 01-core-swift/sdks/core && swiftly run ./build-aar.sh +6.3.3` |
| `01-core-swift` Android: `compiled module was created by an older version of the compiler` | Xcode's Swift cannot read the Android SDK's Foundation | Prefix with `swiftly run … +6.3.3` so the open-source toolchain builds it |
| `01-core-swift` Android: `dlopen failed: library "libc++_shared.so" not found` | AAR packaged without the NDK's C++ runtime | Rebuild with the current `build-aar.sh`, which copies it out of the NDK sysroot |
| Gradle / AGP JDK errors | Wrong Java version | `export JAVA_HOME="$(/usr/libexec/java_home -v 17)"` |
| `am start` → `Error type 3 … does not exist` | `applicationId` differs from the Kotlin package | Use the full component from the table above, or `adb shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1` |
| `04-sdk-skip` iOS shows "Bet slip not included" | Target settings not applied, so `FIGHTDECK_BOTH` is undefined | Settings must be nested under `settings.base` in `project.yml` when the target also uses a template; then `xcodegen generate` |

---

## Size measurements (not the main goal)

Binary size and cold-start numbers are produced by the **`measure`** GitHub workflow (`.github/workflows/measure.yml`). It writes **`tools/out/receipt.md`** — that file is **gitignored** so a stale local run never lands in git.

Regenerate locally after building all apps:

```bash
# Per platform (see also tools/measure-ios.sh and tools/measure-android.sh)
./tools/measure-ios.sh 00-native 00-native/ios FightDeck
./tools/measure-android.sh 00-native 00-native/android app
python3 tools/render-receipt.py > tools/out/receipt.md
```

Presentation assets are maintained outside this repository.
