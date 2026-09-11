#!/usr/bin/env bash
# Cross-compile FightCore for Android and package fightcore.aar with the
# swift-java jextract --mode=jni bindings that let Kotlin call into it.
#
# Requires an open-source Swift toolchain (not Xcode's) — see README. Run as:
#   swiftly run ./build-aar.sh +6.3.3
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=setup-android-sdk.sh
source "$ROOT/setup-android-sdk.sh"
OUT="$ROOT/out"
MIN_SDK="${MIN_SDK:-28}"
ABIS=(
    "aarch64-unknown-linux-android${MIN_SDK}"
    "x86_64-unknown-linux-android${MIN_SDK}"
)
# The generated Java calls System.loadLibrary("fightcore"), which is why the product is
# renamed on the way into the AAR; keep this in step with nativeLibraryName in
# Sources/FightCoreJava/swift-java.config.
LIB_NAME="fightcore"
JAVA_PACKAGE_DIR="com/fightdeck/fightcore"

export FIGHTCORE_JAVA_BRIDGE=1
PLUGIN_OUT="$ROOT/.build/plugins/outputs/core/FightCoreJava/destination/JExtractSwiftPlugin"
GENERATED_JAVA="$PLUGIN_OUT/src/generated/java"

# Stale libraries here would be packaged as if they were current.
rm -rf "$OUT/android-libs"
mkdir -p "$OUT/android-libs"

# The Swift runtime for Android is a directory of shared objects, of which a headless
# core needs a fraction — copying all of them triples the AAR with XCTest and the XML
# and networking halves of Foundation that nothing here references. Walking the ELF
# NEEDED entries from the built libraries ships exactly what the loader will ask for.
copy_swift_runtime() {
    local arch="$1"
    local dest="$2"
    local runtime readelf
    # SwiftPM keeps installed Swift SDKs under Library on macOS and under ~/.swiftpm or
    # ~/.config on Linux, so all three roots are searched. `|| true`: the absent ones make
    # find exit non-zero, which pipefail would otherwise turn into a silent exit.
    runtime="$(find "$HOME/.swiftpm/swift-sdks" "$HOME/.config/swiftpm/swift-sdks" \
        "$HOME/Library/org.swift.swiftpm/swift-sdks" \
        -name libswiftCore.so -path "*${arch}*" 2>/dev/null | head -1 || true)"
    if [[ -z "$runtime" ]]; then
        echo "ERROR: no Swift runtime for $arch in the installed Swift SDK bundle" >&2
        exit 1
    fi
    runtime="$(dirname "$runtime")"

    readelf="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -name llvm-readelf 2>/dev/null | head -1 || true)"
    if [[ -z "$readelf" ]]; then
        echo "ERROR: llvm-readelf not found under $ANDROID_NDK_HOME" >&2
        exit 1
    fi

    # libswiftCore.so links the NDK's C++ runtime, which lives in the NDK sysroot rather
    # than the Swift SDK, and Android does not ship it: without this the first
    # System.loadLibrary fails with `library "libc++_shared.so" not found`. The rest of the
    # sysroot must stay out of the AAR — those are stubs for platform libraries the device
    # already has.
    local ndk_lib
    ndk_lib="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -type d \
        -path "*sysroot/usr/lib/${arch}-linux-android" 2>/dev/null | head -1 || true)"

    # libSwiftJava.so is ours, not the SDK's, so it seeds the walk alongside the core.
    # Visited is tracked by name rather than by "is it already copied", so a library that
    # arrived earlier still has its own NEEDED entries read. It is a delimited string
    # because macOS ships bash 3.2, which has no associative arrays.
    local visited=" "
    local queue=("$dest/lib${LIB_NAME}.so" "$dest/libSwiftJava.so")
    while (( ${#queue[@]} )); do
        local lib="${queue[0]}"
        queue=("${queue[@]:1}")
        [[ -f "$lib" ]] || continue
        local needed src
        while read -r needed; do
            [[ "$visited" == *" $needed "* ]] && continue
            visited+="$needed "
            src=""
            if [[ -f "$runtime/$needed" ]]; then
                src="$runtime/$needed"
            elif [[ "$needed" == "libc++_shared.so" && -n "$ndk_lib" && -f "$ndk_lib/$needed" ]]; then
                src="$ndk_lib/$needed"
            fi
            [[ -n "$src" ]] || continue
            cp "$src" "$dest/$needed"
            queue+=("$dest/$needed")
        done < <("$readelf" --needed-libs "$lib" | awk '/^ /{print $1}')
    done
}

echo "=== Cross-compiling FightCore + JNI bindings for Android ==="
for triple in "${ABIS[@]}"; do
    echo "--- $triple ---"
    # No --static-swift-stdlib: the Android SDK bundle ships the runtime as shared
    # objects only, so a static link fails looking for archives that do not exist.
    # They travel in the AAR instead, which is also the honest size to quote.
    # --disable-sandbox: the jextract build plugin writes generated Swift and Java
    # outside its sandboxed output directory.
    swift build \
        --package-path "$ROOT" \
        --swift-sdk "$triple" \
        --product FightCoreShared \
        --disable-sandbox \
        -c release \
        2>&1 | grep -v -E '^\[(info|debug)\]' || {
            echo "ERROR: swift build failed for $triple" >&2
            exit 1
        }
    build_dir="$ROOT/.build/$triple/release"
    lib_src="$build_dir/libFightCoreShared.so"
    if [[ ! -f "$lib_src" ]]; then
        lib_src="$(find "$ROOT/.build" -name libFightCoreShared.so \
            -path "*${triple%%-*}*" 2>/dev/null | head -1 || true)"
        build_dir="$(dirname "$lib_src")"
    fi
    if [[ ! -f "$lib_src" ]]; then
        echo "ERROR: no shared library for $triple under $ROOT/.build" >&2
        exit 1
    fi
    # Swift names the architecture, Android names the ABI, and an AAR is only loadable
    # if the directory uses Android's name.
    case "$triple" in
        aarch64-*) abi="arm64-v8a" ;;
        x86_64-*) abi="x86_64" ;;
        *) echo "ERROR: no Android ABI known for $triple" >&2; exit 1 ;;
    esac
    mkdir -p "$OUT/android-libs/$abi"
    cp "$lib_src" "$OUT/android-libs/$abi/lib${LIB_NAME}.so"
    # The SwiftJava runtime is a dynamic product of the dependency, so it links as its
    # own object rather than being absorbed into ours.
    cp "$build_dir/libSwiftJava.so" "$OUT/android-libs/$abi/libSwiftJava.so"
    copy_swift_runtime "${triple%%-*}" "$OUT/android-libs/$abi"
    echo "  $(du -h "$OUT/android-libs/$abi/lib${LIB_NAME}.so" | cut -f1)  $abi/lib${LIB_NAME}.so"
    echo "  $(du -h "$OUT/android-libs/$abi/libSwiftJava.so" | cut -f1)  $abi/libSwiftJava.so"
