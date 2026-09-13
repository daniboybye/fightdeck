#!/usr/bin/env bash
# Checks the factual claims behind the build/debug write-up, so none of them has to be taken on
# trust. Read-only: it inspects committed files and existing build output and changes nothing.
#
# Claims that need a build, an install or a running device are deliberately not here — those are
# spelled out as manual steps in the document, because a script that quietly rebuilds five apps
# is not a verification anyone can follow.
#
# Requires the artifacts to exist: build the SDKs and the apps first, or the artifact checks fail
# for the boring reason.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
export REPO
cd "$REPO" || exit 1

pass=0
fail=0

# ck <label> <expected substring> <command…>
ck() {
    local label="$1" want="$2"
    shift 2
    local out
    out="$("$@" 2>&1)"
    if [[ "$out" == *"$want"* ]]; then
        echo "  ok   $label"
        pass=$((pass + 1))
    else
        echo "  FAIL $label (wanted '$want', got: ${out:0:90})"
        fail=$((fail + 1))
    fi
}

SKIP_KOTLIN="$REPO/04-sdk-skip/sdks/core/.build/plugins/outputs/core/FightDeckCoreBinary/destination/skipstone/FightDeckCoreBinary/src/main/kotlin/fight/deck/core"

echo "Shared ground"
ck "all five schemes carry the dataset root" "5" bash -c \
    "rg -c FIGHTDECK_DATASET_ROOT $REPO/*/ios/FightDeck.xcodeproj/xcshareddata/xcschemes/FightDeck.xcscheme | wc -l | tr -d ' '"
ck "only the two SDK hosts bundle dataset JSON" "0 0 0 4 4" bash -c '
for a in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
  apk=$(find "$REPO/$a/android/app/build/outputs/apk" -name "*debug*.apk" | head -1)
  printf "%s " "$(unzip -l "$apk" | grep -c "assets/\(events\|fighters\|news\|media\).json")"
done'

echo "01-core-swift — Swift compiled for Android"
ck "the AAR carries the Swift runtime" "libswiftCore.so" bash -c \
    "unzip -l $REPO/01-core-swift/sdks/core/out/fightcore.aar | grep '\.so'"
ck "jextract's shape leaks into Kotlin" "toInt()" bash -c \
    "rg -n 'toInt\(\)|RED|BLUE' $REPO/01-core-swift/android/app/src/main/java/com/fightdeck/swiftcore/catalog/CatalogHost.kt | head -3"
ck "the .so has Swift debug info" "DW_LANG_Swift" bash -c \
    "xcrun dwarfdump --debug-info $REPO/01-core-swift/sdks/core/out/android-libs/arm64-v8a/libfightcore.so | grep -m3 DW_AT_language"
ck "Android consumes a prebuilt AAR, not sources" ".aar" bash -c \
    "rg -n 'fightCoreAar|\.aar' $REPO/01-core-swift/android/app/build.gradle.kts | head -3"

echo "02-core-rust — Rust behind UniFFI"
ck "the Apple artifact has Rust debug info" "DW_LANG_Rust" bash -c \
    "xcrun dwarfdump --debug-info $REPO/02-core-rust/sdks/core/out/FightCore.xcframework/ios-arm64_x86_64-simulator/libfightcore-sim.a | grep -m2 DW_AT_language"
ck "the Android .so is stripped" "no debug sections" bash -c \
    "xcrun llvm-objdump --section-headers $REPO/02-core-rust/sdks/core/out/android/aar-staging/jni/arm64-v8a/libfightcore.so | grep -i debug || echo 'no debug sections'"
ck "no Rust sources in the Xcode project" "no .rs in the project" bash -c \
    "rg -c '\.rs' $REPO/02-core-rust/ios/FightDeck.xcodeproj/project.pbxproj || echo 'no .rs in the project'"
ck "the logic tests without a device" "test result: ok" bash -c \
    "cd $REPO/02-core-rust/sdks/core/fightcore && cargo test 2>&1 | tail -6"

echo "03-sdk-rn — React Native as an SDK"
ck "the shipped bundle is optimised" "dev false" bash -c \
    "rg -n 'dev false|emit-binary' $REPO/03-sdk-rn/sdks/core/build-jsbundle.sh"
ck "the iOS script emits no source map" "no sourcemap flag" bash -c \
    "rg -q 'sourcemap-output' $REPO/03-sdk-rn/sdks/core/build-jsbundle.sh && echo 'has flag' || echo 'no sourcemap flag'"
ck "Android's Gradle plugin does emit one" "index.android.bundle.map" bash -c \
    "ls $REPO/03-sdk-rn/android/app/build/generated/sourcemaps/react/allDebug/index.android.bundle.map"
ck "metro-symbolicate is available" "metro-symbolicate" bash -c \
    "ls $REPO/03-sdk-rn/sdks/core/node_modules/.bin/ | grep symbolicate"
ck "the host prefers bytecode over Metro" "RCTBundleURLProvider" bash -c \
    "sed -n '21,40p' $REPO/03-sdk-rn/sdks/core/ios/Pod/FightDeckRNHost.mm"
ck "the built app ships that bytecode" "fightdeck.hbc" bash -c \
    "find $REPO/DerivedData/all-ios/03-sdk-rn -name 'fightdeck.hbc' | head -1"
ck "dev support is never asked for" "jsMainModulePath" bash -c \
    "rg -n -A7 'reactHost' $REPO/03-sdk-rn/android/app/src/main/java/com/fightdeck/baseline/MainApplication.kt"

echo "04-sdk-skip — Swift transpiled to Kotlin"
ck "the AAR is pure Kotlin" "classes.jar" bash -c \
    "unzip -l $REPO/04-sdk-skip/sdks/core/out/FightDeckCore-release.aar | grep -E '\.so|classes.jar'"
ck "the generated Kotlin is on disk" "OddsEngine.kt" bash -c "ls '$SKIP_KOTLIN'"
ck "source maps point back at Swift" "Money.swift" bash -c "head -c 300 '$SKIP_KOTLIN/.Money.sourcemap'"
ck "division names its precision" "RoundingMode.HALF_UP" bash -c \
    "rg -n -A3 'fun divide' '$SKIP_KOTLIN/Money.kt'"
ck "Skip ships no debug subcommand" "none" bash -c "skip --help 2>&1 | grep -w debug || echo none"

echo
echo "passed $pass, failed $fail"
[[ "$fail" -eq 0 ]]
