#!/usr/bin/env bash

build_swift_xcframework() {
    local root="$1"
    local product="$2"
    local binary_module="$3"
    local minimum_zip_size="$4"
    local out="$root/out"
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
            -c release \
            --triple "$triple" \
            --sdk "$sdk_path" \
            -Xswiftc -enable-library-evolution \
            -Xswiftc -emit-module-interface \
            >/dev/null

        mkdir -p "$module_dir"
        cp "$root/.build/$triple/release/lib${product}.dylib" \
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
            local source="$root/.build/$triple/release/Modules/${binary_module}.${extension}"
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
    local sim_arm_framework
    local sim_x64_framework
    local sim_framework="$staging/ios-simulator/${binary_module}.framework"
    ios_framework="$(build_framework iphoneos arm64-apple-ios ios-arm64)"
    sim_arm_framework="$(build_framework iphonesimulator arm64-apple-ios-simulator ios-sim-arm64)"
    sim_x64_framework="$(build_framework iphonesimulator x86_64-apple-ios-simulator ios-sim-x64)"

    mkdir -p "$(dirname "$sim_framework")"
    cp -R "$sim_arm_framework" "$sim_framework"
    lipo -create \
        "$sim_arm_framework/$binary_module" \
        "$sim_x64_framework/$binary_module" \
        -output "$sim_framework/$binary_module"
    cp -R "$sim_x64_framework/Modules/${binary_module}.swiftmodule/." \
        "$sim_framework/Modules/${binary_module}.swiftmodule/"

    xcodebuild -create-xcframework \
        -framework "$ios_framework" \
        -framework "$sim_framework" \
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
