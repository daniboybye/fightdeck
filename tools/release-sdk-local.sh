#!/usr/bin/env bash
# Local release orchestrator — builds SDK artifacts, checksums them, stages for file://
# or http://localhost consumption, and prints Package.swift binary-target snippets.
#
# Usage: tools/release-sdk-local.sh {rn|skip}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPROACH="${1:-}"

if [[ "$APPROACH" != "rn" && "$APPROACH" != "skip" ]]; then
    echo "usage: $0 {rn|skip}" >&2
    exit 1
fi

case "$APPROACH" in
    rn) APPROACH_DIR="$ROOT/03-sdk-rn" ;;
    skip) APPROACH_DIR="$ROOT/04-sdk-skip" ;;
    *) echo "usage: $0 {rn|skip}" >&2; exit 1 ;;
esac

STAGING="$ROOT/tools/out/release/$APPROACH"
MANIFEST="$ROOT/tools/out/release-manifest-$APPROACH.json"
SDK_VERSION="0.1.0"
RELEASE_BASE="http://127.0.0.1:8765"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$(dirname "$MANIFEST")"

echo "=== Building $APPROACH SDK artifacts ==="
export FIGHTDECK_LOCAL_SDK=1
for module in core deposit betslip; do
    mod_dir="$APPROACH_DIR/sdks/$module"
    echo "--- $module: xcframework ---"
    (cd "$mod_dir" && chmod +x ./build-xcframework.sh && ./build-xcframework.sh)
    echo "--- $module: aar ---"
    (cd "$mod_dir" && chmod +x ./build-aar.sh && ./build-aar.sh)
done

echo "=== Staging artifacts ==="
find "$APPROACH_DIR/sdks" -maxdepth 3 -path "*/out/*.xcframework.zip" -exec cp {} "$STAGING/" \;

if [[ "$APPROACH" == "skip" ]]; then
    cp "$APPROACH_DIR/sdks/deposit/out/"*.aar "$STAGING/"
    cp "$APPROACH_DIR/sdks/betslip/out/FightDeckBetslip-release.aar" "$STAGING/"
elif [[ "$APPROACH" == "rn" ]]; then
    cp "$APPROACH_DIR/sdks/core/out/"*.aar "$STAGING/"
    cp "$APPROACH_DIR/sdks/deposit/out/DepositSDK.aar" "$STAGING/"
    cp "$APPROACH_DIR/sdks/betslip/out/BetslipSDK.aar" "$STAGING/"
fi

