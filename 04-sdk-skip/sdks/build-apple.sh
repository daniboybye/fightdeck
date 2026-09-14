#!/usr/bin/env bash
# Builds every local Skip Apple binary in dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

for module in core events deposit betslip fighter; do
  "$ROOT/$module/build-xcframework.sh"
done
