#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/node_modules/@react-native/gradle-plugin/gradle/libs.versions.toml"

if [[ ! -f "$PLUGIN" ]]; then
  echo "React Native gradle plugin not found. Run: cd sdks/core && npm install && ln -sf sdks/core/node_modules $ROOT/node_modules"
  exit 1
fi

# Gradle 9.7 embeds Kotlin stdlib 2.4; RN 0.87 plugin defaults to Kotlin 2.2 compiler metadata.
sed -i '' 's/kotlin = "2.2.0"/kotlin = "2.4.10"/' "$PLUGIN"
echo "Patched $PLUGIN to kotlin 2.4.10"
