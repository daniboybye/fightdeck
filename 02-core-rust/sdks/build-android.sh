#!/usr/bin/env bash
# Builds all three Android SDK artifacts and installs their bindings into the Android app.
set -euo pipefail

SDKS="$(cd "$(dirname "$0")" && pwd)"

echo "Building Rust SDKs for Android:"
"$SDKS/core/build-aar.sh"
"$SDKS/slip/build-aar.sh"
"$SDKS/events/build-aar.sh"
