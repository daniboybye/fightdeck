#!/usr/bin/env bash
# Export FightDeckFighter as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
# shellcheck source=../skip-aar-publish.sh
source "$ROOT/../skip-aar-publish.sh"

CORE_AAR="${FIGHTDECK_CORE_AAR:-$REPO_ROOT/tools/out/release/skip/FightDeckCore-release.aar}"
SKIPSTONE="$ROOT/.build/plugins/outputs/fighter/FightDeckFighterBinary/destination/skipstone"
BINARY_MODULE="FightDeckFighterBinary"
MAVEN_REPO="$REPO_ROOT/04-sdk-skip/sdks/out/maven"

mkdir -p "$OUT"
rm -f "$OUT"/*.aar

if [[ ! -f "$CORE_AAR" ]]; then
    echo "error: FightDeckCore AAR not found at $CORE_AAR (build sdks/core first or use pinned release)" >&2
    exit 1
fi

skip export --module "$BINARY_MODULE" --release -d "$OUT" --project "$ROOT" \
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
GRADLE="$SKIPSTONE/FightDeckFighterBinary/build.gradle.kts"
sed -i '' \
    -e 's|api(project(":FightDeckCoreBinary"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    -e 's|api(files("../FightDeckCore-release.aar"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    -e 's|compileOnly(files("../FightDeckCore-release.aar"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    "$GRADLE"
sed -i '' '/include(":FightDeckCoreBinary")/,+1d' "$SKIPSTONE/settings.gradle.kts"

patch_skip_ui_reflect "$SKIPSTONE"
patch_skip_commonmark_api "$SKIPSTONE"
prepare_skipstone_for_patch "$SKIPSTONE"
configure_skipstone_maven_repo "$SKIPSTONE" "$MAVEN_REPO"

(
    cd "$SKIPSTONE"
    gradle ":${BINARY_MODULE}:assembleRelease" --console=plain
)

BUILT="$SKIPSTONE/${BINARY_MODULE}/build/outputs/aar/${BINARY_MODULE}-release.aar"
if [[ ! -f "$BUILT" ]]; then
    echo "error: gradle did not produce $BUILT" >&2
    exit 1
fi

cp "$BUILT" "$OUT/FightDeckFighter-release.aar"

publish_skipstone_maven "$SKIPSTONE" \
    SkipFoundation SkipLib SkipModel SkipUI SkipUnit "$BINARY_MODULE"

rm -f "$OUT/${BINARY_MODULE}-release.aar" "$OUT"/FightDeckCore*-release.aar

bytes="$(stat -f%z "$OUT/FightDeckFighter-release.aar" 2>/dev/null || stat -c%s "$OUT/FightDeckFighter-release.aar")"
if (( bytes < 1024 )); then
    echo "error: stub-sized AAR ($bytes B)" >&2
    exit 1
fi

echo "Wrote AAR artifacts:"
ls -lh "$OUT"/*.aar
echo "Maven repo: $MAVEN_REPO"
du -sh "$OUT"/*.aar