if [[ "$APPROACH" == "rn" ]]; then
    VENDOR="$STAGING/ios-vendor"
    mkdir -p "$VENDOR/runtime" "$VENDOR/deposit" "$VENDOR/betslip"
    for zip in "$STAGING"/FightDeckRNRuntime.xcframework.zip; do
        rm -rf "$VENDOR/runtime"/* && unzip -q "$zip" -d "$VENDOR/runtime"
    done
    unzip -qo "$STAGING/DepositSDK.xcframework.zip" -d "$VENDOR/deposit"
    unzip -qo "$STAGING/BetslipSDK.xcframework.zip" -d "$VENDOR/betslip"

    cat > "$VENDOR/FightDeckRNVendor.podspec" <<'RUBY'
Pod::Spec.new do |s|
  s.name         = 'FightDeckRNVendor'
  s.version      = '0.1.0'
  s.summary      = 'Pinned FightDeck RN runtime distribution'
  s.homepage     = 'https://github.com/fightdeck/fightdeck'
  s.license      = { type: 'MIT' }
  s.author       = { 'FightDeck' => 'demo@fightdeck.dev' }
  s.platforms    = { ios: '26.0' }
  s.source       = { :path => '.' }
  s.vendored_frameworks = [
    'runtime/FightDeckRNRuntime.xcframework',
    'runtime/BundledFrameworks/React.xcframework',
    'runtime/BundledFrameworks/hermesvm.xcframework',
    'runtime/BundledFrameworks/ReactNativeDependencies.xcframework',
  ]
  s.resources = ['runtime/Resources/fightdeck.hbc']
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC',
  }
end
RUBY

    cat > "$VENDOR/DepositSDKVendor.podspec" <<'RUBY'
Pod::Spec.new do |s|
  s.name         = 'DepositSDKVendor'
  s.version      = '0.1.0'
  s.summary      = 'Pinned FightDeck deposit SDK'
  s.homepage     = 'https://github.com/fightdeck/fightdeck'
  s.license      = { type: 'MIT' }
  s.author       = { 'FightDeck' => 'demo@fightdeck.dev' }
  s.platforms    = { ios: '26.0' }
  s.source       = { :path => '.' }
  s.vendored_frameworks = 'deposit/DepositSDK.xcframework'
  s.dependency 'FightDeckRNVendor'
end
RUBY

    cat > "$VENDOR/BetslipSDKVendor.podspec" <<'RUBY'
Pod::Spec.new do |s|
  s.name         = 'BetslipSDKVendor'
  s.version      = '0.1.0'
  s.summary      = 'Pinned FightDeck betslip SDK'
  s.homepage     = 'https://github.com/fightdeck/fightdeck'
  s.license      = { type: 'MIT' }
  s.author       = { 'FightDeck' => 'demo@fightdeck.dev' }
  s.platforms    = { ios: '26.0' }
  s.source       = { :path => '.' }
  s.vendored_frameworks = 'betslip/BetslipSDK.xcframework'
  s.dependency 'FightDeckRNVendor'
end
RUBY
fi

echo "=== Checksums ==="
python3 - "$MANIFEST" "$STAGING" "$APPROACH" "$SDK_VERSION" <<'PY'
import json, os, subprocess, sys

manifest_path, staging, approach, version = sys.argv[1:5]
entries = []

for name in sorted(os.listdir(staging)):
    path = os.path.join(staging, name)
    if not os.path.isfile(path):
        continue
    if not (name.endswith(".zip") or name.endswith(".aar")):
        continue
    size = os.path.getsize(path)
    if name.endswith(".xcframework.zip"):
        checksum = subprocess.check_output(
            ["swift", "package", "compute-checksum", path], text=True
        ).strip()
    else:
        checksum = subprocess.check_output(
            ["shasum", "-a", "256", path], text=True
        ).split()[0]
    entries.append({
        "filename": name,
        "bytes": size,
        "checksum": checksum,
    })

with open(manifest_path, "w", encoding="utf-8") as fh:
    json.dump({
        "approach": approach,
        "version": version,
        "artifacts": entries,
    }, fh, indent=2)

for item in entries:
    print(f"{item['filename']}: {item['bytes']} bytes  sha256={item['checksum']}")
PY

echo ""
echo "=== Package.swift snippets (FIGHTDECK_RELEASE_BASE_URL=$RELEASE_BASE) ==="
python3 - "$MANIFEST" "$RELEASE_BASE" <<'PY'
import json, sys

manifest = json.load(open(sys.argv[1]))
base = sys.argv[2]
for item in manifest["artifacts"]:
    if not item["filename"].endswith(".xcframework.zip"):
        continue
    name = item["filename"].removesuffix(".xcframework.zip")
    print(f'.binaryTarget(name: "{name}Binary",')
    print(f'              url: "{base}/{item["filename"]}",')
    print(f'              checksum: "{item["checksum"]}"),')
    print()
PY

echo "Artifacts staged under: $STAGING"
echo "Manifest: $MANIFEST"
echo ""
echo "Serve for pinned verification:"
echo "  cd $ROOT/tools/out/release && python3 -m http.server 8765"
echo "  export FIGHTDECK_RELEASE_BASE_URL=http://127.0.0.1:8765/$APPROACH  # SPM requires HTTPS in production"
echo "  export FIGHTDECK_RELEASE_PATH=1  # local pinned iOS without GitHub HTTPS"
echo "  unset FIGHTDECK_LOCAL_SDK"
