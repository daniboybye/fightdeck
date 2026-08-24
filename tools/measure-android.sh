#!/usr/bin/env bash
#
# Build an Android app release and emit a size breakdown as JSON.
#
#   ./tools/measure-android.sh <approach> <project-dir> [module] [variant]
#
# The React Native and Skip hosts carry product flavours, so the variant to weigh is
# named rather than assumed: `bothRelease` is the demo configuration, the other flavours
# exist to price a single feature.
#
# The universal APK is the number people quote and the least honest one, because
# nobody downloads it: Play delivers a per-ABI split. Both are recorded, and the
# per-ABI figure is the one that goes on the slide.
#
# Emits tools/out/android-<approach>.json

set -euo pipefail

APPROACH="${1:?usage: measure-android.sh <approach> <project-dir> [module] [variant]}"
PROJECT_DIR="${2:?missing project dir}"
MODULE="${3:-app}"
VARIANT="${4:-release}"
VARIANT_TASK="$(printf '%s' "${VARIANT:0:1}" | tr '[:lower:]' '[:upper:]')${VARIANT:1}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"

if [[ ! -f "$REPO_ROOT/$PROJECT_DIR/gradlew" ]]; then
    echo "::warning::$PROJECT_DIR has no gradlew yet — skipping $APPROACH"
    exit 0
fi

cd "$REPO_ROOT/$PROJECT_DIR"

echo "==> Building $MODULE $VARIANT"
./gradlew --no-daemon ":$MODULE:assemble$VARIANT_TASK" ":$MODULE:bundle$VARIANT_TASK"

# A flavoured build nests the output one directory deeper, so search rather than assume.
APK_PATH="$(find "$MODULE/build/outputs/apk" -name '*.apk' -path '*release*' | sort | head -1)"
AAB_PATH="$(find "$MODULE/build/outputs/bundle" -name '*.aab' | sort | head -1)"

APK_BYTES=0
[[ -n "$APK_PATH" ]] && APK_BYTES="$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH")"

AAB_BYTES=0
[[ -n "$AAB_PATH" ]] && AAB_BYTES="$(stat -f%z "$AAB_PATH" 2>/dev/null || stat -c%s "$AAB_PATH")"

# Per-ABI download size via bundletool. This is what a phone actually pulls, and for
# anything carrying a native runtime (Swift, Rust, Hermes, Skip) it is dramatically
# smaller than the universal APK, so quoting the APK would slander every native approach.
ARM64_BYTES=0
if [[ -n "$AAB_PATH" ]]; then
    BUNDLETOOL="$REPO_ROOT/tools/out/bundletool.jar"
    if [[ ! -f "$BUNDLETOOL" ]]; then
        echo "==> Fetching bundletool"
        curl -sSL -o "$BUNDLETOOL" \
            https://github.com/google/bundletool/releases/latest/download/bundletool-all.jar || true
    fi
    if [[ -f "$BUNDLETOOL" ]]; then
        APKS_PATH="$OUT_DIR/$APPROACH.apks"
        rm -f "$APKS_PATH"
        java -jar "$BUNDLETOOL" build-apks \
            --bundle="$AAB_PATH" --output="$APKS_PATH" --mode=default >/dev/null 2>&1 || true
        if [[ -f "$APKS_PATH" ]]; then
            ARM64_BYTES="$(java -jar "$BUNDLETOOL" get-size total \
                --apks="$APKS_PATH" --dimensions=ABI 2>/dev/null \
                | awk -F',' '/arm64-v8a/ {print $NF; exit}' | tr -d ' \r')"
            ARM64_BYTES="${ARM64_BYTES:-0}"
        fi
    fi
fi

cat > "$OUT_DIR/android-$APPROACH.json" <<JSON
{
  "platform": "android",
  "approach": "$APPROACH",
  "module": "$MODULE",
  "variant": "$VARIANT",
  "apk_universal_bytes": $APK_BYTES,
  "aab_bytes": $AAB_BYTES,
  "arm64_download_bytes": $ARM64_BYTES,
  "measured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

echo "==> $APPROACH: APK $((APK_BYTES / 1024 / 1024)) MB, arm64 download $((ARM64_BYTES / 1024 / 1024)) MB"
cat "$OUT_DIR/android-$APPROACH.json"
