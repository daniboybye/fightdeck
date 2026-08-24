#!/usr/bin/env bash
# Export FightDeckBetslip as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
CORE_AAR="${FIGHTDECK_CORE_AAR:-$REPO_ROOT/tools/out/release/skip/FightDeckCore-release.aar}"
SKIPSTONE="$ROOT/.build/plugins/outputs/betslip/FightDeckBetslipBinary/destination/skipstone"
BINARY_MODULE="FightDeckBetslipBinary"

mkdir -p "$OUT"
rm -f "$OUT"/*.aar

if [[ ! -f "$CORE_AAR" ]]; then
    echo "error: FightDeckCore AAR not found at $CORE_AAR (build sdks/core first or use pinned release)" >&2
    exit 1
fi

# Transpile Swift → Kotlin. Gradle assembly is patched below because the binary
# skipstone project links FightDeckCoreBinary (fight.deck.core.binary) while the
# UI imports fight.deck.core — the pinned umbrella core AAR resolves that.
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
GRADLE="$SKIPSTONE/FightDeckBetslipBinary/build.gradle.kts"
sed -i '' \
    -e 's|api(project(":FightDeckCoreBinary"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    -e 's|api(files("../FightDeckCore-release.aar"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    -e 's|compileOnly(files("../FightDeckCore-release.aar"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    "$GRADLE"
sed -i '' '/include(":FightDeckCoreBinary")/,+1d' "$SKIPSTONE/settings.gradle.kts"

(
    cd "$SKIPSTONE"
    gradle ":${BINARY_MODULE}:assembleRelease" --console=plain
)

BUILT="$SKIPSTONE/${BINARY_MODULE}/build/outputs/aar/${BINARY_MODULE}-release.aar"
if [[ ! -f "$BUILT" ]]; then
    echo "error: gradle did not produce $BUILT" >&2
    exit 1
fi

cp "$BUILT" "$OUT/FightDeckBetslip-release.aar"

# A successful `skip export` also drops the raw module AAR and core's here. Both are
# duplicates of something the host already links, and duplicates collide in the
# manifest merger and in the release staging directory.
rm -f "$OUT/${BINARY_MODULE}-release.aar" "$OUT"/FightDeckCore*-release.aar

bytes="$(stat -f%z "$OUT/FightDeckBetslip-release.aar" 2>/dev/null || stat -c%s "$OUT/FightDeckBetslip-release.aar")"
if (( bytes < 1024 )); then
    echo "error: stub-sized AAR ($bytes B)" >&2
    exit 1
fi

echo "Wrote AAR artifacts:"
ls -lh "$OUT"/*.aar
du -sh "$OUT"/*.aar
