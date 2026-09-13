#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
PRODUCT="FighterSDK"
BINARY_MODULE="FighterSDKBinary"
SRC="$ROOT/ios/Sources/FighterSDK"
BUILD="$ROOT/.build/xcframework"

rm -rf "$OUT" "$BUILD"
mkdir -p "$OUT" "$BUILD/Sources/FighterSDK"
rsync -a "$SRC/" "$BUILD/Sources/FighterSDK/"

cat > "$BUILD/Package.swift" <<PKG
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FighterSDK",
    platforms: [.iOS("26.0")],
    products: [.library(name: "FighterSDKBinary", targets: ["FighterSDKBinary"])],
    dependencies: [
        .package(path: "../../../core")
    ],
    targets: [
        .target(
            name: "FighterSDKBinary",
            dependencies: [
                .product(name: "FightDeckRNRuntime", package: "core")
            ]
        )
    ]
)
PKG

build_slice() {
  local sdk="$1"
  local triple="$2"
  local label="$3"
  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  FIGHTDECK_LOCAL_SDK=1 swift build \
    --package-path "$BUILD" \
    -c release \
    --triple "$triple" \
    --sdk "$sdk_path" >&2
  local dest="$BUILD/$label"
  mkdir -p "$dest"
  shopt -s nullglob
  local objects=("$BUILD/.build/$triple/release/FighterSDKBinary.build"/*.o)
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
lipo -create "$SIM_ARM_LIB" "$SIM_X64_LIB" -output "$BUILD/ios-simulator/lib${BINARY_MODULE}.a"
SIM_LIB="$BUILD/ios-simulator/lib${BINARY_MODULE}.a"

xcodebuild -create-xcframework \
  -library "$IOS_LIB" -headers "$SRC" \
  -library "$SIM_LIB" -headers "$SRC" \
  -output "$OUT/${PRODUCT}.xcframework"

(
  cd "$OUT"
  zip -rq "${PRODUCT}.xcframework.zip" "${PRODUCT}.xcframework"
)

size="$(stat -f%z "$OUT/${PRODUCT}.xcframework.zip" 2>/dev/null || stat -c%s "$OUT/${PRODUCT}.xcframework.zip")"
if (( size < 10000 )); then
  echo "error: ${PRODUCT}.xcframework.zip is only ${size} bytes" >&2
  exit 1
fi

echo "Wrote $OUT/${PRODUCT}.xcframework.zip ($size bytes)"
ls -lh "$OUT/${PRODUCT}.xcframework.zip"
