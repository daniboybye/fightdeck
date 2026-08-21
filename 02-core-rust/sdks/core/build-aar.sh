#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
OUT="$ROOT/out"
JNI="$OUT/jni"
GEN="$OUT/generated/kotlin"
mkdir -p "$OUT" "$JNI" "$GEN"

export PATH="${HOME}/.cargo/bin:${PATH}"

rustup target add aarch64-linux-android x86_64-linux-android >/dev/null 2>&1 || true

if ! command -v cargo-ndk >/dev/null 2>&1; then
  cargo install cargo-ndk --version 4.1.2 --locked
fi

cargo ndk -t arm64-v8a -t x86_64 -o "$JNI" build --release -p fightcore

LIB="$JNI/arm64-v8a/libfightcore.so"
cargo run --release -p fightcore --bin uniffi-bindgen --features uniffi-bindgen -- \
  generate \
  --library "$LIB" \
  --language kotlin \
  --no-format \
  --out-dir "$GEN"

AAR_ROOT="$OUT/aar-staging"
rm -rf "$AAR_ROOT"
mkdir -p "$AAR_ROOT/jni/arm64-v8a" "$AAR_ROOT/jni/x86_64"
mkdir -p "$AAR_ROOT/uniffi/fightcore"

cp "$JNI/arm64-v8a/libfightcore.so" "$AAR_ROOT/jni/arm64-v8a/"
cp "$JNI/x86_64/libfightcore.so" "$AAR_ROOT/jni/x86_64/"
cp "$GEN/uniffi/fightcore/fightcore.kt" "$AAR_ROOT/uniffi/fightcore/"

cat > "$AAR_ROOT/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fightdeck.fightcore">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

# Package Kotlin sources as resources for host Gradle module consumption.
jar cf "$AAR_ROOT/classes.jar" -C "$AAR_ROOT" uniffi

AAR="$OUT/fightcore.aar"
rm -f "$AAR"
(
  cd "$AAR_ROOT"
  zip -rq "$AAR" AndroidManifest.xml classes.jar jni
)

echo "Wrote $AAR"

ANDROID_GEN="$ROOT/../../android/app/src/main/java/uniffi/fightcore"
mkdir -p "$ANDROID_GEN"
cp "$GEN/uniffi/fightcore/fightcore.kt" "$ANDROID_GEN/"
