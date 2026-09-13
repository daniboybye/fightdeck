#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-aar-lib.sh" "$HERE" fightevents FightEventsShared FightEventsJava FIGHTEVENTS_JAVA_BRIDGE
