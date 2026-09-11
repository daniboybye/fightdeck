#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-xcframework.sh" fightslip fightslip FightSlip "$HERE"
