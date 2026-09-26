#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
ANDROID_HOST="$ROOT/../../android"
SCRIPTS="$ROOT/../_scripts"

# shellcheck source=../_scripts/android-aar-pack.sh
source "$SCRIPTS/android-aar-pack.sh"

(
    cd "$ANDROID_HOST"
    ./gradlew :fighter-sdk:assemble${SDK_VARIANT_TASK} --quiet
)

pack_feature_aar "$OUT" \
    "$ROOT/android/build/outputs/aar/fighter-sdk-${SDK_VARIANT}.aar" \
    "FighterSDK"

ls -lh "$OUT/FighterSDK.aar"
