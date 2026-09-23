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

  total          iOS + Android + shared — the code somebody wrote and keeps
  total+adapters the same plus both adapter columns

Deliberately excluded, because including them would compare different things:

  tests          not shipped; `00-native` carries UI tests the SDK demos do not
  config         Package.swift, *.gradle.kts, Podfile — asked for code, not manifests
  harnesses      04-sdk-skip's ios/Harness/** and sdks/consumer-verify/** measure the
                 SDK, they are not the demo app
  duplicates     03-sdk-rn ships its iOS SDK sources twice, once for SwiftPM and once
                 for CocoaPods. Byte-identical files are counted once — the duplication
                 is a real maintenance cost, but it is not two implementations.

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

CODE_SUFFIXES = {".swift", ".kt", ".rs", ".ts", ".tsx", ".java", ".m", ".mm", ".h", ".cpp"}

# Manifests that happen to be written in a counted language. `Package.swift` is Swift and
# `*.d.ts` is TypeScript, but neither is code anyone wrote to make the app behave.
CONFIG_FILES = ("Package.swift",)
CONFIG_SUFFIXES = (".d.ts",)

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
    # Our own modules only. skipstone also transpiles SkipUI/SkipFoundation/SkipLib —
    # another ~280k lines through the same compiler — which is somebody else's framework.
    "04-sdk-skip": ["sdks/*/.build/plugins/outputs/**/skipstone/FightDeck*/**/*.kt"],
}

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
PUNCTUATION_ONLY = re.compile(r"^[\s{}()\[\];,.:?<>&|]*$")


def significant_lines(path: pathlib.Path) -> int:
    """Lines that declare or execute something."""
    try:
        text = (ROOT / path).read_text(errors="ignore")
    except (OSError, UnicodeDecodeError):
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


def generated_lines(approach: str) -> int:
    unique: dict[str, pathlib.Path] = {}
    for pattern in GENERATED_GLOBS.get(approach, []):
        for path in (ROOT / approach).glob(pattern):
            if path.is_file():
                key = str(path).rpartition("skipstone/")[2] or str(path)
                unique.setdefault(key, path)
    return sum(significant_lines(p.relative_to(ROOT)) for p in unique.values())


def measure(approach: str, files: list[pathlib.Path], audit: bool) -> dict[str, int]:
    counts = {
        "ios": 0, "android": 0, "shared": 0,
        "ios-adapter": 0, "android-adapter": 0, "shared-adapter": 0,
    }
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
        # 03-sdk-rn commits the same iOS sources for SwiftPM and CocoaPods. Count once.
        digest = hashlib.sha1((ROOT / path).read_bytes()).hexdigest()
        if digest in seen:
            if audit:
                rows.append(("duplicate", 0, str(rel)))
            continue
        seen.add(digest)
        n = significant_lines(path)
        key = platform if role == "code" else f"{platform}-adapter"
        counts[key] += n
        if audit:
            rows.append((key, n, str(rel)))
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
        # Shared adapters — a hosting seam written once for both platforms — belong with
        # the shared code they gate, not with either host.
        counts["shared"] += counts.pop("shared-adapter")
        counts["generated"] = generated_lines(approach)
        counts["total"] = counts["ios"] + counts["android"] + counts["shared"]
        counts["total+adapters"] = (
            counts["total"] + counts["ios-adapter"] + counts["android-adapter"]
        )
        table[approach] = counts

    cols = [
        ("iOS", "ios"), ("Android", "android"), ("Shared", "shared"),
        ("iOS adapt.", "ios-adapter"), ("Andr. adapt.", "android-adapter"),
        ("Generated", "generated"), ("Total", "total"), ("Total+adapt.", "total+adapters"),
    ]

    # Tab-separated, for pasting into a spreadsheet and on into a slide.
    if "--tsv" in sys.argv:
        print("\t".join(["Approach"] + [label for label, _ in cols]))
        for approach in sorted(APPROACHES, key=lambda a: table[a]["total"]):
            row = table[approach]
            cells = [
                f"{row[key]:,}" if row[key] or key != "generated" else "—"
                for _, key in cols
            ]
            print("\t".join([approach] + cells))
        return 0

    print(f"\nSignificant hand-written lines — measured at {head}\n")
    header = f"{'approach':<16}" + "".join(f"{label:>14}" for label, _ in cols)
    print(header)
    print("-" * len(header))
    for approach in APPROACHES:
        row = table[approach]
        cells = "".join(
            f"{row[key]:>14,}" if row[key] or key != "generated" else f"{'—':>14}"
            for _, key in cols
        )
        print(f"{approach:<16}{cells}")
    print("\n00-native and 03-sdk-rn have no binding generator at all — nothing crosses a")
    print("language boundary in the first, and React Native's Codegen is deliberately unused")
    print("in the second. For the other three, generated is build output: it reads zero until")
    print("that approach has been packaged locally by its SDK build scripts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
