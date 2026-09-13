#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-aar-lib.sh" "$HERE" fightcore FightCoreShared FightCoreJava FIGHTCORE_JAVA_BRIDGE
