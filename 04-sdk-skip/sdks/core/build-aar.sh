#!/usr/bin/env bash
# Export FightDeckCore as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
# shellcheck source=../skip-aar-publish.sh
source "$ROOT/../skip-aar-publish.sh"

BINARY_MODULE="FightDeckCoreBinary"
SKIPSTONE="$ROOT/.build/plugins/outputs/core/FightDeckCoreBinary/destination/skipstone"
MAVEN_REPO="$REPO_ROOT/04-sdk-skip/sdks/out/maven"

mkdir -p "$OUT"
rm -f "$OUT"/*.aar

skip export --module "$BINARY_MODULE" --release -d "$OUT" --project "$ROOT"

if [[ -f "$OUT/${BINARY_MODULE}-release.aar" ]]; then
    mv "$OUT/${BINARY_MODULE}-release.aar" "$OUT/FightDeckCore-release.aar"
fi

if [[ -d "$SKIPSTONE" ]]; then
    prepare_skipstone_for_patch "$SKIPSTONE"
    patch_skip_commonmark_api "$SKIPSTONE"
    configure_skipstone_maven_repo "$SKIPSTONE" "$MAVEN_REPO"
    publish_skipstone_maven "$SKIPSTONE" SkipFoundation SkipLib SkipUnit "$BINARY_MODULE"
fi

for aar in "$OUT"/*.aar; do
    bytes="$(stat -f%z "$aar" 2>/dev/null || stat -c%s "$aar")"
    if (( bytes < 1024 )); then
        echo "error: stub-sized AAR ($bytes B): $aar" >&2
        exit 1
    fi
done

echo "Wrote AAR artifacts:"
ls -lh "$OUT"/*.aar
echo "Maven repo: $MAVEN_REPO"
du -sh "$OUT"/*.aar
