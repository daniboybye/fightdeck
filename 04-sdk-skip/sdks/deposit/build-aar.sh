#!/usr/bin/env bash
# Export FightDeckDeposit as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_BUILDING_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
# shellcheck source=../skip-aar-publish.sh
source "$ROOT/../skip-aar-publish.sh"

CORE_AAR="${FIGHTDECK_CORE_AAR:-$REPO_ROOT/04-sdk-skip/sdks/core/out/FightDeckCore-${SKIP_VARIANT}.aar}"
SKIPSTONE="$ROOT/.build/plugins/outputs/deposit/FightDeckDepositBinary/destination/skipstone"
BINARY_MODULE="FightDeckDepositBinary"
MAVEN_REPO="$REPO_ROOT/04-sdk-skip/sdks/out/maven"

mkdir -p "$OUT"
rm -f "$OUT"/*.aar

if [[ ! -f "$CORE_AAR" ]]; then
    echo "error: FightDeckCore AAR not found at $CORE_AAR (build sdks/core first)" >&2
    exit 1
fi

skip export --module "$BINARY_MODULE" "$SKIP_EXPORT_FLAG" -d "$OUT" --project "$ROOT" \
    || [[ -d "$SKIPSTONE" ]]

if [[ ! -d "$SKIPSTONE" ]]; then
    echo "error: skipstone output missing at $SKIPSTONE" >&2
    exit 1
fi

cp "$CORE_AAR" "$SKIPSTONE/FightDeckCore-release.aar"
(
    cd "$SKIPSTONE"
    rm -rf FightDeckCore-classes
    mkdir -p FightDeckCore-classes
    unzip -q -o FightDeckCore-release.aar classes.jar -d FightDeckCore-classes
)
sed -i '' 's|api(project(":FightDeckCoreBinary"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    "$SKIPSTONE/FightDeckDepositBinary/build.gradle.kts"
sed -i '' '/include(":FightDeckCoreBinary")/,+1d' "$SKIPSTONE/settings.gradle.kts"

patch_skip_ui_reflect "$SKIPSTONE"
patch_skip_commonmark_api "$SKIPSTONE"
prepare_skipstone_for_patch "$SKIPSTONE"
configure_skipstone_maven_repo "$SKIPSTONE" "$MAVEN_REPO"

(
    cd "$SKIPSTONE"
    gradle ":${BINARY_MODULE}:assemble${SKIP_VARIANT_TASK}" --console=plain
)

BUILT="$SKIPSTONE/${BINARY_MODULE}/build/outputs/aar/${BINARY_MODULE}-${SKIP_VARIANT}.aar"
if [[ ! -f "$BUILT" ]]; then
    echo "error: gradle did not produce $BUILT" >&2
    exit 1
fi

cp "$BUILT" "$OUT/FightDeckDeposit-${SKIP_VARIANT}.aar"

publish_skipstone_maven "$SKIPSTONE" \
    SkipFoundation SkipLib SkipModel SkipUI SkipUnit "$BINARY_MODULE"

rm -f "$OUT/${BINARY_MODULE}-${SKIP_VARIANT}.aar" "$OUT"/FightDeckCore*-${SKIP_VARIANT}.aar

for name in SkipFoundation SkipLib SkipModel SkipUI SkipUnit; do
    src=$(find "$SKIPSTONE" -path "*/${name}/build/outputs/aar/${name}-${SKIP_VARIANT}.aar" 2>/dev/null | head -1)
    if [[ -n "$src" ]]; then
        cp "$src" "$OUT/${name}-${SKIP_VARIANT}.aar"
    fi
done

for aar in "$OUT"/*.aar; do
    bytes="$(stat -f%z "$aar" 2>/dev/null || stat -c%s "$aar")"
    if [[ "$(basename "$aar")" == FightDeckDeposit-${SKIP_VARIANT}.aar ]] && (( bytes < 1024 )); then
        echo "error: stub-sized AAR ($bytes B): $aar" >&2
        exit 1
    fi
done

echo "Wrote AAR artifacts:"
ls -lh "$OUT"/*.aar
echo "Maven repo: $MAVEN_REPO"
du -sh "$OUT"/*.aar
