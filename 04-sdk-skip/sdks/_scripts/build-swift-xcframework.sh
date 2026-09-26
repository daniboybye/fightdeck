#!/usr/bin/env bash

build_swift_xcframework() {
    local root="$1"
    local product="$2"
    local binary_module="$3"
    local minimum_zip_size="$4"
    local out="$root/out"
    # FIGHTDECK_SDK_CONFIGURATION=debug builds the Swift in debug; FIGHTDECK_SDK_ARCHS=arm64 builds
    # the device slice alone, for a host built for a phone. The defaults are what ships.
    local configuration="${FIGHTDECK_SDK_CONFIGURATION:-release}"
    local staging="$out/frameworks"

    export FIGHTDECK_BUILDING_SDK=1

    rm -rf "$out"/*.xcframework "$out"/*.xcframework.zip "$out"/ios-* "$staging"
    mkdir -p "$out"

    build_framework() {
        local sdk="$1"
        local triple="$2"
        local label="$3"
        local sdk_path
        local framework="$staging/$label/${binary_module}.framework"
        local module_dir="$framework/Modules/${binary_module}.swiftmodule"
        sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"

        swift build \
            --package-path "$root" \
            -c "$configuration" \
            --triple "$triple" \
            --sdk "$sdk_path" \
            -Xswiftc -enable-library-evolution \
            -Xswiftc -emit-module-interface \
            >/dev/null

        mkdir -p "$module_dir"
        cp "$root/.build/$triple/$configuration/lib${product}.dylib" \
            "$framework/$binary_module"
        install_name_tool -id \
            "@rpath/${binary_module}.framework/${binary_module}" \
            "$framework/$binary_module"

        if [[ "$binary_module" != "FightDeckCoreBinary" ]]; then
            install_name_tool -change \
                "@rpath/libFightDeckCore.dylib" \
                "@rpath/FightDeckCoreBinary.framework/FightDeckCoreBinary" \
                "$framework/$binary_module"
        fi

        for extension in swiftmodule swiftdoc swiftsourceinfo abi.json swiftinterface private.swiftinterface; do
            local source="$root/.build/$triple/$configuration/Modules/${binary_module}.${extension}"
            if [[ -f "$source" ]]; then
                cp "$source" "$module_dir/${triple}.${extension}"
            fi
        done

        cat > "$framework/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${binary_module}</string>
    <key>CFBundleIdentifier</key>
    <string>com.fightdeck.${binary_module}</string>
    <key>CFBundleName</key>
    <string>${binary_module}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

        printf '%s\n' "$framework"
    }

    local ios_framework
    local sim_framework
    ios_framework="$(build_framework iphoneos arm64-apple-ios ios-arm64)"
    # Simulator: arm64 only. The x86_64 slice was a third of the packaging work and nothing
    # consumes it — this machine is Apple Silicon and so is the macos-26 runner CI uses. A
    # real SDK vendor would still ship it; put the triple back beside this line, with the
    # `lipo -create` that merged the two into one binary, the day an Intel Mac has to run it.
    local frameworks=(-framework "$ios_framework")
    if [[ "${FIGHTDECK_SDK_ARCHS:-all}" != "arm64" ]]; then
        sim_framework="$(build_framework iphonesimulator arm64-apple-ios-simulator ios-simulator)"
        frameworks+=(-framework "$sim_framework")
    fi

    xcodebuild -create-xcframework \
        "${frameworks[@]}" \
        -allow-internal-distribution \
        -output "$out/${product}.xcframework"

    (
        cd "$out"
        zip -rq "${product}.xcframework.zip" "${product}.xcframework"
    )

    local size
    size="$(stat -f%z "$out/${product}.xcframework.zip" 2>/dev/null || stat -c%s "$out/${product}.xcframework.zip")"
    if (( size < minimum_zip_size )); then
        echo "error: ${product}.xcframework.zip is only ${size} bytes" >&2
        exit 1
    fi

    echo "Wrote $out/${product}.xcframework.zip ($size bytes)"
    ls -lh "$out/${product}.xcframework.zip"
    du -sh "$out/${product}.xcframework"
}
