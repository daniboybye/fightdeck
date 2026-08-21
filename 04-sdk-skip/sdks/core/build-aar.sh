#!/usr/bin/env bash
# Export FightDeckCore as an Android AAR via skipstone / skip export.
set -euo pipefail

export FIGHTDECK_LOCAL_SDK=1

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
BINARY_MODULE="FightDeckCoreBinary"

mkdir -p "$OUT"
rm -f "$OUT"/*.aar

skip export --module "$BINARY_MODULE" --release -d "$OUT" --project "$ROOT"

if [[ -f "$OUT/${BINARY_MODULE}-release.aar" ]]; then
    cp "$OUT/${BINARY_MODULE}-release.aar" "$OUT/FightDeckCore-release.aar"
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
du -sh "$OUT"/*.aar