done

if [[ ! -d "$GENERATED_JAVA/$JAVA_PACKAGE_DIR" ]]; then
    echo "ERROR: no generated Java under $GENERATED_JAVA — did the jextract plugin run?" >&2
    exit 1
fi

# The generated bindings compile against org.swift.swiftkit.core, which is not on Maven
# Central yet (swift-java README says so outright). Building it from the checkout SwiftPM
# already resolved keeps the Java runtime and the Swift runtime on the same version.
echo "=== Building the SwiftKit Java runtime ==="
SWIFT_JAVA_CHECKOUT="${SWIFT_JAVA_CHECKOUT:-$ROOT/.build/checkouts/swift-java}"
if [[ -z "${SWIFTKIT_CORE_JAR:-}" ]]; then
    if [[ ! -d "$SWIFT_JAVA_CHECKOUT" ]]; then
        echo "ERROR: no swift-java checkout at $SWIFT_JAVA_CHECKOUT" >&2
        exit 1
    fi
    # -PswiftJavaJdk=17 keeps the FFM half of the project out of the build; it needs 25+
    # and Android has no Panama.
    (cd "$SWIFT_JAVA_CHECKOUT" && ./gradlew --quiet :SwiftKitCore:jar -PswiftJavaJdk=17 -PskipSamples=true)
    SWIFTKIT_CORE_JAR="$(find "$SWIFT_JAVA_CHECKOUT/SwiftKitCore/build/libs" -name 'swiftkit-core-*.jar' | head -1)"
fi
if [[ ! -f "$SWIFTKIT_CORE_JAR" ]]; then
    echo "ERROR: swiftkit-core jar not found; set SWIFTKIT_CORE_JAR" >&2
    exit 1
fi
echo "  $(du -h "$SWIFTKIT_CORE_JAR" | cut -f1)  $(basename "$SWIFTKIT_CORE_JAR")"

echo "=== Compiling generated Java bindings ==="
CLASSES="$OUT/classes"
rm -rf "$CLASSES"
mkdir -p "$CLASSES"
# --release 17 because the app's compileOptions are 17; jextract's default source level of
# 22 emits Java that AGP will not accept.
find "$GENERATED_JAVA" -name '*.java' -print0 \
    | xargs -0 javac --release 17 -nowarn -classpath "$SWIFTKIT_CORE_JAR" -d "$CLASSES"
(cd "$CLASSES" && jar --create --file "$OUT/classes.jar" .)
echo "  $(du -h "$OUT/classes.jar" | cut -f1)  classes.jar"

echo "=== Packaging AAR ==="
AAR_DIR="$OUT/aar-staging"
rm -rf "$AAR_DIR"
mkdir -p "$AAR_DIR/jni" "$AAR_DIR/libs" "$AAR_DIR/META-INF/com/android/build/gradle"

cat > "$AAR_DIR/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.fightdeck.fightcore">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

cat > "$AAR_DIR/META-INF/com/android/build/gradle/aar-metadata.properties" <<'EOF'
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=28
EOF

# swift-java resolves the generated types through JNI and reflection, so R8 must not
# rename or strip them. SwiftKitCore ships its own consumer rules for org.swift.swiftkit.
cat > "$AAR_DIR/proguard.txt" <<'EOF'
-keep class com.fightdeck.fightcore.** { *; }
-keep interface com.fightdeck.fightcore.** { *; }
EOF

cp "$OUT/classes.jar" "$AAR_DIR/classes.jar"
cp "$SWIFTKIT_CORE_JAR" "$AAR_DIR/libs/"

for abi_dir in "$OUT/android-libs"/*; do
    abi="$(basename "$abi_dir")"
    mkdir -p "$AAR_DIR/jni/$abi"
    cp "$abi_dir"/*.so "$AAR_DIR/jni/$abi/"
done

rm -f "$OUT/fightcore.aar"
(
    cd "$AAR_DIR"
    zip -qr "$OUT/fightcore.aar" . -x '*.DS_Store'
)

echo "Wrote $OUT/fightcore.aar"
ls -lh "$OUT/fightcore.aar"
echo "=== Per-ABI .so sizes ==="
find "$OUT/android-libs" -name '*.so' -exec du -h {} \; | sort -h | tail -8
