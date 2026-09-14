#!/usr/bin/env bash
# Package FightDeckEvents for iOS distribution as an XCFramework zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../_scripts/build-swift-xcframework.sh
source "$ROOT/../_scripts/build-swift-xcframework.sh"

build_swift_xcframework "$ROOT" FightDeckEvents FightDeckEventsBinary 50000
