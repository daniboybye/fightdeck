#!/usr/bin/env bash
#
# What does the *next* screen cost, once the first one has paid for the runtime?
#
#   ./tools/measure-second-feature.sh                    # both SDKs, both platforms
#   ./tools/measure-second-feature.sh 03-sdk-rn          # one approach
#   FIGHTDECK_PLATFORM=android ./tools/measure-second-feature.sh 03-sdk-rn
#
# Builds each UI-bearing SDK's host four times — runtime alone, then with deposit, bet slip
# and fighter profile added one at a time — leaving one measurement file per stage. Only the
# two SDK approaches have anything to measure: the headless cores ship no UI, so a second
# feature there is ordinary application code.
#
# Three feature screens rather than two because the first one is not representative: it
# drags in whatever the runtime lazily needs. The fighter profile is the smallest of the
# three and pure presentation, so it shows what a screen costs once nothing is left to
# amortise.
#
# The stages are selected differently on each platform, which is itself part of the
# comparison. Both iOS hosts build a small measurement harness per stage, so neither demo
# app carries conditional compilation for the sake of being weighed. Both Android hosts use
# product flavours. React Native needs one step the others do not: its feature set is also
# decided when the SDK's JS bundle is built, so that runs per stage too and the Podfile
# refuses a bundle that disagrees with the stage being measured.
#
# FIGHTDECK_PLATFORM exists so CI can put each half on the cheapest runner that can build
# it. tools/render-receipt.py reads the per-stage files, so the halves never have to meet.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"
cd "$REPO_ROOT"

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

STAGES=(runtime deposit both all)

# What each stage adds on top of the one before it, for the summary at the end.
stage_feature() {
    case "$1" in
        deposit) echo "deposit" ;;
        both)    echo "bet slip" ;;
        all)     echo "fighter" ;;
    esac
}

# Leaving the React Native checkout on a partial feature set would silently shrink the next
# ordinary build, so restore the full one whatever happens.
restore_rn() {
    echo "==> Restoring React Native host to the full feature set"
    FIGHTDECK_FEATURES=all ./03-sdk-rn/sdks/core/build-jsbundle.sh >/dev/null 2>&1 || true
    cp 03-sdk-rn/sdks/core/ios/Resources/fightdeck.hbc \
        03-sdk-rn/sdks/out/ios-vendor/runtime/Resources/fightdeck.hbc 2>/dev/null || true
    (cd 03-sdk-rn/ios && FIGHTDECK_FEATURES=all pod install >/dev/null 2>&1) || true
}

# Both iOS hosts name their harnesses the same way, so the stage maps straight to a scheme.
# The demo apps are deliberately never measured here: each links every feature, so it could
# only ever produce the "both" number.
harness_scheme() {
    case "$1" in
        runtime) echo "FightDeckHarnessRuntime" ;;
        deposit) echo "FightDeckHarnessDeposit" ;;
        both)    echo "FightDeckHarnessBoth" ;;
        all)     echo "FightDeckHarnessAll" ;;
    esac
}

measure_ios() {
    local approach="$1" stage="$2" tag="$3"

    # The feature screens live in the JS bundle, and CocoaPods expands the bundle's resource
    # glob when it installs, so a stage that adds an image needs both steps redone before
    # its harness is archived.
    if [[ "$approach" == "03-sdk-rn" ]]; then
        FIGHTDECK_FEATURES="$stage" ./03-sdk-rn/sdks/core/build-jsbundle.sh >/dev/null
        cp 03-sdk-rn/sdks/core/ios/Resources/fightdeck.hbc \
            03-sdk-rn/sdks/out/ios-vendor/runtime/Resources/fightdeck.hbc
        (cd 03-sdk-rn/ios && FIGHTDECK_FEATURES="$stage" pod install >/dev/null)
    fi

    ./tools/measure-ios.sh "$tag" "$approach/ios" "$(harness_scheme "$stage")" >/dev/null
}

for approach in "${APPROACHES[@]}"; do
    if [[ "$approach" == "03-sdk-rn" ]]; then
        [[ "$PLATFORM" == "android" ]] || ./03-sdk-rn/sdks/build-apple.sh
        [[ "$PLATFORM" == "ios" ]] || ./03-sdk-rn/sdks/build-android.sh
    elif [[ "$approach" == "04-sdk-skip" ]]; then
        # iOS compiles the Skip SDKs into each harness from source; only Android has an SDK
        # to build first.
        [[ "$PLATFORM" == "ios" ]] || ./04-sdk-skip/sdks/build-aars.sh
    fi

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

# Each stage adds one screen to the one before it, so consecutive differences are the
# marginal cost of that screen.
STAGES = (("runtime", None), ("deposit", "deposit"), ("both", "bet slip"), ("all", "fighter"))

for label, (prefix, key) in targets.items():
    sizes = [
        json.load(open(out / f"{prefix}-{approach}-{stage}.json"))[key]
        for stage, _ in STAGES
    ]
    marginal = "".join(
        f" · {name} {(after - before) / 1024:7.1f} KB"
        for (_, name), before, after in zip(STAGES[1:], sizes, sizes[1:])
    )
    print(f"  {label:<8} runtime {sizes[0] / 1048576:6.2f} MB{marginal}")
PY

    if [[ "$approach" == "03-sdk-rn" && "$PLATFORM" != "android" ]]; then
        restore_rn
        trap - EXIT
    fi
done
