#!/usr/bin/env python3
"""Count hand-written lines per approach.

Three views, because "lines of code" on its own says nothing useful:

  totals   how much code each approach carries, split by where it lives
  logic    how many times the FightCore contract is implemented, and where
  glue     the code that exists only to cross a language or process boundary

Generated bindings (UniFFI output, transpiled Kotlin, Xcode projects) are
excluded — counting them would credit a code generator for typing.

    python3 tools/count-lines.py
"""

from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPROACHES = ["00-native", "01-core-swift", "02-core-rust", "03-sdk-rn", "04-sdk-skip"]

EXCLUDED_DIRS = {
    "node_modules", "build", ".build", "out", "DerivedData", "Pods", ".gradle",
    "target", "pkg", "dist", "generated", "Generated", "aar-staging",
}
CODE_SUFFIXES = {".swift", ".kt", ".rs", ".ts", ".tsx", ".java", ".m", ".mm", ".h", ".cpp"}
CONFIG_NAMES = {
    "project.yml", "Package.swift", "Cargo.toml", "package.json", "Podfile",
    "settings.gradle.kts", "build.gradle.kts", "gradle.properties",
}
CONFIG_SUFFIXES = {".podspec"}

# Files implementing the FightCore contract: odds, money, slip math, validation,
# settlement, cash-out.
LOGIC_STEMS = {
    "FightCore", "FightCoreTypes", "FightCoreDisplay", "FightCoreGlue", "Money",
    "OddsEngine", "BetSlipStore", "fightcore", "money", "odds", "types", "core",
}
# Files that marshal values across a language or process boundary. These are
# hand-written: they declare what crosses, adapt types the generator cannot carry,
# and reconnect reactivity on the far side. Not to be confused with the bindings
# themselves, which are counted separately below and which nobody writes.
GLUE_MARKERS = ("ffi", "bridge", "glue", "jni", "uniffi")
# Files that form the SDK's public seam, or wire the host to it. Every approach
# needs these, so they are not a differentiator — they are listed to keep the
# bindings figure honest.
SEAM_MARKERS = ("hosting", "adapter", "runtime", "launcher", "mapper", "holder")

# What the binding tool writes so nobody has to. The ratio between this and the glue
# column is the whole argument for using a generator, so it belongs on the same screen.
# These files are build output: they exist only after the approach has been packaged,
# and the report says so rather than printing a zero that reads like "none needed".
GENERATED_GLOBS = {
    "01-core-swift": (
        "swift-java jextract",
        [
            "sdks/core/.build/plugins/outputs/**/JExtractSwiftPlugin/**/*.java",
            "sdks/core/.build/plugins/outputs/**/JExtractSwiftPlugin/**/*.swift",
        ],
    ),
    "02-core-rust": (
        "UniFFI",
        [
            "sdks/*/Sources/Fight*/*.swift",
            "sdks/*/Sources/*FFI/include/*.h",
            "android/app/src/main/java/uniffi/*/*.kt",
        ],
    ),
    # Scoped to this repository's own modules. skipstone also transpiles the Skip
    # frameworks it depends on — SkipUI, SkipFoundation, SkipLib — which is another
    # 280k lines of Kotlin through the same compiler, and the reason the Android build
    # is slow. Counting it here would compare our transpiled screens against somebody
    # else's UI framework.
    "04-sdk-skip": (
        "skipstone",
        ["sdks/*/.build/plugins/outputs/**/skipstone/FightDeck*/**/*.kt"],
    ),
}


def repo_files() -> list[pathlib.Path]:
    paths: list[pathlib.Path] = []
    for args in (["git", "ls-files"], ["git", "ls-files", "--others", "--exclude-standard"]):
        listing = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True)
        paths += [pathlib.Path(line) for line in listing.stdout.splitlines()]
    return [p for p in paths if not any(part in EXCLUDED_DIRS for part in p.parts)]


def lines(path: pathlib.Path) -> int:
    try:
        text = (ROOT / path).read_text(errors="ignore")
    except (OSError, UnicodeDecodeError):
        return 0
    return sum(1 for line in text.splitlines() if line.strip())


