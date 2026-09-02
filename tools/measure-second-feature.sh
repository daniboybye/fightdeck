#!/usr/bin/env bash
#
# What does the *next* screen cost, once the first one has paid for the runtime?
#
#   ./tools/measure-second-feature.sh            # both SDK approaches, both platforms
#   ./tools/measure-second-feature.sh 03-sdk-rn  # one approach
#
# Builds each UI-bearing SDK's host three times — runtime alone, runtime plus deposit,
# runtime plus deposit plus bet slip — and subtracts. Only the two SDK approaches have
# anything to measure: the headless cores ship no UI, so their second feature is ordinary
# application code.
#
# The three stages are selected differently on each platform, which is itself part of the
# comparison. Skip's iOS host has a scheme per stage. Both Android hosts use product
# flavours. React Native's iOS host has neither: the feature set is decided once when the
# SDK's JS bundle is built and again when CocoaPods resolves, so both steps run per stage
# and the Podfile refuses a mismatch between them.
#
# Writes tools/out/second-feature-<approach>.json, which tools/render-receipt.py reads.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"
cd "$REPO_ROOT"

export FIGHTDECK_LOCAL_SDK=1

APPROACHES=("${@:-}")
if [[ -z "${APPROACHES[0]}" ]]; then
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
    if [[ "$approach" == "03-sdk-rn" ]]; then
        trap restore_rn EXIT
    fi

    for stage in "${STAGES[@]}"; do
        echo "==> ${approach} iOS — ${stage}"
        measure_ios "$approach" "$stage" "${approach}-${stage}"

        echo "==> ${approach} Android — ${stage}"
        ./tools/measure-android.sh "${approach}-${stage}" "${approach}/android" app \
            "${stage}Release" >/dev/null
    done

    python3 - "$OUT_DIR" "$approach" <<'PY'
import json
import pathlib
import sys

out, approach = pathlib.Path(sys.argv[1]), sys.argv[2]


def stages(prefix, key):
    return [json.load(open(out / f"{prefix}-{approach}-{s}.json"))[key]
            for s in ("runtime", "deposit", "both")]


def block(prefix, key):
    runtime, one, two = stages(prefix, key)
    return {
        "runtime_only_bytes": runtime,
        "runtime_plus_one_bytes": one,
        "runtime_plus_two_bytes": two,
        "first_feature_delta_bytes": one - runtime,
        "second_feature_delta_bytes": two - one,
    }


payload = {
    "approach": approach,
    "ios": block("ios", "app_bytes"),
    "android": block("android", "arm64_download_bytes"),
}
path = out / f"second-feature-{approach}.json"
path.write_text(json.dumps(payload, indent=2) + "\n")

for platform in ("ios", "android"):
    data = payload[platform]
    print(f"  {platform:<8} runtime {data['runtime_only_bytes'] / 1048576:6.2f} MB"
          f" · 1st feature {data['first_feature_delta_bytes'] / 1024:8.1f} KB"
          f" · 2nd feature {data['second_feature_delta_bytes'] / 1024:8.1f} KB")
print(f"  wrote {path}")
PY

    if [[ "$approach" == "03-sdk-rn" ]]; then
        restore_rn
        trap - EXIT
    fi
done
