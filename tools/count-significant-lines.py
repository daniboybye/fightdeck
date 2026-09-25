#!/usr/bin/env python3
"""Significant hand-written lines per approach, split by side of the SDK boundary.

"Lines of code" is only honest if it says what it counted. This counts a line when
something executes or declares: blank lines, `//` and `/* */` comments, and lines made
only of punctuation (`}`, `)`, `],`, `})`) are all dropped. A 3,000-line file of Swift
loses roughly a third that way, and the third it loses is the part nobody writes twice.

Six measured columns, then two totals:

  iOS            host code that is not shared and not adapter
  Android        the same, on the other side
  shared         SDK logic and UI, with the adapters taken out
  iOS adapter    code that exists only to reach the shared SDK from iOS
  Android adapt. the same, on the other side
  generated      what a binding tool wrote; build output, never hand-maintained
  config         build scripts, manifests and settings — ships no behaviour, but somebody
                 wrote it, so it is shown rather than dropped

  total          iOS + Android + shared — the code somebody wrote and keeps
  total+adapters the same plus both adapter columns

Deliberately excluded, because including them would compare different things:

  tests          not shipped; `00-native` carries UI tests the SDK demos do not. Rust keeps
                 unit tests inline, so a `#[cfg(test)]` item is cut out of its file too
  harnesses      04-sdk-skip's ios/Harness/** and sdks/consumer-verify/** measure the
                 SDK, they are not the demo app
  duplicates     byte-identical files are counted once — a copy is a real maintenance
                 cost, but it is not two implementations.

    python3 tools/count-significant-lines.py           # the table
    python3 tools/count-significant-lines.py --audit   # every file and how it was classed
"""

from __future__ import annotations

import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPROACHES = ["00-native", "01-core-swift", "02-core-rust", "03-sdk-rn", "04-sdk-skip"]

# Presentation order and names: the talk introduces the headless cores first, then the two
# UI-bearing SDKs, with the baseline on top as the thing everything is measured against.
ORDER = ["00-native", "02-core-rust", "01-core-swift", "03-sdk-rn", "04-sdk-skip"]
LABELS = {
    "00-native": "Native", "02-core-rust": "Rust", "01-core-swift": "Swift",
    "03-sdk-rn": "React Native", "04-sdk-skip": "Skip Lite",
}

CODE_SUFFIXES = {".swift", ".kt", ".rs", ".ts", ".tsx", ".java", ".m", ".mm", ".h", ".cpp"}

# Manifests that happen to be written in a counted language. `Package.swift` is Swift and
# `*.d.ts` is TypeScript, but neither is code anyone wrote to make the app behave.
CONFIG_FILES = ("Package.swift",)
CONFIG_SUFFIXES = (".d.ts",)

# Configuration gets its own column rather than being silently dropped: an approach that
# needs 537 lines of build script to produce its artefacts is not free, and hiding that
# flatters exactly the approaches with the most packaging.
BUILD_SUFFIXES = (".sh",)
MANIFEST_SUFFIXES = (".gradle.kts", ".toml", ".podspec")
MANIFEST_FILES = ("Package.swift", "Podfile")
SETTINGS_SUFFIXES = (".yml", ".yaml", ".json", ".properties", ".pro", ".xcconfig")
# npm writes these; counting them would charge React Native ~9,300 lines for a dependency
# graph nobody typed.
GENERATED_CONFIG = ("package-lock.json", "Cargo.lock", "Podfile.lock", "yarn.lock")

EXCLUDED_DIRS = {
    "node_modules", "build", ".build", "out", "DerivedData", "Pods", ".gradle",
    "target", "pkg", "dist", "generated", "Generated", "aar-staging",
}

