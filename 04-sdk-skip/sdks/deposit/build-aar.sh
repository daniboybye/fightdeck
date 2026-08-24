#!/usr/bin/env bash
# Export FightDeckDeposit as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
CORE_AAR="${FIGHTDECK_CORE_AAR:-$REPO_ROOT/tools/out/release/skip/FightDeckCore-release.aar}"
SKIPSTONE="$ROOT/.build/plugins/outputs/deposit/FightDeckDepositBinary/destination/skipstone"
BINARY_MODULE="FightDeckDepositBinary"

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
sed -i '' 's|api(project(":FightDeckCoreBinary"))|compileOnly(files("../FightDeckCore-classes/classes.jar"))|' \
    "$SKIPSTONE/FightDeckDepositBinary/build.gradle.kts"
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

cp "$BUILT" "$OUT/FightDeckDeposit-release.aar"

# A successful `skip export` also drops the raw module AAR and core's here. Both are
# duplicates of something the host already links, and duplicates collide in the
# manifest merger and in the release staging directory.
rm -f "$OUT/${BINARY_MODULE}-release.aar" "$OUT"/FightDeckCore*-release.aar

# Copy Skip runtime AARs from the skipstone build for local Android consumption.
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
RELEASE_AARS="$REPO_ROOT/tools/out/release/skip"
for name in SkipFoundation SkipLib SkipModel SkipUI SkipUnit; do
    src=$(find "$SKIPSTONE" -path "*/${name}/build/outputs/aar/${name}-release.aar" 2>/dev/null | head -1)
    if [[ -z "$src" && -f "$RELEASE_AARS/${name}-release.aar" ]]; then
        src="$RELEASE_AARS/${name}-release.aar"
    fi
    if [[ -n "$src" ]]; then
        cp "$src" "$OUT/${name}-release.aar"
    fi
done

for aar in "$OUT"/*.aar; do
    bytes="$(stat -f%z "$aar" 2>/dev/null || stat -c%s "$aar")"
    if [[ "$(basename "$aar")" == FightDeckDeposit-release.aar ]] && (( bytes < 1024 )); then
        echo "error: stub-sized AAR ($bytes B): $aar" >&2
        exit 1
    fi
done

echo "Wrote AAR artifacts:"
ls -lh "$OUT"/*.aar
du -sh "$OUT"/*.aar
