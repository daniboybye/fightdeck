#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
PRODUCT="FightDeckRNRuntime"
BINARY_MODULE="FightDeckRNRuntimeBinary"
SRC="$ROOT/ios/Sources/FightDeckRNRuntime"
BUILD="$ROOT/.build/xcframework"
HEADERS="$BUILD/headers"
SCRIPTS="$ROOT/../_scripts"

# shellcheck source=../_scripts/ios-rn-bundle.sh
source "$SCRIPTS/ios-rn-bundle.sh"

rm -rf "$OUT" "$BUILD"
mkdir -p "$OUT" "$BUILD" "$HEADERS" "$ROOT/ios/Resources"

"$ROOT/build-jsbundle.sh"

PODS_ROOT="$ROOT/../../ios/Pods"
if [[ ! -d "$PODS_ROOT/React-Core-prebuilt" ]]; then
    echo "Installing CocoaPods (required for RN xcframeworks)…"
    # The Podfile's other branch consumes an already released vendor drop — which is what this
    # script is about to produce. Resolving from source is the only branch that can bootstrap.
    (cd "$ROOT/../../ios" && FIGHTDECK_LOCAL_SDK=1 pod install)
    PODS_ROOT="$ROOT/../../ios/Pods"
fi

mkdir -p "$ROOT/ios/BuildPackage/Sources/FightDeckRNRuntime"
rsync -a "$SRC/" "$ROOT/ios/BuildPackage/Sources/FightDeckRNRuntime/" \
    --exclude '*.mm' --exclude 'include'

cat > "$ROOT/ios/BuildPackage/Package.swift" <<'PKG'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FightDeckRNRuntime",
    platforms: [.iOS("26.0")],
    products: [.library(name: "FightDeckRNRuntimeBinary", targets: ["FightDeckRNRuntimeBinary"])],
    targets: [.target(
        name: "FightDeckRNRuntimeBinary",
        swiftSettings: [
            .swiftLanguageMode(.v6),
            .unsafeFlags(["-strict-concurrency=minimal"]),
        ]
    )]
)
PKG

build_slice() {
    local sdk="$1"
    local triple="$2"
    local label="$3"
    local sdk_path
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

    FIGHTDECK_LOCAL_SDK=1 swift build \
        --package-path "$ROOT/ios/BuildPackage" \
        -c release \
        --triple "$triple" \
        --sdk "$sdk_path" >&2

    local dest="$BUILD/$label"
    mkdir -p "$dest"
    shopt -s nullglob
    local objects=("$ROOT/ios/BuildPackage/.build/$triple/release/FightDeckRNRuntimeBinary.build"/*.o)
    if ((${#objects[@]} == 0)); then
        echo "error: no object files for $triple" >&2
        exit 1
    fi
  libtool -static -o "$dest/lib${BINARY_MODULE}.a" "${objects[@]}"
  printf '%s\n' "$dest/lib${BINARY_MODULE}.a"
}

IOS_LIB="$(build_slice iphoneos arm64-apple-ios ios-arm64)"
SIM_ARM_LIB="$(build_slice iphonesimulator arm64-apple-ios-simulator ios-sim-arm64)"
SIM_X64_LIB="$(build_slice iphonesimulator x86_64-apple-ios-simulator ios-sim-x64)"

mkdir -p "$BUILD/ios-simulator"
if [[ -f "$SIM_ARM_LIB" && -f "$SIM_X64_LIB" ]]; then
    lipo -create "$SIM_ARM_LIB" "$SIM_X64_LIB" -output "$BUILD/ios-simulator/lib${BINARY_MODULE}.a" 2>/dev/null \
        || cp "$SIM_ARM_LIB" "$BUILD/ios-simulator/lib${BINARY_MODULE}.a"
else
    cp "$IOS_LIB" "$BUILD/ios-simulator/lib${BINARY_MODULE}.a"
fi
SIM_LIB="$BUILD/ios-simulator/lib${BINARY_MODULE}.a"

mkdir -p "$HEADERS"
cp -R "$SRC/." "$HEADERS/" 2>/dev/null || true

xcodebuild -create-xcframework \
    -library "$IOS_LIB" -headers "$HEADERS" \
    -library "$SIM_LIB" -headers "$HEADERS" \
    -output "$BUILD/${PRODUCT}.xcframework"

bundle_rn_ios_distribution "$OUT" "$PRODUCT" "$BUILD/${PRODUCT}.xcframework" \
    "$ROOT/ios/Resources/fightdeck.hbc" "$PODS_ROOT"

du -sh "$OUT/${PRODUCT}.xcframework" "$OUT/${PRODUCT}.xcframework.zip" 2>/dev/null || true