# Not the demo app: measurement harnesses and a consumer smoke-test project. The Android
# product flavours are the same thing on the other platform — `both`, `deposit` and
# `runtime` are cut-down bridges that exist so the size harness can weigh one feature at a
# time. Only `all` is the app that gets demoed, and counting the other three would charge
# the two SDK approaches for measuring themselves.
EXCLUDED_PREFIXES = (
    "ios/Harness/", "sdks/consumer-verify/",
    "android/app/src/both/", "android/app/src/deposit/", "android/app/src/runtime/",
)

TEST_MARKERS = ("test", "Test", "__tests__", "androidTest")

# A file is adapter code when its whole reason to exist is the boundary: it declares what
# crosses, adapts types the generator cannot carry, mounts the surface, or reconnects
# change notification on the far side. Matched on the file stem, case-insensitively.
ADAPTER_STEMS = (
    "adapter", "bridge", "hosting", "host", "glue", "jni", "ffi", "uniffi",
    "launcher", "umbrella", "bootstrap", "registry", "holder", "runtime",
    "surfacecontainer", "surfacelayout", "composeentry",
)
# ...and when it lives in a directory that exists only for the seam.
ADAPTER_DIRS = ("bridge", "sdk", "uniffi")

GENERATED_GLOBS = {
    "01-core-swift": [
        "sdks/*/.build/plugins/outputs/**/JExtractSwiftPlugin/**/*.java",
        "sdks/*/.build/plugins/outputs/**/JExtractSwiftPlugin/**/*.swift",
    ],
    "02-core-rust": [
        "sdks/*/Sources/Fight*/*.swift",
        "sdks/*/Sources/*FFI/include/*.h",
        "android/app/src/main/java/uniffi/*/*.kt",
    ],
    # Codegen, from sdks/core/src/specs. Android writes the Java half into the runtime
    # library and the JNI half into the app; iOS writes both halves at `pod install`.
    "03-sdk-rn": [
        "sdks/core/android/runtime/build/generated/source/codegen/java/**/*.java",
        "android/app/build/generated/source/codegen/jni/**/*.h",
        "android/app/build/generated/source/codegen/jni/**/*.cpp",
        "ios/build/generated/ios/**/FightDeckRuntimeSpec*",
        "ios/build/generated/ios/**/FightDeckRuntimeSpec/*",
    ],
    # Our own modules only. skipstone also transpiles SkipUI/SkipFoundation/SkipLib —
    # another ~280k lines through the same compiler — which is somebody else's framework.
    "04-sdk-skip": ["sdks/*/.build/plugins/outputs/**/skipstone/FightDeck*/**/*.kt"],
}

# Inside a shared module an `#if` branch is an *adapter* only when it is a wrapper with no
# UI of its own: it translates a type, a theme or a runtime handle the other platform has no
# representation for. A branch that draws something — a different icon because the SF Symbol
# has no Material mapping, a hand-written layout because the modifier is missing, a different
# font API — is platform-specific code, not a wrapper. Daniel ruled on those three groups.
#
# Whole files whose every `#if` branch is pure translation:
SDK_ADAPTER_FILES = ("Money.swift", "MaterialScheme.swift")
SDK_ADAPTER_FILE_SUFFIXES = ("Hosting.swift",)   # the `*ComposeEntry` Compose entry points
# ...and the individual members in files that are otherwise UI.
SDK_ADAPTER_MEMBERS = {
    ("android", "platformChrome"),   # installs the host's Material scheme
    ("android", "listChrome"),       # the same, plus scrollContentBackground
    ("android", "doneButton"),       # ComposeView — the only reach to Compose's focus manager
    ("android", "displayStance"),    # localizedCapitalized has no Kotlin representation
    ("ios", "displayStance"),
}

MEMBER = re.compile(
    r"(?:@\w+ )*(?:fileprivate |private |public |static |final )*(?:var|func|struct|let) (\w+)"
)

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
PUNCTUATION_ONLY = re.compile(r"^[\s{}()\[\];,.:?<>&|]*$")


