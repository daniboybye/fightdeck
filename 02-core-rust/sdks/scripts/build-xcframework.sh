#!/usr/bin/env bash
# Builds one Rust crate into one SPM package: an xcframework carrying the staticlib, plus the
# UniFFI bindings written into the package's Sources.
#
# Each SDK ships separately, as its own SwiftPM package with its own binary target. The feature
# crates statically link fightcore; the app-level linker keeps a single copy, which is why three
# packages do not cost three copies of the kernel.
#
# usage: build-xcframework.sh <crate> <uniffi-namespace> <FrameworkName> <package-dir> [<import>...]
set -euo pipefail

CRATE="${1:?usage: build-xcframework.sh <crate> <namespace> <FrameworkName> <package-dir> [<import>...]}"
NAMESPACE="${2:?missing uniffi namespace}"
FRAMEWORK="${3:?missing framework name}"
PKG="$(cd "${4:?missing package dir}" && pwd)"
# Swift modules whose UniFFI types this SDK's bindings use, e.g. FightCore for BoutIndex.
shift 4
IMPORTS=("$@")

SDKS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SDKS"
export PATH="${HOME}/.cargo/bin:${PATH}"

DEVICE=aarch64-apple-ios
SIM_ARM=aarch64-apple-ios-sim
SIM_X86=x86_64-apple-ios

# FIGHTDECK_SDK_CONFIGURATION=debug builds Cargo's dev profile; FIGHTDECK_SDK_ARCHS=arm64 builds
# the device slice alone, for a host built for a phone. The defaults are what ships.
PROFILE=release
PROFILE_FLAG=(--release)
if [[ "${FIGHTDECK_SDK_CONFIGURATION:-release}" == "debug" ]]; then
  PROFILE=debug
  PROFILE_FLAG=()
fi
TARGETS=("$DEVICE")
if [[ "${FIGHTDECK_SDK_ARCHS:-all}" != "arm64" ]]; then
  TARGETS+=("$SIM_ARM" "$SIM_X86")
fi

for target in "${TARGETS[@]}"; do
  rustup target add "$target" >/dev/null 2>&1 || true
  cargo build ${PROFILE_FLAG[@]+"${PROFILE_FLAG[@]}"} -p "$CRATE" --target "$target"
done

OUT="$PKG/out"
SWIFT_SRC="$PKG/Sources/$FRAMEWORK"
FFI_INCLUDE="$PKG/Sources/${NAMESPACE}FFI/include"
# Targeted so unrelated package artifacts in `out/` survive an Apple rebuild.
rm -rf "$OUT/$FRAMEWORK.xcframework" "$OUT/$FRAMEWORK.xcframework.zip" "$SWIFT_SRC" "$FFI_INCLUDE"
mkdir -p "$OUT" "$SWIFT_SRC" "$FFI_INCLUDE"

# Library mode also reports the metadata of statically linked dependencies, so generate into
# a scratch directory and keep only this SDK's module.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
cargo run --release -p fightcore --bin uniffi-bindgen --features uniffi-bindgen -- \
  generate \
  --library "$SDKS/target/$DEVICE/$PROFILE/lib${CRATE}.a" \
  --language swift \
  --out-dir "$SCRATCH"

for file in "$NAMESPACE.swift" "${NAMESPACE}FFI.h"; do
  [ -f "$SCRATCH/$file" ] || { echo "build-xcframework: $NAMESPACE did not produce $file" >&2; exit 1; }
done

# UniFFI's Swift generator calls an external type's public converter by name but never imports
# the module that declares it; Kotlin gets the import, Swift has to be told. The line goes
# straight after `import Foundation`, where UniFFI puts its own imports.
cp "$SCRATCH/$NAMESPACE.swift" "$SWIFT_SRC/$NAMESPACE.swift"
for module in ${IMPORTS[@]+"${IMPORTS[@]}"}; do
  perl -pi -e "s/^import Foundation\$/import Foundation\nimport $module/" "$SWIFT_SRC/$NAMESPACE.swift"
done
cp "$SCRATCH/${NAMESPACE}FFI.h" "$FFI_INCLUDE/${NAMESPACE}FFI.h"

# UniFFI's own modulemap carries `use` declarations for Darwin submodules that SwiftPM does not
# put on the include path. SwiftPM only needs the umbrella, and it has to be named
# module.modulemap for a C target to pick it up.
cat > "$FFI_INCLUDE/module.modulemap" <<EOF
module ${NAMESPACE}FFI {
    header "${NAMESPACE}FFI.h"
    export *
}
EOF

# One simulator slice covering both architectures, or a Release build that is not restricted
# to the active arch fails to link on the x86_64 simulator.
LIBRARIES=(-library "$SDKS/target/$DEVICE/$PROFILE/lib${CRATE}.a")
if [[ " ${TARGETS[*]} " == *" $SIM_ARM "* ]]; then
  FAT_SIM="$SCRATCH/lib${CRATE}-sim.a"
  lipo -create \
    "$SDKS/target/$SIM_ARM/$PROFILE/lib${CRATE}.a" \
    "$SDKS/target/$SIM_X86/$PROFILE/lib${CRATE}.a" \
    -output "$FAT_SIM"
  LIBRARIES+=(-library "$FAT_SIM")
fi

# No `-headers`: the C header ships as a SwiftPM target above, where each package gets its own
# include directory. Folding it into the xcframework would make Xcode copy all three module maps
# into one include/, and they collide on the filename.
xcodebuild -create-xcframework \
  "${LIBRARIES[@]}" \
  -output "$OUT/$FRAMEWORK.xcframework" >/dev/null

# A binary target's zip has to hold the xcframework and nothing else.
(
  cd "$OUT"
  zip -rq "$FRAMEWORK.xcframework.zip" "$FRAMEWORK.xcframework"
)

SIZE=$(du -sh "$OUT/$FRAMEWORK.xcframework" | cut -f1)
echo "  $FRAMEWORK.xcframework  ($SIZE)  namespace=$NAMESPACE  package=$(basename "$PKG")"
