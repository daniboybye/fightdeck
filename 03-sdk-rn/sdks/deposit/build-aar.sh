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
    ./gradlew :deposit-sdk:assembleRelease --quiet
)

pack_feature_aar "$OUT" \
    "$ROOT/android/build/outputs/aar/deposit-sdk-release.aar" \
    "DepositSDK"

ls -lh "$OUT/DepositSDK.aar"
