#!/usr/bin/env bash
# Cross-compile FightCore for Android and package fightcore.aar.
# Route 1: bare Swift SDK + swift-java jextract --mode=jni
# Route 2 (fallback): Skip --native-model export (see README for status)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=setup-android-sdk.sh
source "$ROOT/setup-android-sdk.sh"
OUT="$ROOT/out"
ANDROID_SDK_NAME="swift-6.3.3-RELEASE_android"
MIN_SDK="${MIN_SDK:-28}"
ABIS=(
    "aarch64-unknown-linux-android${MIN_SDK}"
    "x86_64-unknown-linux-android${MIN_SDK}"
)

mkdir -p "$OUT/android-libs"

echo "=== Cross-compiling FightCore for Android ==="
for triple in "${ABIS[@]}"; do
    echo "--- $triple ---"
    swift build \
        --package-path "$ROOT" \
        --swift-sdk "$triple" \
        --static-swift-stdlib \
        -c release \
        -Xlinker -shared \
        2>&1 || {
            echo "ERROR: swift build failed for $triple" >&2
            exit 1
        }
    lib_src="$ROOT/.build/$triple/release/libFightCore.so"
    if [[ ! -f "$lib_src" ]]; then
        lib_src="$ROOT/.build/release/libFightCore.so"
    fi
    abi="$(echo "$triple" | cut -d- -f1)"
    mkdir -p "$OUT/android-libs/$abi"
    cp "$lib_src" "$OUT/android-libs/$abi/libfightcore.so"
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
    cp "$abi_dir/libfightcore.so" "$AAR_DIR/jni/$abi/"
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