def without_rust_tests(text: str) -> str:
    """Drop every `#[cfg(test)]` item — in practice the `mod tests { … }` at a file's foot.

    Everywhere else tests live in their own files and TEST_MARKERS keeps them out; Rust's
    convention puts them inside the file under test, which would count them as shipped code.
    """
    lines = text.splitlines()
    kept: list[str] = []
    i = 0
    while i < len(lines):
        if lines[i].strip() != "#[cfg(test)]":
            kept.append(lines[i])
            i += 1
            continue
        depth, opened = 0, False
        i += 1
        while i < len(lines):
            depth += lines[i].count("{") - lines[i].count("}")
            opened = opened or "{" in lines[i]
            i += 1
            if (opened and depth <= 0) or (not opened and lines[i - 1].rstrip().endswith(";")):
                break
    return "\n".join(kept)


def read_code(path: pathlib.Path) -> str | None:
    try:
        text = (ROOT / path).read_text(errors="ignore")
    except (OSError, UnicodeDecodeError):
        return None
    return without_rust_tests(text) if path.suffix == ".rs" else text


def significant_lines(path: pathlib.Path) -> int:
    """Lines that declare or execute something."""
    text = read_code(path)
    if text is None:
        return 0
    text = BLOCK_COMMENT.sub("", text)
    count = 0
    in_block = False
    for raw in text.splitlines():
        line = raw.strip()
        # An unterminated /* survives the regex above only when it spans to EOF.
        if in_block:
            if "*/" in line:
                in_block = False
                line = line.split("*/", 1)[1].strip()
            else:
                continue
        if "/*" in line and "*/" not in line:
            in_block = True
            line = line.split("/*", 1)[0].strip()
        if line.startswith("//") or line.startswith("*"):
            continue
        # Strip a trailing comment, but only when it is not inside a string literal.
        if "//" in line and line.count('"') % 2 == 0:
            head = line.split("//", 1)[0]
            if head.count('"') % 2 == 0:
                line = head.strip()
        if not line or PUNCTUATION_ONLY.match(line):
            continue
        count += 1
    return count


def regions(path: pathlib.Path) -> dict[str, int]:
    """Split one shared file into what runs on both platforms, and what runs on one.

    Code behind `#if SKIP` / `#if !SKIP` is not shared: it compiles for one platform and
    never runs on the other. It splits again by whether it is a wrapper (adapter) or real
    platform code — see SDK_ADAPTER_* above.
    """
    out = {"shared": 0, "android-adapter": 0, "android-specific": 0,
           "ios-adapter": 0, "ios-specific": 0}
    text = read_code(path)
    if text is None:
        return out
    # A headless module has no UI, so none of its branches can be platform-specific *UI* —
    # every one of them is translating a type or an API the other side lacks. That is the
    # whole of 01-core-swift's and 02-core-rust's shared code, and it is why only Skip shows
    # anything in the "specific" columns.
    is_ui = "import SwiftUI" in text
    whole_file_adapter = (
        not is_ui
        or path.name in SDK_ADAPTER_FILES
        or path.name.endswith(SDK_ADAPTER_FILE_SUFFIXES)
    )
    text = BLOCK_COMMENT.sub("", text)
    mode: str | None = None
    member = ""
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("#if SKIP") or line.startswith("#if os(Android)"):
            mode, member = "android", ""
            continue
        if line.startswith("#if !SKIP") or line.startswith("#if !os(Android)"):
            mode, member = "ios", ""
            continue
        if line.startswith("#else") and mode:
            mode, member = ("ios" if mode == "android" else "android"), ""
            continue
        if line.startswith("#endif"):
            mode, member = None, ""
            continue
        if line.startswith("//") or line.startswith("*"):
            continue
        if "//" in line and line.count('"') % 2 == 0:
            head = line.split("//", 1)[0]
            if head.count('"') % 2 == 0:
                line = head.strip()
        if not line or PUNCTUATION_ONLY.match(line):
            continue
        if mode is None:
            out["shared"] += 1
            continue
        # Only a declaration at the type's own indentation starts a new member; a `let`
        # inside a body is a local, and treating it as one used to hand the rest of the
        # member to the wrong bucket.
        if len(raw) - len(raw.lstrip()) <= 4:
            found = MEMBER.match(line)
            if found:
                member = found.group(1)
        role = "adapter" if (
            whole_file_adapter or (mode, member) in SDK_ADAPTER_MEMBERS
        ) else "specific"
        out[f"{mode}-{role}"] += 1
    return out


