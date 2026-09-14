#!/usr/bin/env bash
# Bundle React Native + Hermes iOS xcframeworks and Hermes bytecode into a distribution zip.
# The zip root contains the local SDK xcframework plus sibling folders documented in
# LAYOUT.txt that CocoaPods / Xcode must link explicitly.
set -euo pipefail

bundle_rn_ios_distribution() {
    local out_dir="$1"
    local product="$2"
    local xcframework_path="$3"
    local hbc_path="${4:-}"
    local pods_root="${5:-}"

    if [[ ! -d "$xcframework_path" ]]; then
        echo "error: missing xcframework at $xcframework_path" >&2
        exit 1
    fi

    if [[ -z "$pods_root" ]]; then
        pods_root="$(cd "$(dirname "$0")/../../ios/Pods" && pwd)"
    fi

    local react_xc="${pods_root}/React-Core-prebuilt/React.xcframework"
    local hermes_xc="${pods_root}/hermes-engine/destroot/Library/Frameworks/universal/hermesvm.xcframework"
    local deps_xc="${pods_root}/ReactNativeDependencies/framework/packages/react-native/ReactNativeDependencies.xcframework"

    for required in "$react_xc" "$hermes_xc" "$deps_xc"; do
        if [[ ! -d "$required" ]]; then
            echo "error: RN pod artifact missing: $required" >&2
            echo "Run: cd 03-sdk-rn/ios && pod install" >&2
            exit 1
        fi
    done

    rm -rf "$out_dir/${product}.xcframework" "$out_dir/BundledFrameworks" "$out_dir/Resources"
    cp -R "$xcframework_path" "$out_dir/${product}.xcframework"

    mkdir -p "$out_dir/BundledFrameworks" "$out_dir/Resources"
    cp -R "$react_xc" "$out_dir/BundledFrameworks/React.xcframework"
    cp -R "$hermes_xc" "$out_dir/BundledFrameworks/hermesvm.xcframework"
    cp -R "$deps_xc" "$out_dir/BundledFrameworks/ReactNativeDependencies.xcframework"

    if [[ -n "$hbc_path" && -f "$hbc_path" ]]; then
        cp "$hbc_path" "$out_dir/Resources/fightdeck.hbc"
    else
        echo "error: Hermes bytecode missing at ${hbc_path:-<unset>}" >&2
        exit 1
    fi

    cat > "$out_dir/LAYOUT.txt" <<EOF
FightDeck RN iOS distribution layout
====================================

${product}.xcframework.zip contains:

1. ${product}.xcframework/
   SDK adapter (static). SPM binaryTarget extracts this path from the zip root.

2. BundledFrameworks/
   React.xcframework
   hermesvm.xcframework
   ReactNativeDependencies.xcframework
   Link with -framework and embed in the host app. Required for a self-contained SDK.

3. Resources/fightdeck.hbc
   Hermes bytecode bundle. Copy into the ${product} resource bundle at link time.

Consumers must link all BundledFrameworks; the adapter xcframework alone is not runnable.
EOF

    (
        cd "$out_dir"
        rm -f "${product}.xcframework.zip"
        zip -rq "${product}.xcframework.zip" \
            "${product}.xcframework" \
            BundledFrameworks \
            Resources \
            LAYOUT.txt
    )

    local size
    size="$(stat -f%z "$out_dir/${product}.xcframework.zip" 2>/dev/null || stat -c%s "$out_dir/${product}.xcframework.zip")"
    if (( size < 1000000 )); then
        echo "error: ${product}.xcframework.zip is only ${size} bytes — expected bundled RN frameworks" >&2
        exit 1
    fi

    echo "Wrote $out_dir/${product}.xcframework.zip ($(ls -lh "$out_dir/${product}.xcframework.zip" | awk '{print $5}'))"
}
