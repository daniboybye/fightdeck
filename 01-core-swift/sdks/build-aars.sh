#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$ROOT/scripts/build-aar-lib.sh"

# Core ships the Swift runtime and the other two link against the copy it brings, so it has
# to be built first and its output is the baseline they are diffed against.
CORE_RUNTIME="$ROOT/core/out/android-libs"

"$SCRIPT" "$ROOT/core" fightcore FightCoreShared FightCoreJava FIGHTCORE_JAVA_BRIDGE
"$SCRIPT" "$ROOT/slip" fightslip FightSlipShared FightSlipJava FIGHTSLIP_JAVA_BRIDGE "$CORE_RUNTIME"
"$SCRIPT" "$ROOT/events" fightevents FightEventsShared FightEventsJava FIGHTEVENTS_JAVA_BRIDGE "$CORE_RUNTIME"
