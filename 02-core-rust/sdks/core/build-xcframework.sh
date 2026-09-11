#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-xcframework.sh" fightcore fightcore FightCore "$HERE"
