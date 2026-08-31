#!/usr/bin/env bash
# Shared helpers for Skip AAR builds: transitive dependency patches and Maven publish.
# Sourced by sdks/{core,deposit,betslip}/build-aar.sh — not executed directly.
set -euo pipefail

patch_skip_ui_reflect() {
    local skipstone="$1"
    local gradle_file
    gradle_file=$(find -L "$skipstone" -path "*/SkipUI/build.gradle.kts" 2>/dev/null | head -1)
    if [[ -z "$gradle_file" ]]; then
        echo "warn: SkipUI build.gradle.kts not found under $skipstone" >&2
        return 0
    fi
    if ! grep -q 'kotlin-reflect' "$gradle_file"; then
        chmod u+w "$gradle_file" 2>/dev/null || true
        sed -i '' "/^dependencies {/a\\
    api(libs.kotlin.reflect)
" "$gradle_file"
    fi
    if ! grep -q 'androidx.compose.material:material' "$gradle_file"; then
        chmod u+w "$gradle_file" 2>/dev/null || true
        sed -i '' "/^dependencies {/a\\
    api(\"androidx.compose.material:material:1.7.8\")
" "$gradle_file"
    fi
}

patch_skip_commonmark_api() {
    local skipstone="$1"
    local gradle_file="$skipstone/SkipFoundation/build.gradle.kts"
    if [[ ! -f "$gradle_file" ]]; then
        gradle_file=$(find -L "$skipstone" -path "*/SkipFoundation/build.gradle.kts" 2>/dev/null | head -1)
    fi
    if [[ -z "$gradle_file" || ! -f "$gradle_file" ]]; then
        echo "warn: SkipFoundation build.gradle.kts not found under $skipstone" >&2
        return 0
    fi
    chmod u+w "$gradle_file" 2>/dev/null || true
    sed -i '' \
        -e 's/implementation("org.commonmark:commonmark/    api("org.commonmark:commonmark/g' \
        -e 's/implementation("org.commonmark:commonmark-ext-gfm-strikethrough/    api("org.commonmark:commonmark-ext-gfm-strikethrough/g' \
        "$gradle_file"
}

prepare_skipstone_for_patch() {
    local skipstone="$1"
    chmod -R u+w "$skipstone" 2>/dev/null || true
}

configure_skipstone_maven_repo() {
    local skipstone="$1"
    local maven_repo="$2"
    prepare_skipstone_for_patch "$skipstone"
    rm -f "$skipstone/fightdeck-publish.gradle.kts"
    sed -i '' '/fightdeck-publish.gradle.kts/d' "$skipstone/settings.gradle.kts" 2>/dev/null || true
    mkdir -p "$maven_repo"
    if ! grep -q '^group=' "$skipstone/gradle.properties" 2>/dev/null; then
        cat >> "$skipstone/gradle.properties" <<EOF
group=fightdeck.skip
version=0.1.0-local
EOF
    fi
    while IFS= read -r gradle_file; do
        if grep -q 'id("maven-publish")' "$gradle_file" && ! grep -q 'name = "fightdeck"' "$gradle_file"; then
            chmod u+w "$gradle_file" 2>/dev/null || true
            sed -i '' "/^publishing {/a\\
    repositories {\\
        maven {\\
            name = \"fightdeck\"\\
            url = uri(\"${maven_repo}\")\\
        }\\
    }
" "$gradle_file"
        fi
    done < <(find -L "$skipstone" -name 'build.gradle.kts' 2>/dev/null)
}

publish_skipstone_maven() {
    local skipstone="$1"
    shift
    local modules=("$@")
    (
        cd "$skipstone"
        local tasks=()
        for module in "${modules[@]}"; do
            tasks+=(":${module}:publishDefaultPublicationToFightdeckRepository")
        done
        gradle "${tasks[@]}" --console=plain
    )
}
