#!/usr/bin/env bash
# Builds the RN source pods once per architecture, then packages local binary SDKs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="$ROOT/../ios"
PODS="$HOST/Pods"
BUILD="$ROOT/.build/apple-pods"
VENDOR="$ROOT/out/ios-vendor"
MODULES=(FightDeckRNRuntime DepositSDK BetslipSDK FighterSDK)

# shellcheck source=_scripts/ios-rn-bundle.sh
source "$ROOT/_scripts/ios-rn-bundle.sh"

"$ROOT/core/build-jsbundle.sh"
(cd "$HOST" && FIGHTDECK_BUILDING_SDK=1 pod install)

for attempt in 1 2 3; do
  rm -rf "$BUILD" && break
  if [[ "$attempt" == 3 ]]; then
    echo "error: could not clean $BUILD" >&2
    exit 1
  fi
  sleep 1
done
mkdir -p "$BUILD"

NODE_ENV_LOCAL="$HOST/.xcode.env.local"
NODE_ENV_BACKUP="$BUILD/.xcode.env.local.backup"
if [[ -f "$NODE_ENV_LOCAL" ]]; then
  cp "$NODE_ENV_LOCAL" "$NODE_ENV_BACKUP"
fi
restore_node_env() {
  if [[ -f "$NODE_ENV_BACKUP" ]]; then
    cp "$NODE_ENV_BACKUP" "$NODE_ENV_LOCAL"
  else
    rm -f "$NODE_ENV_LOCAL"
  fi
}
trap restore_node_env EXIT

cat > "$NODE_ENV_LOCAL" <<ENV
export FIGHTDECK_REAL_NODE="$(command -v node)"
export NODE_BINARY="$ROOT/_scripts/node-pod-build.sh"
ENV

build_slice() {
  local label="$1"
  local sdk="$2"
  local destination="$3"
  local arch="$4"

  xcodebuild build \
    -jobs 1 \
    -project "$PODS/Pods.xcodeproj" \
    -scheme Pods-FightDeckHosts-FightDeck \
    -configuration Release \
    -sdk "$sdk" \
    -destination "$destination" \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS="$arch" \
    CODE_SIGNING_ALLOWED=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    BUILD_DIR="$BUILD/$label" \
    >/dev/null
}

build_slice ios-arm64 iphoneos 'generic/platform=iOS' arm64
build_slice sim-arm64 iphonesimulator 'generic/platform=iOS Simulator' arm64
build_slice sim-x86_64 iphonesimulator 'generic/platform=iOS Simulator' x86_64

write_framework_info() {
  local framework="$1"
  local module="$2"
  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${module}</string>
  <key>CFBundleIdentifier</key><string>dev.fightdeck.${module}</string>
  <key>CFBundleName</key><string>${module}</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST
}