def tracked_files() -> list[pathlib.Path]:
    listing = subprocess.run(
        ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
    )
    paths = [pathlib.Path(p) for p in listing.stdout.splitlines()]
    return [p for p in paths if not any(part in EXCLUDED_DIRS for part in p.parts)]


def classify(rel: pathlib.Path) -> tuple[str, str] | None:
    """(platform, role) for a path relative to its approach root, or None to skip."""
    text = str(rel)
    if text.startswith(EXCLUDED_PREFIXES):
        return None
    if rel.suffix not in CODE_SUFFIXES:
        return None
    if rel.name in CONFIG_FILES or text.endswith(CONFIG_SUFFIXES):
        return None
    if any(marker in part for part in rel.parts for marker in TEST_MARKERS):
        return None

    parts = rel.parts
    if parts[0] == "ios":
        platform = "ios"
    elif parts[0] == "android":
        platform = "android"
    elif parts[0] == "sdks":
        if "ios" in parts:
            platform = "ios"
        elif "android" in parts:
            platform = "android"
        else:
            platform = "shared"
    else:
        return None

    stem = rel.stem.lower()
    is_adapter = (
        any(marker in stem for marker in ADAPTER_STEMS)
        or any(part.lower() in ADAPTER_DIRS for part in rel.parts[:-1])
        # A module sitting directly under sdks/<platform>/ is there to package for that
        # platform, not to hold logic — 02-core-rust's aggregate cdylib crate is the case.
        or (parts[0] == "sdks" and len(parts) > 1 and parts[1] in {"ios", "android"})
    )
    return platform, ("adapter" if is_adapter else "code")


def config_lines(approach: str, files: list[pathlib.Path]) -> int:
    """Build scripts, manifests and settings — everything that ships no behaviour."""
    total = 0
    for path in files:
        if path.parts[0] != approach or path.name in GENERATED_CONFIG:
            continue
        name = str(path)
        if (
            name.endswith(BUILD_SUFFIXES)
            or name.endswith(MANIFEST_SUFFIXES)
            or path.name in MANIFEST_FILES
            or name.endswith(SETTINGS_SUFFIXES)
        ):
            total += significant_lines(path)
    return total


def generated_lines(approach: str) -> int:
    unique: dict[str, pathlib.Path] = {}
    for pattern in GENERATED_GLOBS.get(approach, []):
        for path in (ROOT / approach).glob(pattern):
            if path.is_file():
                key = str(path).rpartition("skipstone/")[2] or str(path)
                unique.setdefault(key, path)
    return sum(significant_lines(p.relative_to(ROOT)) for p in unique.values())


