#!/usr/bin/env bash
# Builds all three UniFFI namespaces into one Android shared library and AAR.
set -euo pipefail

SDKS="$(cd "$(dirname "$0")" && pwd)"
cd "$SDKS"
export PATH="${HOME}/.cargo/bin:${PATH}"

rustup target add aarch64-linux-android >/dev/null 2>&1 || true
if ! command -v cargo-ndk >/dev/null 2>&1; then
  CARGO_NDK_VERSION="$("$SDKS/../../tools/versions.py" rust.cargo_ndk)"
  cargo install cargo-ndk --version "$CARGO_NDK_VERSION" --locked
fi

OUT="$SDKS/android/fightdeck/out/android"
JNI="$OUT/jni"
rm -rf "$OUT"
mkdir -p "$JNI"

# `uniffi_reexport_scaffolding!` in the aggregate crate keeps all three namespaces'
# exported symbols and metadata in this one cdylib. arm64-v8a alone: every phone this demo runs
# on, and the emulator on Apple silicon. x86_64 was there for an emulator on an Intel machine,
# which nothing here uses.
cargo ndk -t arm64-v8a -o "$JNI" \
  build --release -p fightdeck-android

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
cargo run --release -p fightcore --bin uniffi-bindgen --features uniffi-bindgen -- \
  generate \
  --library "$JNI/arm64-v8a/libfightdeck.so" \
  --language kotlin \
  --no-format \
  --out-dir "$SCRATCH"

NAMESPACES=(fightcore fightslip fightevents)
for namespace in "${NAMESPACES[@]}"; do
  KT="$SCRATCH/uniffi/$namespace/$namespace.kt"
  [ -f "$KT" ] || {
    echo "build-android: aggregate library did not produce $namespace.kt" >&2
    exit 1
  }
done

STAGING="$OUT/aar-staging"
mkdir -p \
  "$STAGING/jni/arm64-v8a" \
  "$STAGING/uniffi"
cp "$JNI/arm64-v8a/libfightdeck.so" "$STAGING/jni/arm64-v8a/"
for namespace in "${NAMESPACES[@]}"; do
  mkdir -p "$STAGING/uniffi/$namespace"
  cp "$SCRATCH/uniffi/$namespace/$namespace.kt" "$STAGING/uniffi/$namespace/"
done

cat > "$STAGING/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fightdeck.rust">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

# The demo host compiles the generated sources copied below. Keep the same source snapshot
# in the AAR's classes.jar for parity with the previous packaging layout.
jar cf "$STAGING/classes.jar" -C "$STAGING" uniffi

AAR="$OUT/fightdeck.aar"
(
  cd "$STAGING"
  zip -rq "$AAR" AndroidManifest.xml classes.jar jni
)

ANDROID="$SDKS/../android/app/src/main"
rm -rf "$ANDROID/java/uniffi"
mkdir -p "$ANDROID/java/uniffi"
for namespace in "${NAMESPACES[@]}"; do
  mkdir -p "$ANDROID/java/uniffi/$namespace"
  cp "$SCRATCH/uniffi/$namespace/$namespace.kt" "$ANDROID/java/uniffi/$namespace/"
done

rm -rf "$ANDROID/jniLibs"
mkdir -p "$ANDROID/jniLibs/arm64-v8a"
cp "$JNI/arm64-v8a/libfightdeck.so" "$ANDROID/jniLibs/arm64-v8a/"

# Do not leave stale per-SDK Android artifacts around: release scripts must see one AAR.
rm -rf \
  "$SDKS/core/out/android" \
  "$SDKS/slip/out/android" \
  "$SDKS/events/out/android"

echo "  fightdeck.aar  ($(du -sh "$AAR" | cut -f1))"
