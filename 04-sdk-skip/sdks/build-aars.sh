#!/usr/bin/env bash
# Export all three Skip modules as Android AARs, in the only order that works.
#
# The two feature modules link against the core AAR rather than re-transpiling it, so
# core has to exist on disk before they run. Their scripts look for it in the staged
# release directory by default, which is exactly what a machine that has never built
# this repository does not have; pointing them at core's own output is what makes a
# clean clone behave like a developer's machine.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

"$ROOT/core/build-aar.sh"

export FIGHTDECK_CORE_AAR="$ROOT/core/out/FightDeckCore-release.aar"
for module in deposit betslip; do
    "$ROOT/$module/build-aar.sh"
done
