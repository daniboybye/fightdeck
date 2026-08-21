#!/usr/bin/env bash
# Export Android SDK/NDK paths for Swift SDK for Android cross-compilation.
# Source this before `swift build --swift-sdk …-android28` or `./build-aar.sh`.
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-${HOME}/Library/Android/sdk}"
export ANDROID_HOME

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    # Prefer pinned r27d; fall back to any installed r27.x NDK.
    pinned="${ANDROID_HOME}/ndk/27.3.13750724"
    if [[ -d "$pinned" ]]; then
        export ANDROID_NDK_HOME="$pinned"
    else
        ndk="$(ls -d "${ANDROID_HOME}/ndk/"27.* 2>/dev/null | sort -V | tail -1 || true)"
        if [[ -z "$ndk" ]]; then
            echo "ERROR: No Android NDK found under ${ANDROID_HOME}/ndk" >&2
            exit 1
        fi
        export ANDROID_NDK_HOME="$ndk"
    fi
else
    export ANDROID_NDK_HOME
fi

echo "ANDROID_HOME=$ANDROID_HOME"
echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
