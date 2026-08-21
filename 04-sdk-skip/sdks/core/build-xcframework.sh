#!/usr/bin/env bash
# Package FightDeckCore for iOS distribution as an XCFramework zip.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
PRODUCT="FightDeckCore"
BINARY_MODULE="FightDeckCoreBinary"

mkdir -p "$OUT"
rm -rf "$OUT"/*.xcframework "$OUT"/*.xcframework.zip "$OUT"/ios-* 

build_dylib() {
    local sdk="$1"
    local triple="$2"
    local label="$3"
    local sdk_path
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

    FIGHTDECK_LOCAL_SDK=1 swift build \
        --package-path "$ROOT" \
        -c release \
        --triple "$triple" \
        --sdk "$sdk_path" \
        >/dev/null

    local src="$ROOT/.build/$triple/release/lib${PRODUCT}.dylib"
    local dest="$OUT/$label"
    mkdir -p "$dest"
    cp "$src" "$dest/lib${PRODUCT}.dylib"
    printf '%s\n' "$dest/lib${PRODUCT}.dylib"
}

IOS_LIB="$(build_dylib iphoneos arm64-apple-ios ios-arm64)"
SIM_ARM_LIB="$(build_dylib iphonesimulator arm64-apple-ios-simulator ios-sim-arm64)"
SIM_X64_LIB="$(build_dylib iphonesimulator x86_64-apple-ios-simulator ios-sim-x64)"

mkdir -p "$OUT/ios-simulator"
lipo -create "$SIM_ARM_LIB" "$SIM_X64_LIB" -output "$OUT/ios-simulator/lib${PRODUCT}.dylib"
SIM_LIB="$OUT/ios-simulator/lib${PRODUCT}.dylib"

xcodebuild -create-xcframework \
    -library "$IOS_LIB" \
    -library "$SIM_LIB" \
    -output "$OUT/${PRODUCT}.xcframework"

(
    cd "$OUT"
    zip -rq "${PRODUCT}.xcframework.zip" "${PRODUCT}.xcframework"
)

size="$(stat -f%z "$OUT/${PRODUCT}.xcframework.zip" 2>/dev/null || stat -c%s "$OUT/${PRODUCT}.xcframework.zip")"
if (( size < 50000 )); then
    echo "error: ${PRODUCT}.xcframework.zip is only ${size} bytes" >&2
    exit 1
fi

echo "Wrote $OUT/${PRODUCT}.xcframework.zip ($size bytes)"
ls -lh "$OUT/${PRODUCT}.xcframework.zip"
du -sh "$OUT/${PRODUCT}.xcframework"
