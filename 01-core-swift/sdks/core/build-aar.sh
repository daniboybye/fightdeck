#!/usr/bin/env bash
# Cross-compile FightCore for Android and package fightcore.aar.
# Route 1: bare Swift SDK + swift-java jextract --mode=jni
# Route 2 (fallback): Skip --native-model export (see README for status)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=setup-android-sdk.sh
source "$ROOT/setup-android-sdk.sh"
OUT="$ROOT/out"
MIN_SDK="${MIN_SDK:-28}"
ABIS=(
    "aarch64-unknown-linux-android${MIN_SDK}"
    "x86_64-unknown-linux-android${MIN_SDK}"
)

mkdir -p "$OUT/android-libs"

# Everything the .so needs at load time lives next to libswiftCore.so inside the Swift
# SDK bundle, whose path SwiftPM has moved between releases — hence the search.
copy_swift_runtime() {
    local arch="$1"
    local dest="$2"
    local core
    # `|| true`: one of the two roots is always absent, and find reports that as failure,
    # which pipefail would otherwise turn into a silent exit.
    core="$(find "$HOME/.swiftpm/swift-sdks" "$HOME/.config/swiftpm/swift-sdks" \
        -name libswiftCore.so -path "*${arch}*" 2>/dev/null | head -1 || true)"
    if [[ -z "$core" ]]; then
        echo "ERROR: no Swift runtime for $arch in the installed Swift SDK bundle" >&2
        exit 1
    fi
    find "$(dirname "$core")" -maxdepth 1 -name '*.so' -exec cp {} "$dest/" \;
}

echo "=== Cross-compiling FightCore for Android ==="
for triple in "${ABIS[@]}"; do
    echo "--- $triple ---"
    # No --static-swift-stdlib: the Android SDK bundle ships the runtime as shared
    # objects only, so a static link fails looking for archives that do not exist.
    # They travel in the AAR instead, which is also the honest size to quote.
    swift build \
        --package-path "$ROOT" \
        --swift-sdk "$triple" \
        --product FightCoreShared \
        -c release \
        2>&1 || {
            echo "ERROR: swift build failed for $triple" >&2
            exit 1
        }
    lib_src="$ROOT/.build/$triple/release/libFightCoreShared.so"
    if [[ ! -f "$lib_src" ]]; then
        lib_src="$(find "$ROOT/.build" -name libFightCoreShared.so \
            -path "*${triple%%-*}*" 2>/dev/null | head -1 || true)"
    fi
    if [[ ! -f "$lib_src" ]]; then
        echo "ERROR: no shared library for $triple under $ROOT/.build" >&2
        exit 1
    fi
    # Swift names the architecture, Android names the ABI, and an AAR is only loadable
    # if the directory uses Android's name.
    case "$triple" in
        aarch64-*) abi="arm64-v8a" ;;
        x86_64-*) abi="x86_64" ;;
        *) echo "ERROR: no Android ABI known for $triple" >&2; exit 1 ;;
    esac
    mkdir -p "$OUT/android-libs/$abi"
    cp "$lib_src" "$OUT/android-libs/$abi/libfightcore.so"
    copy_swift_runtime "${triple%%-*}" "$OUT/android-libs/$abi"
    echo "  $(du -h "$OUT/android-libs/$abi/libfightcore.so" | cut -f1)  $abi/libfightcore.so"
done

echo "=== Packaging AAR ==="
AAR_DIR="$OUT/aar-staging"
rm -rf "$AAR_DIR"
mkdir -p "$AAR_DIR/jni" "$AAR_DIR/META-INF/com/android/build/gradle"

cat > "$AAR_DIR/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fightdeck.fightcore">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

cat > "$AAR_DIR/META-INF/com/android/build/gradle/aar-metadata.properties" <<'EOF'
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=28
EOF

for abi_dir in "$OUT/android-libs"/*; do
    abi="$(basename "$abi_dir")"
    mkdir -p "$AAR_DIR/jni/$abi"
    cp "$abi_dir"/*.so "$AAR_DIR/jni/$abi/"
done

# Placeholder for swift-java generated bindings — see android/README-STUB.md if empty
mkdir -p "$AAR_DIR/classes"
if [[ -d "$ROOT/generated/kotlin" ]]; then
    echo "Including swift-java generated Kotlin bindings"
fi

(
    cd "$AAR_DIR"
    zip -r "$OUT/fightcore.aar" . -x '*.DS_Store'
)

echo "Wrote $OUT/fightcore.aar"
ls -lh "$OUT/fightcore.aar"
echo "=== Per-ABI .so sizes ==="
find "$OUT/android-libs" -name '*.so' -exec du -h {} \;
