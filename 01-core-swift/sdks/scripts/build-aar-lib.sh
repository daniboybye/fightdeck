#!/usr/bin/env bash
# Cross-compile a Swift package for Android and package its AAR with jextract JNI bindings,
# the Swift runtime its library needs and the SwiftKit jar the bindings compile against.
#
# usage: build-aar-lib.sh <package-dir> <lib-name> <shared-product> <java-bridge-target> <java-package>
set -euo pipefail

PKG_ROOT="$(cd "${1:?usage: build-aar-lib.sh <package-dir> <lib-name> <shared-product> <java-bridge-target> <java-package>}" && pwd)"
LIB_NAME="${2:?missing lib name}"
SHARED_PRODUCT="${3:?missing shared product name}"
JAVA_BRIDGE_TARGET="${4:?missing java bridge target}"
JAVA_PACKAGE="${5:?missing java package}"

# shellcheck source=setup-android-sdk.sh
source "$(cd "$(dirname "$0")" && pwd)/setup-android-sdk.sh"

OUT="$PKG_ROOT/out"
MIN_SDK="${MIN_SDK:-28}"
ABIS=(
    "aarch64-unknown-linux-android${MIN_SDK}"
    "x86_64-unknown-linux-android${MIN_SDK}"
)

JAVA_PACKAGE_DIR="${JAVA_PACKAGE//.//}"

PKG_FOLDER="$(basename "$PKG_ROOT")"
PLUGIN_OUT="$PKG_ROOT/.build/plugins/outputs/${PKG_FOLDER}/${JAVA_BRIDGE_TARGET}/destination/JExtractSwiftPlugin"
GENERATED_JAVA="$PLUGIN_OUT/src/generated/java"

# jextract writes a Java file per type and never deletes the file of a type that is gone, and
# every file in that folder is compiled into classes.jar. Without this, a glue type deleted from
# Swift keeps shipping as a class whose native methods no longer exist in the .so.
rm -rf "$PLUGIN_OUT"
rm -rf "$OUT/android-libs"
mkdir -p "$OUT/android-libs"

copy_swift_runtime() {
    local arch="$1"
    local dest="$2"
    local runtime readelf
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

    local ndk_lib
    ndk_lib="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -type d \
        -path "*sysroot/usr/lib/${arch}-linux-android" 2>/dev/null | head -1 || true)"

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

echo "=== Cross-compiling ${SHARED_PRODUCT} + JNI bindings for Android ==="
for triple in "${ABIS[@]}"; do
    echo "--- $triple ---"
    swift build \
        --package-path "$PKG_ROOT" \
        --swift-sdk "$triple" \
        --product "$SHARED_PRODUCT" \
        --disable-sandbox \
        -c release \
        2>&1 | grep -v -E '^\[(info|debug)\]' || {
            echo "ERROR: swift build failed for $triple" >&2
            exit 1
        }
    build_dir="$PKG_ROOT/.build/$triple/release"
    lib_src="$build_dir/lib${SHARED_PRODUCT}.so"
    if [[ ! -f "$lib_src" ]]; then
        lib_src="$(find "$PKG_ROOT/.build" -name "lib${SHARED_PRODUCT}.so" \
            -path "*${triple%%-*}*" 2>/dev/null | head -1 || true)"
        build_dir="$(dirname "$lib_src")"
    fi
    if [[ ! -f "$lib_src" ]]; then
        echo "ERROR: no shared library for $triple under $PKG_ROOT/.build" >&2
        exit 1
    fi
    case "$triple" in
        aarch64-*) abi="arm64-v8a" ;;
        x86_64-*) abi="x86_64" ;;
        *) echo "ERROR: no Android ABI known for $triple" >&2; exit 1 ;;
    esac
    mkdir -p "$OUT/android-libs/$abi"
    cp "$lib_src" "$OUT/android-libs/$abi/lib${LIB_NAME}.so"
    # libSwiftJava.so is a dynamic product of the dependency rather than part of the Swift
    # SDK, so it is not reached by walking the runtime and has to be named here.
    cp "$build_dir/libSwiftJava.so" "$OUT/android-libs/$abi/libSwiftJava.so"
    copy_swift_runtime "${triple%%-*}" "$OUT/android-libs/$abi"
    echo "  $(du -h "$OUT/android-libs/$abi/lib${LIB_NAME}.so" | cut -f1)  $abi/lib${LIB_NAME}.so"
done

if [[ ! -d "$GENERATED_JAVA/$JAVA_PACKAGE_DIR" ]]; then
    echo "ERROR: no generated Java under $GENERATED_JAVA — did the jextract plugin run?" >&2
    exit 1
fi

echo "=== Building the SwiftKit Java runtime ==="
SWIFT_JAVA_CHECKOUT="${SWIFT_JAVA_CHECKOUT:-$PKG_ROOT/.build/checkouts/swift-java}"
if [[ -z "${SWIFTKIT_CORE_JAR:-}" ]]; then
    if [[ ! -d "$SWIFT_JAVA_CHECKOUT" ]]; then
        echo "ERROR: no swift-java checkout at $SWIFT_JAVA_CHECKOUT" >&2
        exit 1
    fi
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
find "$GENERATED_JAVA" -name '*.java' -print0 \
    | xargs -0 javac --release 17 -nowarn -classpath "$SWIFTKIT_CORE_JAR" -d "$CLASSES"
(cd "$CLASSES" && jar --create --file "$OUT/classes.jar" .)
echo "  $(du -h "$OUT/classes.jar" | cut -f1)  classes.jar"

echo "=== Packaging AAR ==="
AAR_DIR="$OUT/aar-staging"
rm -rf "$AAR_DIR"
mkdir -p "$AAR_DIR/jni" "$AAR_DIR/libs" "$AAR_DIR/META-INF/com/android/build/gradle"

cat > "$AAR_DIR/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="${JAVA_PACKAGE}">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF

cat > "$AAR_DIR/META-INF/com/android/build/gradle/aar-metadata.properties" <<'EOF'
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=28
EOF

cat > "$AAR_DIR/proguard.txt" <<EOF
-keep class ${JAVA_PACKAGE}.** { *; }
-keep interface ${JAVA_PACKAGE}.** { *; }
EOF

cp "$OUT/classes.jar" "$AAR_DIR/classes.jar"
cp "$SWIFTKIT_CORE_JAR" "$AAR_DIR/libs/"

for abi_dir in "$OUT/android-libs"/*; do
    abi="$(basename "$abi_dir")"
    mkdir -p "$AAR_DIR/jni/$abi"
    cp "$abi_dir"/*.so "$AAR_DIR/jni/$abi/"
done

rm -f "$OUT/${LIB_NAME}.aar"
(
    cd "$AAR_DIR"
    zip -qr "$OUT/${LIB_NAME}.aar" . -x '*.DS_Store'
)

echo "Wrote $OUT/${LIB_NAME}.aar"
ls -lh "$OUT/${LIB_NAME}.aar"
echo "=== Per-ABI .so sizes ==="
find "$OUT/android-libs" -name '*.so' -exec du -h {} \; | sort -h | tail -8
