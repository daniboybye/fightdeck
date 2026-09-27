#!/usr/bin/env bash
# Package real Android AAR artifacts. Fails loudly on stubs.
set -euo pipefail

RN_VERSION="${RN_VERSION:-0.87.0}"
HERMES_COORD="${HERMES_COORD:-com.facebook.hermes:hermes-android:250829098.0.16}"

# FIGHTDECK_SDK_CONFIGURATION=debug assembles each library's debug variant instead of the
# release one that ships. The file names in out/ stay the same: the host links them by path.
if [[ "${FIGHTDECK_SDK_CONFIGURATION:-release}" == "debug" ]]; then
    SDK_VARIANT=debug
    SDK_VARIANT_TASK=Debug
else
    SDK_VARIANT=release
    SDK_VARIANT_TASK=Release
fi

find_gradle_aar() {
    local pattern="$1"
    local found
    found="$(find "$HOME/.gradle/caches/modules-2/files-2.1" -name "$pattern" 2>/dev/null | head -1 || true)"
    if [[ -z "$found" || ! -f "$found" ]]; then
        echo "error: could not locate $pattern in Gradle cache — build the Android host once" >&2
        exit 1
    fi
    printf '%s\n' "$found"
}

pack_rn_runtime_aars() {
    local out_dir="$1"
    local gradle_aar="$2"

    mkdir -p "$out_dir"
    rm -f "$out_dir"/*.aar

    if [[ ! -f "$gradle_aar" ]]; then
        echo "error: Gradle AAR missing: $gradle_aar" >&2
        exit 1
    fi
    cp "$gradle_aar" "$out_dir/FightDeckRNRuntime.aar"

    local react_aar hermes_aar
    react_aar="$(find_gradle_aar "react-android-${RN_VERSION}-release.aar")"
    hermes_aar="$(find_gradle_aar "hermes-android-250829098.0.16-release.aar")"

    cp "$react_aar" "$out_dir/react-android-${RN_VERSION}-release.aar"
    cp "$hermes_aar" "$out_dir/hermes-android-release.aar"

    for coord in "soloader-0.12.1.aar" "annotation-0.12.1.jar" "nativeloader-0.12.1.jar"; do
        found="$(find "$HOME/.gradle/caches/modules-2/files-2.1/com.facebook.soloader" -name "$coord" 2>/dev/null | head -1 || true)"
        if [[ -z "$found" ]]; then
            echo "error: missing RN bootstrap artifact: $coord" >&2
            exit 1
        fi
        cp "$found" "$out_dir/$(basename "$found")"
    done

    for aar in "$out_dir"/*.aar; do
        local bytes
        bytes="$(stat -f%z "$aar" 2>/dev/null || stat -c%s "$aar")"
        if (( bytes < 4096 )); then
            echo "error: stub-sized AAR ($bytes B): $aar" >&2
            exit 1
        fi
        echo "  $(basename "$aar"): $bytes bytes"
    done
}

pack_feature_aar() {
    local out_dir="$1"
    local gradle_aar="$2"
    local product_name="$3"

    mkdir -p "$out_dir"
    rm -f "$out_dir/${product_name}.aar"

    if [[ ! -f "$gradle_aar" ]]; then
        echo "error: Gradle AAR missing: $gradle_aar" >&2
        exit 1
    fi

    cp "$gradle_aar" "$out_dir/${product_name}.aar"
    local bytes
    bytes="$(stat -f%z "$out_dir/${product_name}.aar" 2>/dev/null || stat -c%s "$out_dir/${product_name}.aar")"
    if (( bytes < 1024 )); then
        echo "error: stub-sized feature AAR ($bytes B)" >&2
        exit 1
    fi
    echo "Wrote $out_dir/${product_name}.aar ($bytes bytes)"
}
