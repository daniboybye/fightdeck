#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../scripts/build-aar.sh" fightcore fightcore "$HERE"
