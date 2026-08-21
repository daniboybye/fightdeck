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
    ./gradlew :betslip-sdk:assembleRelease --quiet
)

pack_feature_aar "$OUT" \
    "$ROOT/android/build/outputs/aar/betslip-sdk-release.aar" \
    "BetslipSDK"

ls -lh "$OUT/BetslipSDK.aar"
