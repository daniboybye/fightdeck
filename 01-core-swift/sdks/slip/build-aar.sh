#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-aar-lib.sh" "$HERE" fightslip FightSlipShared FightSlipJava FIGHTSLIP_JAVA_BRIDGE
