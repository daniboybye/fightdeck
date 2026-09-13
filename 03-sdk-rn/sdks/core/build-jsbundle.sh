#!/usr/bin/env bash
#
# Bundle the JS runtime for one feature set and compile it to Hermes bytecode.
#
#   FIGHTDECK_FEATURES=deposit ./build-jsbundle.sh
#
# Split out of build-xcframework.sh because the xcframework is identical for every feature
# set — only the bundle changes. Measuring what the second feature costs means building the
# same native code twice with different JavaScript, and rebuilding three architecture slices
# to swap one file is minutes of nothing.
#
# Writes ios/Resources/fightdeck.hbc, the ios/.fightdeck-features stamp the Podfile checks,
# and the intermediate text bundle under ios/.jsbundle-staging (not shipped).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

if ! command -v npx >/dev/null 2>&1; then
    echo "error: npx not found — install Node.js" >&2
    exit 1
fi

# Android already selects an entry point per flavour: syncRnEntry copies index.<flavour>.js
# to index.active.js before Gradle bundles. iOS always bundled the all-surfaces entry, so a
# deposit-only host still shipped the bet slip's JavaScript, and the measured cost of the
# second feature was native code only.
FEATURES="${FIGHTDECK_FEATURES:-all}"
case "$FEATURES" in
    runtime) ENTRY="src/runtime/index.runtime.js" ;;
    deposit) ENTRY="src/runtime/index.deposit.js" ;;
    both)    ENTRY="src/runtime/index.js" ;;
    all)     ENTRY="src/runtime/index.all.js" ;;
    *)
        echo "error: FIGHTDECK_FEATURES must be runtime, deposit, both or all (got '$FEATURES')" >&2
        exit 1
        ;;
esac

echo "Bundling JS runtime — features: $FEATURES (entry $ENTRY)"
mkdir -p "$ROOT/ios/Resources" "$ROOT/ios/.jsbundle-staging"

# Staged outside Resources/ because the podspec ships that whole directory. FightDeckRNHost
# prefers the Hermes bytecode and only falls back to the text bundle, and the fallback cannot
# fire — this script errors out when hermesc is missing. Shipping both put 0.9 MB of
# never-read JavaScript into every build.
JSBUNDLE="$ROOT/ios/.jsbundle-staging/fightdeck.jsbundle"

(cd "$ROOT" && npm install --silent)
(cd "$ROOT" && npx react-native bundle \
    --platform ios \
    --dev false \
    --entry-file "$ENTRY" \
    --bundle-output "$JSBUNDLE" \
    --assets-dest ios/Resources)

HERMESC=""
for candidate in \
    "$ROOT/node_modules/hermes-compiler/hermesc/osx-bin/hermesc" \
    "$ROOT/node_modules/react-native/sdks/hermesc/osx-bin/hermesc" \
    "$(command -v hermesc 2>/dev/null)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
        HERMESC="$candidate"
        break
    fi
done

if [[ -z "$HERMESC" || ! -f "$JSBUNDLE" ]]; then
    echo "error: hermesc or jsbundle missing — cannot produce Hermes bytecode" >&2
    exit 1
fi

"$HERMESC" -O -emit-binary \
    -out "$ROOT/ios/Resources/fightdeck.hbc" \
    "$JSBUNDLE"

# A text bundle left behind by an older build would still be picked up by the podspec's
# Resources/* glob and shipped alongside the bytecode.
rm -f "$ROOT/ios/Resources/fightdeck.jsbundle"

# Stamped so the Podfile can refuse a host/SDK feature mismatch. Without it, building the SDK
# for one feature set and the host for another produces a working app with a quietly wrong
# size, which is the exact failure this repository exists to measure. Kept out of Resources/
# because the podspec ships that whole directory into the app.
printf '%s\n' "$FEATURES" > "$ROOT/ios/.fightdeck-features"

bundle_bytes="$(stat -f%z "$JSBUNDLE" 2>/dev/null || stat -c%s "$JSBUNDLE")"
hbc_bytes="$(stat -f%z "$ROOT/ios/Resources/fightdeck.hbc" 2>/dev/null \
    || stat -c%s "$ROOT/ios/Resources/fightdeck.hbc")"
echo "JS bundle: $bundle_bytes bytes · Hermes bytecode: $hbc_bytes bytes"
