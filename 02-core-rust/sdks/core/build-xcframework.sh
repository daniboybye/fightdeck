#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
OUT="$ROOT/out"
GEN="$OUT/generated/swift"
mkdir -p "$OUT" "$GEN"

export PATH="${HOME}/.cargo/bin:${PATH}"

TARGETS=(
  aarch64-apple-ios
  aarch64-apple-ios-sim
  x86_64-apple-ios
)

for target in "${TARGETS[@]}"; do
  rustup target add "$target" >/dev/null 2>&1 || true
  cargo build --release -p fightcore --target "$target"
done

LIB_IOS="$ROOT/target/aarch64-apple-ios/release/libfightcore.a"
cargo run --release -p fightcore --bin uniffi-bindgen --features uniffi-bindgen -- \
  generate \
  --library "$LIB_IOS" \
  --language swift \
  --out-dir "$GEN"

chmod +x "$ROOT/patch-swift-bindings.sh"
"$ROOT/patch-swift-bindings.sh" "$GEN/fightcore.swift"

HEADER="$GEN/fightcoreFFI.h"
MODULEMAP="$GEN/fightcore.modulemap"
XCFW="$OUT/FightCore.xcframework"
rm -rf "$XCFW"

xcodebuild -create-xcframework \
  -library "$ROOT/target/aarch64-apple-ios/release/libfightcore.a" -headers "$GEN" \
  -library "$ROOT/target/aarch64-apple-ios-sim/release/libfightcore.a" -headers "$GEN" \
  -output "$XCFW"

cp -R "$GEN" "$OUT/swift"

(
  cd "$OUT"
  rm -f FightCore.xcframework.zip
  zip -rq FightCore.xcframework.zip FightCore.xcframework swift
)

echo "Wrote $OUT/FightCore.xcframework.zip"

IOS_GEN="$ROOT/../../ios/FightDeck/Generated"
mkdir -p "$IOS_GEN"
cp "$GEN/fightcore.swift" "$GEN/fightcoreFFI.h" "$GEN/fightcoreFFI.modulemap" "$IOS_GEN/"
