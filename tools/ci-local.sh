#!/usr/bin/env bash
#
# Local CI harness — mirrors .github/workflows/ on this Mac without spending Actions minutes.
#
# shellcheck disable=SC2329
#   ./tools/ci-local.sh contract
#   ./tools/ci-local.sh sdk-rn
#   ./tools/ci-local.sh sdk-skip
#   ./tools/ci-local.sh ios 03-sdk-rn
#   ./tools/ci-local.sh android 04-sdk-skip
#   ./tools/ci-local.sh measure
#   ./tools/ci-local.sh release-sdk skip 0.1.0 --artifacts-dir /path/to/zips
#   ./tools/ci-local.sh all
#
# By default the repo is copied into a fresh temp directory so stale AARs and dylibs cannot
# mask a break. Pass --in-place to run against the current checkout (faster, less honest).
#
# A target whose prerequisites are missing is reported as SKIP with the command that would
# install them, not silently treated as pass.

set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN_PLACE=0
SKIP_TESTS=0
ARTIFACTS_DIR=""
TARGET=""
TARGET_ARGS=()

declare -a RESULT_LABELS=()
declare -a RESULT_OUTCOMES=()

usage() {
    cat <<'EOF'
usage: tools/ci-local.sh [options] <target> [args...]

options:
  --in-place              Run in the current checkout instead of a pristine copy
  --skip-tests            Skip unit-test steps (ios, android, measure)
  --artifacts-dir PATH    Pre-built zips/AARs for release-sdk (skips SDK rebuild)

targets:
  contract                contract.yml (Swift + Rust + native baseline)
  sdk-core-swift [part]   sdk-core-swift.yml — apple | android | all (default all)
  sdk-core-rust [part]    sdk-core-rust.yml — apple | android | wasm | all
  sdk-rn [part]           sdk-rn.yml — apple | android | all
  sdk-skip [part]         sdk-skip.yml — apple | android | all
  ios APPROACH            _ios-app.yml for one approach (00-native … 04-sdk-skip)
  android APPROACH        _android-app.yml for one approach
  measure                 measure.yml (all apps + contract + receipt render)
  measure-receipt         measure.yml receipt job only (needs tools/out/*.json)
  release-sdk SDK [VER]   release-sdk.yml checksum/staging — SDK is rn or skip
  all                     Every target that can run on macOS

examples:
  ./tools/ci-local.sh contract
  ./tools/ci-local.sh --in-place sdk-skip android
  ./tools/ci-local.sh release-sdk skip 0.1.0 --artifacts-dir /tmp/fd-skip/04-sdk-skip/sdks
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --in-place)
            IN_PLACE=1
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="${2:?--artifacts-dir requires a path}"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ -z "$TARGET" ]]; then
                TARGET="$1"
            else
                TARGET_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    usage >&2
    exit 1
fi

record() {
    RESULT_LABELS+=("$1")
    RESULT_OUTCOMES+=("$2")
}

run_step() {
    local label="$1"
    shift
    echo ""
    echo "======== $label ========"
    if "$@"; then
        record "$label" "PASS"
    else
        record "$label" "FAIL"
        return 1
    fi
}

skip_step() {
    local label="$1"
    local reason="$2"
    echo ""
    echo "======== $label ========"
    echo "SKIP: $reason"
    record "$label" "SKIP"
}

guard_file() {
    local path="$1"
    local notice="${2:-missing $path}"
    if [[ ! -f "$path" ]]; then
        echo "::notice::$notice"
        return 1
    fi
}

guard_ios_app() {
    local project_dir="$1"
    if [[ ! -d "$project_dir" ]]; then
        return 1
    fi
    [[ -n "$(find "$project_dir" -maxdepth 2 \( -name '*.xcodeproj' -o -name 'Package.swift' \) 2>/dev/null)" ]]
}

guard_android_app() {
    [[ -f "${1}/gradlew" ]]
}

pin_xcode() {
    local xcode_version
    xcode_version="$(./tools/versions.py apple.xcode)"
    echo "Pinned Xcode: $xcode_version"
    if [[ -d "/Applications/Xcode_${xcode_version}.app" ]]; then
        xcode-select -p | grep -q "Xcode_${xcode_version}" \
            || sudo xcode-select -switch "/Applications/Xcode_${xcode_version}.app" 2>/dev/null \
            || echo "::warning::Xcode ${xcode_version} not selected; using $(xcode-select -p)"
    else
        echo "::warning::Xcode ${xcode_version} not found at expected path; using runner default"
    fi
    xcodebuild -version
}

ensure_rust() {
    local toolchain
    toolchain="$(./tools/versions.py rust.toolchain)"
    if ! command -v rustup >/dev/null 2>&1; then
        echo "rustup is not installed" >&2
        return 1
    fi
    rustup toolchain install "$toolchain" --profile minimal 2>/dev/null || true
    export RUSTUP_TOOLCHAIN="$toolchain"
}

ensure_xcbeautify() {
    command -v xcbeautify >/dev/null 2>&1 || brew install xcbeautify
}

install_skip_cli() {
    local skip_version
    skip_version="$(./tools/versions.py skip.skipstone)"
    local tmp="${TMPDIR:-/tmp}/fightdeck-skip-$$"
    mkdir -p "$tmp"
    curl -fsSL -o "$tmp/skip.zip" \
        "https://github.com/skiptools/skip/releases/download/${skip_version}/skip-macos.zip"
    unzip -q "$tmp/skip.zip" -d "$tmp"
    chmod +x "$tmp/skip.artifactbundle/bin/skip" "$tmp/skip.artifactbundle/macos/skip"
    export PATH="$tmp/skip.artifactbundle/bin:$PATH"
    skip version
}

install_rn_deps() {
    local node_version
    node_version="$(./tools/versions.py react_native.node)"
    if command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env)"
        fnm use "$node_version" 2>/dev/null || fnm install "$node_version"
    elif command -v nvm >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
        nvm use "$node_version" 2>/dev/null || nvm install "$node_version"
    fi
    (cd 03-sdk-rn/sdks/core && npm ci)
}

install_rn_pods() {
    pod --version >/dev/null 2>&1 || sudo gem install cocoapods --no-document
    (cd 03-sdk-rn/ios && pod install)
}

ensure_cargo_ndk() {
    local version
    version="$(./tools/versions.py rust.cargo_ndk)"
    cargo install cargo-ndk --version "$version" --locked 2>/dev/null \
        || cargo install cargo-ndk --version "$version" --locked --force
}

# --- contract.yml -----------------------------------------------------------------

run_contract_swift() {
    guard_file 01-core-swift/sdks/core/Package.swift "Swift core not written yet" \
        || return 0
    (cd 01-core-swift/sdks/core && swift test --parallel)
}

run_contract_rust() {
    guard_file 02-core-rust/sdks/core/Cargo.toml "Rust core not written yet" \
        || return 0
    ensure_rust
    (cd 02-core-rust/sdks/core && cargo test --release)
}

run_contract_native() {
    guard_ios_app 00-native/ios || return 0
    # FightDeckUITests is a screenshot helper, not a gate, and the workflow skips it too —
    # running it here is what made a green pipeline report a red contract check.
    (cd 00-native/ios && xcodebuild test \
        -scheme FightDeck \
        -skip-testing:FightDeckUITests \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        CODE_SIGNING_ALLOWED=NO)
}

run_contract() {
    run_step "contract/swift" run_contract_swift || true
    run_step "contract/rust" run_contract_rust || true
    run_step "contract/native-baseline" run_contract_native || true
}

# --- sdk-core-swift.yml -----------------------------------------------------------

run_sdk_core_swift_apple() {
    guard_file 01-core-swift/sdks/core/Package.swift || return 0
    pin_xcode
    (cd 01-core-swift/sdks/core && swift test)
    (cd 01-core-swift/sdks/core && ./build-xcframework.sh)
}

# Xcode's Swift cannot use a cross-compilation Swift SDK: the bundle's Foundation was built
# by the open-source 6.3.3 and, identical version number notwithstanding, the module format
# differs. swiftly installs that toolchain beside Xcode's without displacing the `swift` in
# PATH, which turns this from a CI-only job into a ten-second local one.
swift_android_blocker() {
    local pinned sdk_name ndk
    pinned="$(./tools/versions.py apple.swift)"
    sdk_name="$(./tools/versions.py apple.swift_sdks.android)"
    ndk="$(./tools/versions.py android.ndk)"

    if ! command -v swiftly >/dev/null 2>&1; then
        echo "swiftly is not installed — brew install swiftly"
        return 0
    fi
    if ! swiftly list 2>/dev/null | grep -q "Swift ${pinned}"; then
        echo "open-source Swift ${pinned} is missing, and Xcode's cannot cross-compile — swiftly install ${pinned}"
        return 0
    fi
    if [[ -z "$(swift_sdk_bundle "$sdk_name")" ]]; then
        echo "the Swift SDK for Android is not installed — see 01-core-swift/README.md"
        return 0
    fi
    if [[ ! -d "$(android_sdk_home)/ndk/${ndk}" ]]; then
        echo "NDK ${ndk} is missing under $(android_sdk_home)/ndk"
        return 0
    fi
    return 1
}

swift_sdk_bundle() {
    find "$HOME/.swiftpm/swift-sdks" "$HOME/.config/swiftpm/swift-sdks" \
        "$HOME/Library/org.swift.swiftpm/swift-sdks" \
        -maxdepth 1 -name "${1}.artifactbundle" 2>/dev/null | head -1 || true
}

android_sdk_home() {
    echo "${ANDROID_HOME:-$HOME/Library/Android/sdk}"
}

run_sdk_core_swift_android() {
    guard_file 01-core-swift/sdks/core/Package.swift || return 0
    local pinned ndk
    pinned="$(./tools/versions.py apple.swift)"
    ndk="$(./tools/versions.py android.ndk)"
    (
        cd 01-core-swift/sdks/core
        ANDROID_NDK_HOME="$(android_sdk_home)/ndk/${ndk}" \
            swiftly run ./build-aar.sh "+${pinned}"
    )
}

step_sdk_core_swift_android() {
    local blocker
    if blocker="$(swift_android_blocker)"; then
        skip_step "sdk-core-swift/android" "$blocker"
    else
        run_step "sdk-core-swift/android" run_sdk_core_swift_android || true
    fi
}

run_sdk_core_swift() {
    local part="${1:-all}"
    case "$part" in
        apple) run_step "sdk-core-swift/apple" run_sdk_core_swift_apple || true ;;
        android) step_sdk_core_swift_android ;;
        all)
            run_step "sdk-core-swift/apple" run_sdk_core_swift_apple || true
            step_sdk_core_swift_android
            ;;
        *)
            echo "unknown sdk-core-swift part: $part" >&2
            return 1
            ;;
    esac
}

# --- sdk-core-rust.yml --------------------------------------------------------------

run_sdk_core_rust_apple() {
    guard_file 02-core-rust/sdks/core/Cargo.toml || return 0
    ensure_rust
    rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios 2>/dev/null || true
    (cd 02-core-rust/sdks/core && ./build-xcframework.sh)
}

run_sdk_core_rust_android() {
    guard_file 02-core-rust/sdks/core/Cargo.toml || return 0
    ensure_rust
    rustup target add aarch64-linux-android x86_64-linux-android 2>/dev/null || true
    ensure_cargo_ndk
    (cd 02-core-rust/sdks/core && ./build-aar.sh)
}

run_sdk_core_rust_wasm() {
    guard_file 02-core-rust/sdks/core/Cargo.toml || return 0
    ensure_rust
    rustup target add wasm32-unknown-unknown 2>/dev/null || true
    (
        cd 02-core-rust/sdks/core
        cargo build --release --target wasm32-unknown-unknown
        ls -la target/wasm32-unknown-unknown/release/*.wasm
    )
}

run_sdk_core_rust() {
    local part="${1:-all}"
    case "$part" in
        apple) run_step "sdk-core-rust/apple" run_sdk_core_rust_apple || true ;;
        android) run_step "sdk-core-rust/android" run_sdk_core_rust_android || true ;;
        wasm) run_step "sdk-core-rust/wasm" run_sdk_core_rust_wasm || true ;;
        all)
            run_step "sdk-core-rust/apple" run_sdk_core_rust_apple || true
            run_step "sdk-core-rust/android" run_sdk_core_rust_android || true
            run_step "sdk-core-rust/wasm" run_sdk_core_rust_wasm || true
            ;;
        *)
            echo "unknown sdk-core-rust part: $part" >&2
            return 1
            ;;
    esac
}

# --- sdk-rn.yml -------------------------------------------------------------------

run_sdk_rn_apple_module() {
    local module="$1"
    guard_file "03-sdk-rn/sdks/${module}/package.json" || return 0
    if [[ "$module" == "core" ]]; then
        install_rn_deps
        pod --version >/dev/null 2>&1 || sudo gem install cocoapods --no-document
    fi
    (cd "03-sdk-rn/sdks/${module}" && ./build-xcframework.sh)
}

run_sdk_rn_apple() {
    pin_xcode
    local module
    for module in core deposit betslip; do
        run_step "sdk-rn/apple/${module}" run_sdk_rn_apple_module "$module" || true
    done
}

run_sdk_rn_android_module() {
    local module="$1"
    guard_file "03-sdk-rn/sdks/${module}/package.json" || return 0
    install_rn_deps
    (cd "03-sdk-rn/sdks/${module}" && ./build-aar.sh)
}

run_sdk_rn_android() {
    local module
    for module in core deposit betslip; do
        run_step "sdk-rn/android/${module}" run_sdk_rn_android_module "$module" || true
    done
}

run_sdk_rn() {
    local part="${1:-all}"
    case "$part" in
        apple) run_sdk_rn_apple ;;
        android) run_sdk_rn_android ;;
        all)
            run_sdk_rn_apple
            run_sdk_rn_android
            ;;
        *)
            echo "unknown sdk-rn part: $part" >&2
            return 1
            ;;
    esac
}

# --- sdk-skip.yml -----------------------------------------------------------------

run_sdk_skip_apple_module() {
    local module="$1"
    guard_file "04-sdk-skip/sdks/${module}/Package.swift" || return 0
    export FIGHTDECK_LOCAL_SDK=1
    if [[ "$module" == "core" ]]; then
        (cd 04-sdk-skip/sdks/core && swift test)
    fi
    (cd "04-sdk-skip/sdks/${module}" && ./build-xcframework.sh)
}

run_sdk_skip_apple() {
    pin_xcode
    export FIGHTDECK_LOCAL_SDK=1
    local module
    for module in core deposit betslip; do
        run_step "sdk-skip/apple/${module}" run_sdk_skip_apple_module "$module" || true
    done
}

run_sdk_skip_android() {
    guard_file 04-sdk-skip/sdks/core/Package.swift || return 0
    export FIGHTDECK_LOCAL_SDK=1
    local jdk
    jdk="$(./tools/versions.py android.jdk)"
    if [[ -z "${JAVA_HOME:-}" ]]; then
        if /usr/libexec/java_home -v "$jdk" >/dev/null 2>&1; then
            local java_home
            java_home="$(/usr/libexec/java_home -v "$jdk")"
            export JAVA_HOME="$java_home"
        fi
    fi
    install_skip_cli
    skip checkup --verbose || echo "::warning::skip checkup reported problems"
    ./04-sdk-skip/sdks/build-aars.sh
}

run_sdk_skip() {
    local part="${1:-all}"
    case "$part" in
        apple) run_sdk_skip_apple ;;
        android) run_step "sdk-skip/android" run_sdk_skip_android || true ;;
        all)
            run_sdk_skip_apple
            run_step "sdk-skip/android" run_sdk_skip_android || true
            ;;
        *)
            echo "unknown sdk-skip part: $part" >&2
            return 1
            ;;
    esac
}

# --- _ios-app.yml -----------------------------------------------------------------

run_ios_app() {
    local approach="${1:?usage: ci-local.sh ios <approach>}"
    local project_dir="${approach}/ios"
    local scheme="FightDeck"

    guard_ios_app "$project_dir" || {
        echo "::notice::${project_dir} is not built yet — nothing to do"
        return 0
    }

    pin_xcode
    export FIGHTDECK_LOCAL_SDK=1
    ensure_xcbeautify

    if [[ "$approach" == "03-sdk-rn" ]]; then
        install_rn_deps
        install_rn_pods
    fi

    if [[ "$approach" == "02-core-rust" ]]; then
        ensure_rust
        rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios 2>/dev/null || true
        (cd 02-core-rust/sdks/core && ./build-xcframework.sh)
    fi

    if [[ "$SKIP_TESTS" -eq 0 ]]; then
        (
            cd "$project_dir"
            if [[ ! -d "${scheme}Tests" ]]; then
                echo "::notice::${approach} has no unit test target — nothing to run"
            else
                local -a args=(-scheme "$scheme")
                if [[ -d "${scheme}.xcworkspace" ]]; then
                    args+=(-workspace "${scheme}.xcworkspace")
                fi
                if [[ -d "${scheme}UITests" ]]; then
                    args+=(-skip-testing:"${scheme}UITests")
                fi
                xcodebuild test \
                    "${args[@]}" \
                    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
                    -skipPackagePluginValidation \
                    -skipMacroValidation \
                    CODE_SIGNING_ALLOWED=NO \
                    | xcbeautify
            fi
        )
    fi

    ./tools/measure-ios.sh "$approach" "$project_dir" "$scheme"
}

# --- _android-app.yml --------------------------------------------------------------

android_variant_for() {
    local approach="$1"
    if [[ "$approach" == "03-sdk-rn" || "$approach" == "04-sdk-skip" ]]; then
        echo "bothRelease"
    else
        echo "release"
    fi
}

run_android_app() {
    local approach="${1:?usage: ci-local.sh android <approach>}"
    local project_dir="${approach}/android"
    local module="app"
    local variant
    variant="$(android_variant_for "$approach")"

    guard_android_app "$project_dir" || {
        echo "::notice::${project_dir} has no gradlew yet — nothing to do"
        return 0
    }

    export FIGHTDECK_LOCAL_SDK=1
    local jdk
    jdk="$(./tools/versions.py android.jdk)"
    if [[ -z "${JAVA_HOME:-}" ]]; then
        if /usr/libexec/java_home -v "$jdk" >/dev/null 2>&1; then
            local java_home
            java_home="$(/usr/libexec/java_home -v "$jdk")"
            export JAVA_HOME="$java_home"
        fi
    fi

    local ndk
    ndk="$(./tools/versions.py android.ndk)"
    if [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]]; then
        "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --install "ndk;${ndk}" \
            || echo "::warning::NDK ${ndk} unavailable; falling back to preinstalled"
    fi

    if [[ "$approach" == "03-sdk-rn" ]]; then
        install_rn_deps
    fi

    if [[ "$approach" == "04-sdk-skip" ]]; then
        install_skip_cli
        ./04-sdk-skip/sdks/build-aars.sh
    fi

    if [[ "$approach" == "02-core-rust" ]]; then
        ensure_rust
        rustup target add aarch64-linux-android x86_64-linux-android 2>/dev/null || true
        ensure_cargo_ndk
        (cd 02-core-rust/sdks/core && ./build-aar.sh)
    fi

    if [[ "$SKIP_TESTS" -eq 0 ]]; then
        (cd "$project_dir" && ./gradlew --no-daemon ":${module}:test")
    fi

    ./tools/measure-android.sh "$approach" "$project_dir" "$module" "$variant"
}

# --- measure.yml ------------------------------------------------------------------

run_measure_receipt() {
    echo "Measurement files present:"
    ls -la tools/out/ 2>/dev/null || echo "(none)"
    python3 tools/render-receipt.py > tools/out/receipt.md
    echo "Wrote tools/out/receipt.md ($(wc -l < tools/out/receipt.md) lines)"
    head -20 tools/out/receipt.md
}

run_measure() {
    local approach
    for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
        run_step "measure/ios/${approach}" run_ios_app "$approach" || true
    done
    for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
        run_step "measure/android/${approach}" run_android_app "$approach" || true
    done
    run_contract
    run_step "measure/receipt" run_measure_receipt || true
}

# --- release-sdk.yml publish job --------------------------------------------------

stage_release_artifacts() {
    local sdk="$1"
    local staging="$2"
    rm -rf "$staging"
    mkdir -p "$staging"

    if [[ -n "$ARTIFACTS_DIR" ]]; then
        echo "Staging from --artifacts-dir $ARTIFACTS_DIR"
        find "$ARTIFACTS_DIR" -type f \( -name '*.xcframework.zip' -o -name '*.aar' \) -exec cp {} "$staging/" \;
        return 0
    fi

    export FIGHTDECK_LOCAL_SDK=1
    if [[ "$sdk" == "rn" ]]; then
        run_sdk_rn all
        find 03-sdk-rn/sdks -path '*/out/*.xcframework.zip' -exec cp {} "$staging/" \;
        find 03-sdk-rn/sdks -path '*/out/*.aar' -exec cp {} "$staging/" \;
    elif [[ "$sdk" == "skip" ]]; then
        run_sdk_skip all
        find 04-sdk-skip/sdks -path '*/out/*.xcframework.zip' -exec cp {} "$staging/" \;
        find 04-sdk-skip/sdks -path '*/out/*.aar' -exec cp {} "$staging/" \;
    fi
}

run_release_sdk_checksum() {
    local sdk="${1:?release-sdk requires rn or skip}"
    local version="${2:-0.1.0-local}"
    local staging="$WORK_DIR/release-staging"

    if [[ "$sdk" != "rn" && "$sdk" != "skip" ]]; then
        echo "release-sdk SDK must be rn or skip, got: $sdk" >&2
        return 1
    fi

    stage_release_artifacts "$sdk" "$staging"

    echo "Artifacts staged for release:"
    find "$staging" -type f \( -name '*.zip' -o -name '*.aar' \) -exec ls -lh {} \;

    local zip_count
    zip_count="$(find "$staging" -type f -name '*.xcframework.zip' | wc -l | tr -d ' ')"
    if [[ "$zip_count" -eq 0 ]]; then
        echo "error: no .xcframework.zip files in $staging" >&2
        return 1
    fi

    local snippet_file="${TMPDIR:-/tmp}/fightdeck-snippet-$$.md"
    local base="https://github.com/daniboybye/fightdeck/releases/download/sdk-v${version}"

    {
        echo "## Checksums for \`sdk-v${version}\`"
        echo
        echo "Paste straight into the SDK wrapper's \`Package.swift\`."
        echo
        echo '```swift'
    } > "$snippet_file"

    local zip name sum
    while IFS= read -r zip; do
        name="$(basename "$zip" .xcframework.zip)"
        sum="$(swift package compute-checksum "$zip")"
        {
            echo ".binaryTarget(name: \"${name}\","
            echo "              url: \"${base}/$(basename "$zip")\","
            echo "              checksum: \"${sum}\"),"
        } >> "$snippet_file"
        echo "${name}: ${sum}"
    done < <(find "$staging" -type f -name '*.xcframework.zip' | sort)

    echo '```' >> "$snippet_file"
    echo "Snippet written to $snippet_file"
    cat "$snippet_file"
}

run_release_sdk() {
    local sdk="${TARGET_ARGS[0]:?release-sdk requires rn or skip as the first argument}"
    local version="${TARGET_ARGS[1]:-0.1.0-local}"
    run_step "release-sdk/${sdk}" run_release_sdk_checksum "$sdk" "$version"
}

# --- all --------------------------------------------------------------------------

run_all() {
    run_contract
    run_sdk_core_swift all
    run_sdk_core_rust all
    run_sdk_rn all
    run_sdk_skip all
    local approach
    for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
        run_step "ios/${approach}" run_ios_app "$approach" || true
    done
    for approach in 00-native 01-core-swift 02-core-rust 03-sdk-rn 04-sdk-skip; do
        run_step "android/${approach}" run_android_app "$approach" || true
    done
    if [[ -d tools/out ]] && compgen -G "tools/out/*.json" >/dev/null; then
        run_step "measure-receipt" run_measure_receipt || true
    fi
}

print_summary() {
    local pass=0 fail=0 skip=0
    local i outcome
    echo ""
    echo "==================== CI local summary ===================="
    for i in "${!RESULT_LABELS[@]}"; do
        outcome="${RESULT_OUTCOMES[$i]}"
        printf "  %-40s %s\n" "${RESULT_LABELS[$i]}" "$outcome"
        case "$outcome" in
            PASS) pass=$((pass + 1)) ;;
            FAIL) fail=$((fail + 1)) ;;
            SKIP) skip=$((skip + 1)) ;;
        esac
    done
    echo "--------------------------------------------------------"
    echo "  PASS: $pass   FAIL: $fail   SKIP: $skip"
    echo "========================================================"
    if [[ "$fail" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# --- workspace setup --------------------------------------------------------------

setup_workspace() {
    if [[ "$IN_PLACE" -eq 1 ]]; then
        WORK_DIR="$SOURCE_REPO"
        echo "Running in-place at $WORK_DIR"
        cd "$WORK_DIR"
        return 0
    fi

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fightdeck-ci.XXXXXX")"
    echo "Pristine copy: git clone --local $SOURCE_REPO -> $WORK_DIR"
    git clone --local "$SOURCE_REPO" "$WORK_DIR"
    cd "$WORK_DIR"
}

main() {
    local exit_code=0

    setup_workspace

    case "$TARGET" in
        contract) run_contract ;;
        sdk-core-swift) run_sdk_core_swift "${TARGET_ARGS[0]:-all}" ;;
        sdk-core-rust) run_sdk_core_rust "${TARGET_ARGS[0]:-all}" ;;
        sdk-rn) run_sdk_rn "${TARGET_ARGS[0]:-all}" ;;
        sdk-skip) run_sdk_skip "${TARGET_ARGS[0]:-all}" ;;
        ios)
            run_step "ios/${TARGET_ARGS[0]:?ios requires an approach, e.g. 03-sdk-rn}" \
                run_ios_app "${TARGET_ARGS[0]}" || exit_code=1
            ;;
        android)
            run_step "android/${TARGET_ARGS[0]:?android requires an approach, e.g. 04-sdk-skip}" \
                run_android_app "${TARGET_ARGS[0]}" || exit_code=1
            ;;
        measure) run_measure ;;
        measure-receipt) run_step "measure-receipt" run_measure_receipt || exit_code=1 ;;
        release-sdk) run_release_sdk || exit_code=1 ;;
        all) run_all ;;
        *)
            echo "unknown target: $TARGET" >&2
            usage >&2
            exit 1
            ;;
    esac

    print_summary || exit_code=1
    exit "$exit_code"
}

main
