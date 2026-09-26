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

# Only for the Gradle plugin and codegen under node_modules. The JavaScript itself is not
# packed here: every app flavour bundles its own entry into assets/index.android.bundle,
# and an app asset replaces a library asset of the same name, so a copy in this AAR was
# 0.9 MB that no build ever loaded.
(cd "$ROOT" && npm install --silent)

(
    cd "$ANDROID_HOST"
    ./gradlew :fightdeck-rn-runtime:assemble${SDK_VARIANT_TASK} --quiet
)

GRADLE_AAR="$ROOT/android/runtime/build/outputs/aar/fightdeck-rn-runtime-${SDK_VARIANT}.aar"
pack_rn_runtime_aars "$OUT" "$GRADLE_AAR"

echo "Wrote runtime AARs in $OUT:"
ls -lh "$OUT"/*.aar
