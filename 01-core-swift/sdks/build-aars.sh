#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# One AAR for all three SDKs: ../android links core, slip and events into libfightdeck.so,
# which carries the Swift runtime and the jextract bindings of all three facades.
"$ROOT/scripts/build-aar-lib.sh" "$ROOT/android" fightdeck FightDeckShared FightDeckJava com.fightdeck.sdk