make_framework() {
  local framework="$1"
  local module="$2"
  local library="$3"
  shift 3

  rm -rf "$framework"
  mkdir -p "$framework/Modules/${module}.swiftmodule"
  cp "$library" "$framework/$module"
  while (($#)); do
    cp -R "$1/." "$framework/Modules/${module}.swiftmodule/"
    shift
  done
  # Binary .swiftmodule files capture absolute search paths from the packaging build.
  # Keep the stable .swiftinterface files so consumers resolve dependencies in their host.
  rm -f "$framework/Modules/${module}.swiftmodule/"*.swiftmodule
  write_framework_info "$framework" "$module"
}

package_module() {
  local module="$1"
  local module_root="$ROOT/${module/FightDeckRNRuntime/core}"
  module_root="${module_root/DepositSDK/deposit}"
  module_root="${module_root/BetslipSDK/betslip}"
  module_root="${module_root/FighterSDK/fighter}"
  local out="$module_root/out"
  local frameworks="$BUILD/frameworks/$module"
  local ios_product="$BUILD/ios-arm64/Release-iphoneos/$module"
  local sim_arm_product="$BUILD/sim-arm64/Release-iphonesimulator/$module"
  local sim_x64_product="$BUILD/sim-x86_64/Release-iphonesimulator/$module"
  local ios_library="$ios_product/lib${module}.a"
  local sim_arm_library="$sim_arm_product/lib${module}.a"
  local sim_x64_library="$sim_x64_product/lib${module}.a"

  rm -rf "$out"
  mkdir -p "$out" "$frameworks"
  if [[ "$module" == "FightDeckRNRuntime" ]]; then
    libtool -static -o "$frameworks/lib${module}-ios.a" \
      "$ios_library" \
      "$BUILD/ios-arm64/Release-iphoneos/ReactAppDependencyProvider/libReactAppDependencyProvider.a" \
      "$BUILD/ios-arm64/Release-iphoneos/ReactCodegen/libReactCodegen.a"
    libtool -static -o "$frameworks/lib${module}-sim-arm64.a" \
      "$sim_arm_library" \
      "$BUILD/sim-arm64/Release-iphonesimulator/ReactAppDependencyProvider/libReactAppDependencyProvider.a" \
      "$BUILD/sim-arm64/Release-iphonesimulator/ReactCodegen/libReactCodegen.a"
    libtool -static -o "$frameworks/lib${module}-sim-x86_64.a" \
      "$sim_x64_library" \
      "$BUILD/sim-x86_64/Release-iphonesimulator/ReactAppDependencyProvider/libReactAppDependencyProvider.a" \
      "$BUILD/sim-x86_64/Release-iphonesimulator/ReactCodegen/libReactCodegen.a"
    ios_library="$frameworks/lib${module}-ios.a"
    sim_arm_library="$frameworks/lib${module}-sim-arm64.a"
    sim_x64_library="$frameworks/lib${module}-sim-x86_64.a"
  fi
  lipo -create \
    "$sim_arm_library" \
    "$sim_x64_library" \
    -output "$frameworks/lib${module}-simulator.a"

  make_framework "$frameworks/ios/${module}.framework" "$module" \
    "$ios_library" \
    "$ios_product/${module}.swiftmodule"
  make_framework "$frameworks/simulator/${module}.framework" "$module" \
    "$frameworks/lib${module}-simulator.a" \
    "$sim_arm_product/${module}.swiftmodule" \
    "$sim_x64_product/${module}.swiftmodule"

  for framework in "$frameworks/ios/${module}.framework" "$frameworks/simulator/${module}.framework"; do
    mkdir -p "$framework/Headers"
    cp "$PODS/Target Support Files/$module/${module}-umbrella.h" "$framework/Headers/"
    sed 's/^module /framework module /' \
      "$PODS/Target Support Files/$module/${module}.modulemap" \
      > "$framework/Modules/module.modulemap"
    if [[ "$module" == "FightDeckRNRuntime" ]]; then
      cp "$ROOT/core/ios/Pod/"*.h "$framework/Headers/"
    fi
  done

  xcodebuild -create-xcframework \
    -allow-internal-distribution \
    -framework "$frameworks/ios/${module}.framework" \
    -framework "$frameworks/simulator/${module}.framework" \
    -output "$out/${module}.xcframework"

  (cd "$out" && zip -rq "${module}.xcframework.zip" "${module}.xcframework")
}

for module in "${MODULES[@]}"; do
  package_module "$module"
done

cp -R "$ROOT/core/out/FightDeckRNRuntime.xcframework" "$BUILD/"
bundle_rn_ios_distribution \
  "$ROOT/core/out" \
  FightDeckRNRuntime \
  "$BUILD/FightDeckRNRuntime.xcframework" \
  "$ROOT/core/ios/Resources/fightdeck.hbc" \
  "$PODS"

OLD_VENDOR="${VENDOR}.old.$$"
if [[ -d "$VENDOR" ]]; then
  mv "$VENDOR" "$OLD_VENDOR"
fi
mkdir -p "$VENDOR/runtime" "$VENDOR/deposit" "$VENDOR/betslip" "$VENDOR/fighter"
cp -R "$ROOT/core/out/FightDeckRNRuntime.xcframework" "$VENDOR/runtime/"
cp -R "$ROOT/core/out/BundledFrameworks" "$VENDOR/runtime/"
cp -R "$ROOT/core/out/Resources" "$VENDOR/runtime/"
cp -R "$ROOT/deposit/out/DepositSDK.xcframework" "$VENDOR/deposit/"
cp -R "$ROOT/betslip/out/BetslipSDK.xcframework" "$VENDOR/betslip/"
cp -R "$ROOT/fighter/out/FighterSDK.xcframework" "$VENDOR/fighter/"

cat > "$VENDOR/FightDeckRNRuntime.podspec" <<'RUBY'
Pod::Spec.new do |s|
  s.name = 'FightDeckRNRuntime'
  s.version = '0.1.0'
  s.summary = 'Local FightDeck RN runtime binary'
  s.homepage = 'https://github.com/fightdeck/fightdeck'
  s.license = { type: 'MIT' }
  s.author = { 'FightDeck' => 'demo@fightdeck.dev' }
  s.platforms = { ios: '26.0' }
  s.source = { :path => '.' }
  s.vendored_frameworks = [
    'runtime/FightDeckRNRuntime.xcframework',
    'runtime/BundledFrameworks/React.xcframework',
    'runtime/BundledFrameworks/hermesvm.xcframework',
    'runtime/BundledFrameworks/ReactNativeDependencies.xcframework',
  ]
  s.resources = ['runtime/Resources/fightdeck.hbc']
  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
end
RUBY

write_feature_podspec() {
  local pod="$1"
  local directory="$2"
  cat > "$VENDOR/${pod}.podspec" <<RUBY
Pod::Spec.new do |s|
  s.name = '${pod}'
  s.version = '0.1.0'
  s.summary = 'Local ${pod} binary'
  s.homepage = 'https://github.com/fightdeck/fightdeck'
  s.license = { type: 'MIT' }
  s.author = { 'FightDeck' => 'demo@fightdeck.dev' }
  s.platforms = { ios: '26.0' }
  s.source = { :path => '.' }
  s.vendored_frameworks = '${directory}/${pod}.xcframework'
  s.dependency 'FightDeckRNRuntime'
end
RUBY
}

write_feature_podspec DepositSDK deposit
write_feature_podspec BetslipSDK betslip
write_feature_podspec FighterSDK fighter

restore_node_env
trap - EXIT
(cd "$HOST" && pod install)
rm -rf "$OLD_VENDOR" 2>/dev/null || true
echo "RN Apple SDKs -> $VENDOR"
