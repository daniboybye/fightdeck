#!/usr/bin/env bash
# Builds all three Apple SDK packages. Each one is a SwiftPM package the iOS app resolves by
# path, so there is nothing left to copy into the app after this runs.
set -euo pipefail

SDKS="$(cd "$(dirname "$0")" && pwd)"

echo "Building Rust SDK packages for Apple platforms:"
"$SDKS/core/build-xcframework.sh"
"$SDKS/slip/build-xcframework.sh"
"$SDKS/events/build-xcframework.sh"

echo
echo "Checksums for the binary targets in each Package.swift:"
for pkg in core:FightCore slip:FightSlip events:FightEvents; do
  dir="${pkg%%:*}"
  framework="${pkg##*:}"
  zip="$SDKS/$dir/out/$framework.xcframework.zip"
  printf "  %-14s %s\n" "$framework" "$(swift package compute-checksum "$zip")"
done
