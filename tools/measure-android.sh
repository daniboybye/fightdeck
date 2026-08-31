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

# The bundle directory is named for the variant, the APK directory splits flavour and build
# type into separate levels. Both are addressed exactly: a `find | sort | head -1` picked
# whichever variant sorted first, so once a second flavour had ever been built, every
# approach reported bothRelease no matter which variant was asked for — which is how the
# cost of the second feature came out as zero bytes.
AAB_PATH="$(ls "$MODULE/build/outputs/bundle/$VARIANT"/*.aab 2>/dev/null | head -1)"
FLAVOUR="${VARIANT%Release}"
if [[ "$FLAVOUR" == "$VARIANT" ]]; then
    APK_DIR="$MODULE/build/outputs/apk/release"
else
    APK_DIR="$MODULE/build/outputs/apk/$FLAVOUR/release"
fi
APK_PATH="$(ls "$APK_DIR"/*.apk 2>/dev/null | head -1)"

if [[ -z "$AAB_PATH" || -z "$APK_PATH" ]]; then
    echo "::error::no $VARIANT artifacts under $MODULE/build/outputs for $APPROACH"
    exit 1
fi

APK_BYTES="$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH")"
AAB_BYTES="$(stat -f%z "$AAB_PATH" 2>/dev/null || stat -c%s "$AAB_PATH")"

# Per-ABI download size via bundletool. This is what a phone actually pulls, and for
# anything carrying a native runtime (Swift, Rust, Hermes, Skip) it is dramatically
# smaller than the universal APK, so quoting the APK would slander every native approach.
ARM64_BYTES=0
if [[ -n "$AAB_PATH" ]]; then
    # Pinned rather than "latest": the release asset is version-stamped, so the /latest/
    # convenience path 404s and curl happily writes the HTML error body into the jar. That
    # failed silently and every arm64 figure came out as zero.
    BUNDLETOOL_VERSION="$("$REPO_ROOT/tools/versions.py" android.bundletool)"
    BUNDLETOOL="$REPO_ROOT/tools/out/bundletool-${BUNDLETOOL_VERSION}.jar"
    if [[ ! -f "$BUNDLETOOL" ]]; then
        echo "==> Fetching bundletool $BUNDLETOOL_VERSION"
        curl -fsSL -o "$BUNDLETOOL" \
            "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar"
    fi

    APKS_PATH="$OUT_DIR/$APPROACH.apks"
    rm -f "$APKS_PATH"
    java -jar "$BUNDLETOOL" build-apks \
        --bundle="$AAB_PATH" --output="$APKS_PATH" --mode=default >/dev/null
    ARM64_BYTES="$(java -jar "$BUNDLETOOL" get-size total \
        --apks="$APKS_PATH" --dimensions=ABI \
        | awk -F',' '/arm64-v8a/ {print $NF; exit}' | tr -d ' \r')"
    if [[ -z "$ARM64_BYTES" || "$ARM64_BYTES" == "0" ]]; then
        echo "::error::bundletool reported no arm64-v8a split for $APPROACH"
        exit 1
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
