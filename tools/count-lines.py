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
# Files that marshal values across a language or process boundary.
BINDING_MARKERS = ("ffi", "bridge", "glue", "jni", "uniffi")
# Files that form the SDK's public seam, or wire the host to it. Every approach
# needs these, so they are not a differentiator — they are listed to keep the
# bindings figure honest.
SEAM_MARKERS = ("hosting", "adapter", "runtime", "launcher", "mapper", "holder")


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
    print("  bindings  marshal values across a language or process boundary")
    print("  seam      the SDK's public interface and the host wiring behind it\n")
    for approach in APPROACHES:
        found: list[tuple[str, str, int]] = []
        for path in files:
            if path.parts[0] != approach or path.suffix not in CODE_SUFFIXES:
                continue
            stem = path.stem.lower()
            if any(marker in stem for marker in BINDING_MARKERS):
                found.append(("bindings", str(pathlib.Path(*path.parts[1:])), lines(path)))
            elif any(marker in stem for marker in SEAM_MARKERS):
                found.append(("seam", str(pathlib.Path(*path.parts[1:])), lines(path)))
        bindings = sum(n for kind, _, n in found if kind == "bindings")
        seam = sum(n for kind, _, n in found if kind == "seam")
        print(f"  {approach}   bindings {bindings} · seam {seam}")
        for kind, name, count in sorted(found):
            print(f"      {kind:<9}{count:>5}  {name}")
        print()

    print("Read the bindings column, not the seam column: every approach needs a seam,")
    print("but only some make you hand-write the marshalling. 03-sdk-rn ships its iOS")
    print("sources twice (SwiftPM and CocoaPods), so its figures count the same code")
    print("more than once — that duplication is itself a real cost.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
