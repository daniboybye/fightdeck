#!/usr/bin/env bash
#
# Archive an iOS app and emit a size breakdown as JSON.
#
#   ./tools/measure-ios.sh <approach> <project-dir> <scheme>
#
# Signing is disabled on purpose. A signed IPA needs a provisioning profile that CI
# does not have, and signing adds a near-constant overhead anyway. What matters for the
# comparison is that every approach is measured exactly the same way, so we archive
# unsigned and measure the .app payload inside the archive.
#
# Emits tools/out/ios-<approach>.json

set -euo pipefail

APPROACH="${1:?usage: measure-ios.sh <approach> <project-dir> <scheme>}"
PROJECT_DIR="${2:?missing project dir}"
SCHEME="${3:?missing scheme}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/tools/out"
mkdir -p "$OUT_DIR"

if [[ ! -d "$REPO_ROOT/$PROJECT_DIR" ]]; then
    echo "::warning::$PROJECT_DIR does not exist yet — skipping $APPROACH"
    exit 0
fi

ARCHIVE_PATH="$OUT_DIR/$APPROACH.xcarchive"
rm -rf "$ARCHIVE_PATH"

# CocoaPods links React Native through a workspace, so the RN host cannot be archived from
# its bare project. Skip's SwiftPM plugin is unsigned and Xcode 26 refuses it interactively;
# both validation opt-outs are inert for the approaches that do not use plugins.
cd "$REPO_ROOT/$PROJECT_DIR"
# The container is whatever is in the directory, not whatever the scheme is called. Deriving
# it from the scheme name meant the only measurable scheme was the one sharing the project's
# name, so the single-feature hosts — which is how the cost of the second feature is
# calculated — could not be archived at all.
shopt -s nullglob
WORKSPACES=(./*.xcworkspace)
PROJECTS=(./*.xcodeproj)
shopt -u nullglob
if [[ ${#WORKSPACES[@]} -gt 0 ]]; then
    CONTAINER=(-workspace "${WORKSPACES[0]}")
elif [[ ${#PROJECTS[@]} -gt 0 ]]; then
    CONTAINER=(-project "${PROJECTS[0]}")
else
    echo "::error::no .xcworkspace or .xcodeproj in $PROJECT_DIR"
    exit 1
fi

ARCHIVE_ARGS=(
    "${CONTAINER[@]}"
    -scheme "$SCHEME"
    -destination 'generic/platform=iOS'
    -archivePath "$ARCHIVE_PATH"
    -configuration Release
    -skipPackagePluginValidation
    -skipMacroValidation
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    ONLY_ACTIVE_ARCH=NO
)

echo "==> Archiving $SCHEME from $PROJECT_DIR"
xcodebuild archive "${ARCHIVE_ARGS[@]}" | xcbeautify --quiet \
    || xcodebuild archive "${ARCHIVE_ARGS[@]}"
cd "$REPO_ROOT"

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' | head -1)"
if [[ -z "$APP_PATH" ]]; then
    echo "::error::no .app found inside $ARCHIVE_PATH"
    exit 1
fi

total_bytes() { du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'; }

APP_BYTES="$(total_bytes "$APP_PATH")"

# The executable on its own is the honest "how much code did this approach add" number.
# Asset catalogs and the JS bundle are broken out separately so a heavy SDK cannot hide
# inside the resources line.
EXECUTABLE_NAME="$(basename "$APP_PATH" .app)"
EXEC_BYTES=0
[[ -f "$APP_PATH/$EXECUTABLE_NAME" ]] && EXEC_BYTES="$(stat -f%z "$APP_PATH/$EXECUTABLE_NAME")"

FRAMEWORKS_BYTES=0
[[ -d "$APP_PATH/Frameworks" ]] && FRAMEWORKS_BYTES="$(total_bytes "$APP_PATH/Frameworks")"

ASSETS_BYTES=0
[[ -f "$APP_PATH/Assets.car" ]] && ASSETS_BYTES="$(stat -f%z "$APP_PATH/Assets.car")"

# React Native and Skip both ship a payload that is neither executable nor asset catalog.
# `.hbc` is the one that actually matters here: this repo's RN host ships Hermes bytecode,
# not a text bundle, and leaving it out of the glob reported 0 for the largest single
# non-executable payload in the app while still counting it in app_bytes.
JSBUNDLE_BYTES=0
while IFS= read -r bundle; do
    JSBUNDLE_BYTES=$((JSBUNDLE_BYTES + $(stat -f%z "$bundle")))
done < <(find "$APP_PATH" \( -name '*.jsbundle' -o -name '*.ios.bundle' -o -name '*.hbc' \) 2>/dev/null)

cat > "$OUT_DIR/ios-$APPROACH.json" <<JSON
{
  "platform": "ios",
  "approach": "$APPROACH",
  "scheme": "$SCHEME",
  "app_bytes": $APP_BYTES,
  "executable_bytes": $EXEC_BYTES,
  "frameworks_bytes": $FRAMEWORKS_BYTES,
  "assets_bytes": $ASSETS_BYTES,
  "jsbundle_bytes": $JSBUNDLE_BYTES,
  "measured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

echo "==> $APPROACH: app $((APP_BYTES / 1024 / 1024)) MB, executable $((EXEC_BYTES / 1024 / 1024)) MB"
cat "$OUT_DIR/ios-$APPROACH.json"
