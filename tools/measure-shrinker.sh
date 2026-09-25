#!/usr/bin/env bash
#
# What R8 does to each Android release build.
#
#   ./tools/measure-shrinker.sh                 # every approach
#   ./tools/measure-shrinker.sh 04-sdk-skip     # one
#
# Run it after tools/measure-android.sh, which leaves the minified universal APK behind: this
# weighs that APK first, then rebuilds the same variant with `-PfightdeckMinify=false` and
# weighs it again. Universal APKs from one machine — read the ratios, not the digits. A
# per-ABI download compresses its dex and drops three of the four ABIs, so the saving a phone
# sees is smaller than the one in these columns.
#
# Emits tools/out/shrinker-<approach>.json. Leaves the unminified APK in the build directory;
# the next measure-android.sh run rebuilds the minified one.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"

if [[ $# -gt 0 ]]; then
    APPROACHES=("$@")
else
    APPROACHES=(00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip)
fi

variant_for() {
    case "$1" in
        03-sdk-rn|04-sdk-skip) echo "allRelease" ;;
        *) echo "release" ;;
    esac
}

apk_path() {
    local approach="$1" variant="$2" flavour="${2%Release}"
    if [[ "$flavour" == "$variant" ]]; then
        echo "$REPO_ROOT/$approach/android/app/build/outputs/apk/release/app-release.apk"
    else
        echo "$REPO_ROOT/$approach/android/app/build/outputs/apk/$flavour/release/app-$flavour-release.apk"
    fi
}

# Uncompressed bytes of every classes*.dex in the APK — the code R8 actually works on.
dex_bytes() {
    python3 - "$1" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    print(sum(i.file_size for i in z.infolist() if i.filename.startswith("classes") and i.filename.endswith(".dex")))
PY
}

for approach in "${APPROACHES[@]}"; do
    variant="$(variant_for "$approach")"
    task="assemble$(printf '%s' "${variant:0:1}" | tr '[:lower:]' '[:upper:]')${variant:1}"
    apk="$(apk_path "$approach" "$variant")"
    if [[ ! -f "$apk" ]]; then
        echo "::error::$apk missing — run tools/measure-android.sh $approach first" >&2
        exit 1
    fi

    minified_apk="$(stat -f%z "$apk")"
    minified_dex="$(dex_bytes "$apk")"

    echo "==> $approach: rebuilding $variant without R8"
    (cd "$REPO_ROOT/$approach/android" && ./gradlew --no-daemon ":app:$task" -PfightdeckMinify=false >/dev/null)
    unminified_apk="$(stat -f%z "$apk")"
    unminified_dex="$(dex_bytes "$apk")"

    cat > "$OUT_DIR/shrinker-$approach.json" <<JSON
{
  "approach": "$approach",
  "variant": "$variant",
  "apk_minified_bytes": $minified_apk,
  "apk_unminified_bytes": $unminified_apk,
  "dex_minified_bytes": $minified_dex,
  "dex_unminified_bytes": $unminified_dex,
  "measured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
    printf '  %-14s APK %6.2f -> %6.2f MB   dex %6.2f -> %6.2f MB\n' "$approach" \
        "$(echo "$unminified_apk / 1048576" | bc -l)" "$(echo "$minified_apk / 1048576" | bc -l)" \
        "$(echo "$unminified_dex / 1048576" | bc -l)" "$(echo "$minified_dex / 1048576" | bc -l)"
done
