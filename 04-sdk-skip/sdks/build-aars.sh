#!/usr/bin/env bash
# Export every Skip module as an Android AAR, in the only order that works.
#
# The other modules link against the core AAR rather than re-transpiling it, so
# core has to exist on disk before they run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

"$ROOT/core/build-aar.sh"

export FIGHTDECK_CORE_AAR="$ROOT/core/out/FightDeckCore-release.aar"
for module in events deposit betslip fighter; do
    "$ROOT/$module/build-aar.sh"
done
