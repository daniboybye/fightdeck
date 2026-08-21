#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
PRODUCT="FightCore"

rm -rf "$OUT"
mkdir -p "$OUT"

build_static_lib() {
    local sdk="$1"
    local triple="$2"
    local label="$3"
    local sdk_path
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

    swift build \
        --package-path "$ROOT" \
        -c release \
        --triple "$triple" \
        --sdk "$sdk_path" \
        -Xswiftc -enable-library-evolution \
        >/dev/null

    local obj_dir="$ROOT/.build/$triple/release/${PRODUCT}.build"
    local dest="$OUT/$label"
    mkdir -p "$dest"
    libtool -static -o "$dest/lib${PRODUCT}.a" "$obj_dir"/*.o
    printf '%s\n' "$dest/lib${PRODUCT}.a"
}

IOS_LIB="$(build_static_lib iphoneos arm64-apple-ios ios-arm64)"
SIM_ARM_LIB="$(build_static_lib iphonesimulator arm64-apple-ios-simulator ios-sim-arm64)"
SIM_X64_LIB="$(build_static_lib iphonesimulator x86_64-apple-ios-simulator ios-sim-x64)"

mkdir -p "$OUT/ios-simulator"
lipo -create "$SIM_ARM_LIB" "$SIM_X64_LIB" -output "$OUT/ios-simulator/lib${PRODUCT}.a"
SIM_LIB="$OUT/ios-simulator/lib${PRODUCT}.a"

xcodebuild -create-xcframework \
    -library "$IOS_LIB" -headers "$ROOT/Sources/${PRODUCT}" \
    -library "$SIM_LIB" -headers "$ROOT/Sources/${PRODUCT}" \
    -output "$OUT/${PRODUCT}.xcframework"

(
    cd "$OUT"
    zip -rq "${PRODUCT}.xcframework.zip" "${PRODUCT}.xcframework"
)

echo "Wrote $OUT/${PRODUCT}.xcframework.zip"
ls -lh "$OUT/${PRODUCT}.xcframework.zip"
du -sh "$OUT/${PRODUCT}.xcframework"