def generated_lines(approach: str) -> int | None:
    """Non-blank lines the binding tool produced, or None when nothing is built yet."""
    spec = GENERATED_GLOBS.get(approach)
    if spec is None:
        return None
    # A module can be emitted more than once — skipstone re-transpiles a dependency
    # into every package that consumes it — so identify output by where it lands
    # inside the tool's tree, not by which build produced it.
    unique: dict[str, pathlib.Path] = {}
    for pattern in spec[1]:
        for path in (ROOT / approach).glob(pattern):
            if path.is_file():
                unique.setdefault(str(path).rpartition("skipstone/")[2] or str(path), path)
    return sum(lines(p.relative_to(ROOT)) for p in unique.values()) or None


def bucket(path: pathlib.Path) -> str | None:
    if path.name in CONFIG_NAMES or path.suffix in CONFIG_SUFFIXES:
        return "config"
    if path.suffix not in CODE_SUFFIXES:
        return None
    top = path.parts[1] if len(path.parts) > 1 else ""
    if top == "sdks":
        return "shared-ts" if path.suffix in {".ts", ".tsx"} else "shared"
    return top if top in {"ios", "android"} else None


def main() -> int:
    files = repo_files()

    print("Totals — hand-written lines\n")
    header = f"{'approach':<16}{'shared':>9}{'shared TS':>11}{'iOS':>8}{'Android':>9}{'config':>8}{'total':>8}"
    print(header)
    print("-" * len(header))
    for approach in APPROACHES:
        counts = {"shared": 0, "shared-ts": 0, "ios": 0, "android": 0, "config": 0}
        for path in files:
            if path.parts[0] != approach:
                continue
            key = bucket(path)
            if key:
                counts[key] += lines(path)
        total = sum(counts.values())
        print(f"{approach:<16}{counts['shared']:>9}{counts['shared-ts']:>11}"
              f"{counts['ios']:>8}{counts['android']:>9}{counts['config']:>8}{total:>8}")

    print("\n\nThe FightCore contract — how many times it is implemented\n")
    for approach in APPROACHES:
        sites: dict[str, int] = {}
        for path in files:
            if path.parts[0] != approach or path.suffix not in CODE_SUFFIXES:
                continue
            if path.stem not in LOGIC_STEMS or "test" in str(path).lower():
                continue
            site = "shared SDK" if path.parts[1] == "sdks" else path.parts[1]
            sites[site] = sites.get(site, 0) + lines(path)
        summary = " · ".join(f"{site} {count}" for site, count in sorted(sites.items()))
        print(f"  {approach:<16}{summary}")

    print("\n\nBoundary code — listed per file, because one total would hide the difference\n")
    print("  glue       hand-written: declares what crosses, adapts types the tool cannot")
    print("             carry, and reconnects reactivity on the far side")
    print("  seam       the SDK's public interface and the host wiring behind it")
    print("  generated  what the binding tool wrote instead of you; build output\n")
    for approach in APPROACHES:
        found: list[tuple[str, str, int]] = []
        for path in files:
            if path.parts[0] != approach or path.suffix not in CODE_SUFFIXES:
                continue
            stem = path.stem.lower()
            if any(marker in stem for marker in GLUE_MARKERS):
                found.append(("glue", str(pathlib.Path(*path.parts[1:])), lines(path)))
            elif any(marker in stem for marker in SEAM_MARKERS):
                found.append(("seam", str(pathlib.Path(*path.parts[1:])), lines(path)))
        glue = sum(n for kind, _, n in found if kind == "glue")
        seam = sum(n for kind, _, n in found if kind == "seam")
        headline = f"  {approach}   glue {glue} · seam {seam}"
        if approach in GENERATED_GLOBS:
            tool = GENERATED_GLOBS[approach][0]
            count = generated_lines(approach)
            headline += (f" · generated {count} by {tool}" if count
                         else f" · generated — ({tool}; nothing built here yet)")
        print(headline)
        for kind, name, count in sorted(found):
            print(f"      {kind:<9}{count:>5}  {name}")
        print()

    print("Read glue against generated. The bindings themselves — JNI thunks, UniFFI's")
    print("Swift and Kotlin, skipstone's transpiled output — are written by a tool in")
    print("every approach that has them; nobody maintains a line of it. What survives in")
    print("the glue column is the part no generator can decide: which API crosses, what")
    print("happens to a type it cannot represent (both cores pass money as decimal")
    print("strings), and how a change notification becomes @Observable or StateFlow.")
    print()
    print("Read glue against seam, too: every approach needs a seam, but only some make")
    print("you hand-write the marshalling. 03-sdk-rn ships its iOS sources twice (SwiftPM")
    print("and CocoaPods), so its figures count the same code more than once — that")
    print("duplication is itself a real cost.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
