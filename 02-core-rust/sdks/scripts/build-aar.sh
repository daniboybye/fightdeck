#!/usr/bin/env bash
# Builds one Rust crate into one AAR, mirroring build-xcframework.sh.
#
# usage: build-aar.sh <crate> <uniffi-namespace> <package-dir>
set -euo pipefail

CRATE="${1:?usage: build-aar.sh <crate> <namespace> <package-dir>}"
NAMESPACE="${2:?missing uniffi namespace}"
PKG="$(cd "${3:?missing package dir}" && pwd)"

SDKS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SDKS"
export PATH="${HOME}/.cargo/bin:${PATH}"

rustup target add aarch64-linux-android x86_64-linux-android >/dev/null 2>&1 || true
if ! command -v cargo-ndk >/dev/null 2>&1; then
  cargo install cargo-ndk --version 4.1.2 --locked
fi

# Alongside the xcframework, so both artifacts for an SDK live in the package that ships them.
OUT="$PKG/out/android"
JNI="$OUT/jni"
rm -rf "$OUT"
mkdir -p "$JNI"

cargo ndk -t arm64-v8a -t x86_64 -o "$JNI" build --release -p "$CRATE"

# Library mode also reports statically linked dependencies; keep only this SDK's module.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
cargo run --release -p fightcore --bin uniffi-bindgen --features uniffi-bindgen -- \
  generate \
  --library "$JNI/arm64-v8a/lib${CRATE}.so" \
  --language kotlin \
  --no-format \
  --out-dir "$SCRATCH"

KT="$SCRATCH/uniffi/$NAMESPACE/$NAMESPACE.kt"
[ -f "$KT" ] || { echo "build-aar: $NAMESPACE did not produce $NAMESPACE.kt" >&2; exit 1; }

STAGING="$OUT/aar-staging"
mkdir -p "$STAGING/jni/arm64-v8a" "$STAGING/jni/x86_64" "$STAGING/uniffi/$NAMESPACE"
cp "$JNI/arm64-v8a/lib${CRATE}.so" "$STAGING/jni/arm64-v8a/"
cp "$JNI/x86_64/lib${CRATE}.so" "$STAGING/jni/x86_64/"
cp "$KT" "$STAGING/uniffi/$NAMESPACE/"

cat > "$STAGING/AndroidManifest.xml" <<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fightdeck.$NAMESPACE">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

# Kotlin sources ship as resources so the host Gradle module compiles them directly.
jar cf "$STAGING/classes.jar" -C "$STAGING" uniffi

AAR="$OUT/$NAMESPACE.aar"
(
  cd "$STAGING"
  zip -rq "$AAR" AndroidManifest.xml classes.jar jni
)

ANDROID="$SDKS/../android/app/src/main"
mkdir -p "$ANDROID/java/uniffi/$NAMESPACE" "$ANDROID/jniLibs/arm64-v8a" "$ANDROID/jniLibs/x86_64"
cp "$KT" "$ANDROID/java/uniffi/$NAMESPACE/"
cp "$JNI/arm64-v8a/lib${CRATE}.so" "$ANDROID/jniLibs/arm64-v8a/"
cp "$JNI/x86_64/lib${CRATE}.so" "$ANDROID/jniLibs/x86_64/"

echo "  $NAMESPACE.aar  ($(du -sh "$AAR" | cut -f1))"
