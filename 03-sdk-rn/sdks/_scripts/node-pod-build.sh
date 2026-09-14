#!/usr/bin/env bash
# The RN prebuilt-dependency swap mutates Pods while Xcode reads it and is unnecessary
# after pod install. Keep every other Node-based CocoaPods phase running normally.
set -euo pipefail

if [[ "${1:-}" == *"/replace_dependencies_version.js" ]]; then
  exit 0
fi

exec "${FIGHTDECK_REAL_NODE:?FIGHTDECK_REAL_NODE is not set}" "$@"
