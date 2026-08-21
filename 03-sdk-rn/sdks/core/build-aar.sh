#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
ANDROID_HOST="$ROOT/../../android"
SCRIPTS="$ROOT/../_scripts"

# shellcheck source=../_scripts/android-aar-pack.sh
source "$SCRIPTS/android-aar-pack.sh"

echo "Building Android runtime AAR via Gradle…"
if [[ ! -x "$ANDROID_HOST/gradlew" ]]; then
    echo "error: Android host gradlew missing at $ANDROID_HOST" >&2
    exit 1
fi

echo "Bundling JS for Android…"
mkdir -p "$ROOT/android/build"
if ! command -v npx >/dev/null 2>&1; then
    echo "error: npx not found" >&2
    exit 1
fi
(cd "$ROOT" && npm install --silent)
(cd "$ROOT" && npx react-native bundle \
    --platform android \
    --dev false \
    --entry-file src/runtime/index.js \
    --bundle-output android/build/index.android.bundle \
    --assets-dest android/build)

(
    cd "$ANDROID_HOST"
    ./gradlew :fightdeck-rn-runtime:assembleRelease --quiet
)

GRADLE_AAR="$ROOT/android/runtime/build/outputs/aar/fightdeck-rn-runtime-release.aar"
pack_rn_runtime_aars "$OUT" "$GRADLE_AAR" "$ROOT/android/build/index.android.bundle"

echo "Wrote runtime AARs in $OUT:"
ls -lh "$OUT"/*.aar
