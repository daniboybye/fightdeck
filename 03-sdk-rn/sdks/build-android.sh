#!/usr/bin/env bash
# Builds every local RN Android binary in dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

"$ROOT/core/build-aar.sh"
"$ROOT/deposit/build-aar.sh"
"$ROOT/betslip/build-aar.sh"
"$ROOT/fighter/build-aar.sh"
