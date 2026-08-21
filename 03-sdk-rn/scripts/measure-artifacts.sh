#!/usr/bin/env bash
# Measure RN-linked artifact sizes for 03-sdk-rn (Pods / Gradle host path).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_ARCHIVE="${1:-/tmp/fightdeck-rn.xcarchive}"
ANDROID_APK="${2:-$ROOT/android/app/build/outputs/apk/release/app-release-unsigned.apk}"

bytes() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }
kb() { echo "scale=1; $1 / 1024" | bc; }
mb() { echo "scale=2; $1 / 1024 / 1024" | bc; }

echo "=== JS bundle (sdks/core/ios/Resources) ==="
JSB="$ROOT/sdks/core/ios/Resources/fightdeck.jsbundle"
HBC="$ROOT/sdks/core/ios/Resources/fightdeck.hbc"
echo "Metro .jsbundle: $(bytes "$JSB") bytes ($(kb "$(bytes "$JSB")") KB)"
echo "Hermes .hbc:     $(bytes "$HBC") bytes ($(kb "$(bytes "$HBC")") KB)"

if [[ -d "$IOS_ARCHIVE/Products/Applications/FightDeck.app" ]]; then
  APP="$IOS_ARCHIVE/Products/Applications/FightDeck.app"
  echo ""
  echo "=== iOS Release archive ($IOS_ARCHIVE) ==="
  echo "App payload: $(du -sk "$APP" | awk '{print $1 * 1024}') bytes ($(mb "$(du -sk "$APP" | awk '{print $1 * 1024}')") MB)"
  echo "Frameworks:  $(du -sk "$APP/Frameworks" 2>/dev/null | awk '{print $1 * 1024}') bytes"
  du -sh "$APP/Frameworks"/* 2>/dev/null | sort -hr || true
  echo "Main executable: $(bytes "$APP/FightDeck") bytes"
  echo "Bundled hbc in app: $(bytes "$APP/FightDeckRNRuntime.bundle/fightdeck.hbc") bytes"
fi

DD="$(ls -d ~/Library/Developer/Xcode/DerivedData/FightDeck-*/Build/Intermediates.noindex/ArchiveIntermediates/FightDeck/IntermediateBuildFilesPath/UninstalledProducts/iphoneos 2>/dev/null | head -1)"
if [[ -n "$DD" && -f "$DD/libFightDeckRNRuntime.a" ]]; then
  echo ""
  echo "=== iOS SDK static libs (Release device, from last archive) ==="
  for lib in libFightDeckRNRuntime libDepositSDK libBetslipSDK; do
    f="$DD/${lib}.a"
    [[ -f "$f" ]] && echo "$lib: $(bytes "$f") bytes ($(kb "$(bytes "$f")") KB)"
  done
fi

if [[ -f "$ANDROID_APK" ]]; then
  echo ""
  echo "=== Android release APK ($ANDROID_APK) ==="
  echo "Universal APK: $(bytes "$ANDROID_APK") bytes ($(mb "$(bytes "$ANDROID_APK")") MB)"
  ARM64=$(unzip -l "$ANDROID_APK" | awk '/lib\/arm64-v8a\// {sum+=$1} END {print sum+0}')
  BUNDLE=$(unzip -l "$ANDROID_APK" | awk '/assets\/index.android.bundle/ {print $1; exit}')
  echo "arm64-v8a .so total: $ARM64 bytes ($(mb "$ARM64") MB)"
  echo "index.android.bundle: ${BUNDLE:-0} bytes ($(kb "${BUNDLE:-0}") KB)"
  echo "RN/Hermes arm64 libs:"
  unzip -l "$ANDROID_APK" | awk '/lib\/arm64-v8a\/(libreactnative|libhermesvm|libjsi|libhermestooling)\.so/ {printf "  %s %s\n", $1, $4}'
fi

echo ""
echo "=== Android SDK adapter AARs (release lint stubs) ==="
for mod in core/android/runtime deposit/android betslip/android; do
  aar="$ROOT/sdks/$mod/build/intermediates/local_aar_for_lint/release/out.aar"
  [[ -f "$aar" ]] && echo "$(basename $(dirname $(dirname $(dirname $(dirname $aar))))): $(bytes "$aar") bytes"
done
