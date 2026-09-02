#!/usr/bin/env bash
#
# What does the *next* screen cost, once the first one has paid for the runtime?
#
#   ./tools/measure-second-feature.sh                    # both SDKs, both platforms
#   ./tools/measure-second-feature.sh 03-sdk-rn          # one approach
#   FIGHTDECK_PLATFORM=android ./tools/measure-second-feature.sh 03-sdk-rn
#
# Builds each UI-bearing SDK's host three times — runtime alone, runtime plus deposit,
# runtime plus deposit plus bet slip — leaving one measurement file per stage. Only the two
# SDK approaches have anything to measure: the headless cores ship no UI, so a second
# feature there is ordinary application code.
#
# The stages are selected differently on each platform, which is itself part of the
# comparison. Skip's iOS host has a scheme per stage. Both Android hosts use product
# flavours. React Native's iOS host has neither: the feature set is decided once when the
# SDK's JS bundle is built and again when CocoaPods resolves, so both steps run per stage
# and the Podfile refuses a mismatch between them.
#
# FIGHTDECK_PLATFORM exists so CI can put each half on the cheapest runner that can build
# it. tools/render-receipt.py reads the per-stage files, so the halves never have to meet.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"
cd "$REPO_ROOT"

export FIGHTDECK_LOCAL_SDK=1

PLATFORM="${FIGHTDECK_PLATFORM:-both}"
case "$PLATFORM" in
    ios|android|both) ;;
    *)
        echo "error: FIGHTDECK_PLATFORM must be ios, android or both (got '$PLATFORM')" >&2
        exit 1
        ;;
esac

if [[ $# -gt 0 ]]; then
    APPROACHES=("$@")
else
    APPROACHES=(03-sdk-rn 04-sdk-skip)
fi

STAGES=(runtime deposit both)

# Leaving the React Native checkout on a partial feature set would silently shrink the next
# ordinary build, so restore the full one whatever happens.
restore_rn() {
    echo "==> Restoring React Native host to the full feature set"
    FIGHTDECK_FEATURES=both ./03-sdk-rn/sdks/core/build-jsbundle.sh >/dev/null 2>&1 || true
    (cd 03-sdk-rn/ios && FIGHTDECK_FEATURES=both pod install >/dev/null 2>&1) || true
}

measure_ios() {
    local approach="$1" stage="$2" tag="$3"
    case "$approach" in
        03-sdk-rn)
            FIGHTDECK_FEATURES="$stage" ./03-sdk-rn/sdks/core/build-jsbundle.sh >/dev/null
            (cd 03-sdk-rn/ios && FIGHTDECK_FEATURES="$stage" pod install >/dev/null)
            ./tools/measure-ios.sh "$tag" "03-sdk-rn/ios" "FightDeck" >/dev/null
            ;;
        04-sdk-skip)
            local scheme
            case "$stage" in
                runtime) scheme="FightDeckRuntime" ;;
                deposit) scheme="FightDeckSkipDeposit" ;;
                both)    scheme="FightDeck" ;;
            esac
            ./tools/measure-ios.sh "$tag" "04-sdk-skip/ios" "$scheme" >/dev/null
            ;;
    esac
}

for approach in "${APPROACHES[@]}"; do
    if [[ "$approach" == "03-sdk-rn" && "$PLATFORM" != "android" ]]; then
        trap restore_rn EXIT
    fi

    for stage in "${STAGES[@]}"; do
        if [[ "$PLATFORM" != "android" ]]; then
            echo "==> ${approach} iOS — ${stage}"
            measure_ios "$approach" "$stage" "${approach}-${stage}"
        fi

        if [[ "$PLATFORM" != "ios" ]]; then
            echo "==> ${approach} Android — ${stage}"
            ./tools/measure-android.sh "${approach}-${stage}" "${approach}/android" app \
                "${stage}Release" >/dev/null
        fi
    done

    python3 - "$OUT_DIR" "$approach" "$PLATFORM" <<'PY'
import json
import pathlib
import sys

out, approach, platform = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]

WANTED = {"ios": ("ios", "app_bytes"), "android": ("android", "arm64_download_bytes")}
targets = WANTED if platform == "both" else {platform: WANTED[platform]}

for label, (prefix, key) in targets.items():
    runtime, one, two = (
        json.load(open(out / f"{prefix}-{approach}-{stage}.json"))[key]
        for stage in ("runtime", "deposit", "both")
    )
    print(f"  {label:<8} runtime {runtime / 1048576:6.2f} MB"
          f" · 1st feature {(one - runtime) / 1024:8.1f} KB"
          f" · 2nd feature {(two - one) / 1024:8.1f} KB")
PY

    if [[ "$approach" == "03-sdk-rn" && "$PLATFORM" != "android" ]]; then
        restore_rn
        trap - EXIT
    fi
done