def measure(approach: str, files: list[pathlib.Path], audit: bool) -> dict[str, int]:
    counts = {"ios": 0, "android": 0, "shared": 0, "ios-adapter": 0, "android-adapter": 0,
              "ios-specific": 0, "android-specific": 0}
    seen: set[str] = set()
    rows: list[tuple[str, int, str]] = []
    for path in files:
        if path.parts[0] != approach:
            continue
        rel = pathlib.Path(*path.parts[1:])
        verdict = classify(rel)
        if verdict is None:
            continue
        platform, role = verdict
        digest = hashlib.sha1((ROOT / path).read_bytes()).hexdigest()
        if digest in seen:
            if audit:
                rows.append(("duplicate", 0, str(rel)))
            continue
        seen.add(digest)

        if platform != "shared":
            key = platform if role == "code" else f"{platform}-adapter"
            counts[key] += significant_lines(path)
            if audit:
                rows.append((key, significant_lines(path), str(rel)))
            continue

        # SDK-side. A whole file belongs to one platform when its target exists only for
        # that platform: `*Java` targets are the jextract facade, `*Umbrella` is the SPM
        # shim that lets Apple consumers import the binary framework.
        if any(part.endswith("Java") for part in rel.parts[:-1]):
            counts["android-adapter"] += significant_lines(path)
            if audit:
                rows.append(("android-adapter", significant_lines(path), str(rel)))
            continue
        if rel.stem.endswith("Umbrella"):
            counts["ios-adapter"] += significant_lines(path)
            if audit:
                rows.append(("ios-adapter", significant_lines(path), str(rel)))
            continue

        split = regions(path)
        for key, n in split.items():
            counts[key] += n
        if audit and any(split.values()):
            extra = " ".join(f"+{n} {k}" for k, n in split.items() if k != "shared" and n)
            rows.append(("shared", split["shared"], f"{rel}  {extra}"))
    if audit:
        print(f"\n--- {approach}")
        for key, n, name in sorted(rows):
            print(f"  {key:<16}{n:>6}  {name}")
    return counts


def main() -> int:
    audit = "--audit" in sys.argv
    files = tracked_files()
    head = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    table: dict[str, dict[str, int]] = {}
    for approach in APPROACHES:
        counts = measure(approach, files, audit)
        counts["config"] = config_lines(approach, files)
        counts["generated"] = generated_lines(approach)
        counts["total"] = (
            counts["ios"] + counts["android"] + counts["shared"]
            + counts["ios-specific"] + counts["android-specific"]
        )
        counts["total+adapters"] = (
            counts["total"] + counts["ios-adapter"] + counts["android-adapter"]
        )
        table[approach] = counts

    # The baseline's host total is what every "decrease hosts" figure is measured against.
    base_hosts = table["00-native"]["ios"] + table["00-native"]["android"]
    for approach in APPROACHES:
        row = table[approach]
        hosts = row["ios"] + row["android"]
        row["decrease"] = round((hosts - base_hosts) / base_hosts * 100)

    cols = [
        ("iOS host", "ios"), ("Android host", "android"), ("Shared", "shared"),
        ("iOS specific", "ios-specific"), ("Android specific", "android-specific"),
        ("Decrease hosts", "decrease"), ("Total", "total"),
        ("iOS Adapters", "ios-adapter"), ("Android Adapters", "android-adapter"),
        ("Total + Adapters", "total+adapters"),
        ("Generated", "generated"), ("Config", "config"),
    ]

    def cell(approach: str, key: str) -> str:
        row = table[approach]
        if key == "decrease":
            return "X" if approach == "00-native" else f"{row[key]}%".replace("-", "\u2212")
        if not row[key] and key in {"shared", "generated", "ios-adapter", "android-adapter",
                                    "ios-specific", "android-specific"}:
            return "X"
        return f"{row[key]:,}"

    if "--tsv" in sys.argv:
        print("\t".join(["Approach"] + [label for label, _ in cols]))
        for approach in ORDER:
            print("\t".join([LABELS[approach]] + [cell(approach, key) for _, key in cols]))
        return 0

    print(f"\nSignificant hand-written lines — measured at {head}\n")
    header = f"{'approach':<16}" + "".join(f"{label:>18}" for label, _ in cols)
    print(header)
    print("-" * len(header))
    for approach in ORDER:
        cells = "".join(f"{cell(approach, key):>18}" for _, key in cols)
        print(f"{LABELS[approach]:<16}{cells}")
    print()
    return 0

if __name__ == "__main__":
    sys.exit(main())
