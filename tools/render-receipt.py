#!/usr/bin/env python3
"""Turn the raw measurement JSON in tools/out into the markdown table shown on stage.

    ./tools/render-receipt.py > tools/out/receipt.md

Nothing here invents a number. Approaches that were not measured show up as a dash
rather than being quietly dropped, because a missing row on a comparison slide is a
lie of omission and somebody in the audience always notices.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

OUT_DIR = Path(__file__).resolve().parent / "out"

APPROACHES: list[tuple[str, str]] = [
    ("00-native", "Native baseline"),
    ("01-core-swift", "Swift core"),
    ("02-core-rust", "Rust core"),
    ("03-sdk-rn", "React Native SDK"),
    ("04-sdk-skip", "Skip SDK"),
]

DASH = "—"


def mib(value: Any) -> str:
    if not isinstance(value, (int, float)) or value <= 0:
        return DASH
    return f"{value / 1024 / 1024:.1f} MB"


def kib(value: Any) -> str:
    if not isinstance(value, (int, float)) or value <= 0:
        return DASH
    return f"{value / 1024:.1f} KB"


def millis(value: Any) -> str:
    if not isinstance(value, (int, float)) or value <= 0:
        return DASH
    return f"{value:.0f} ms"


def load(name: str) -> dict[str, Any]:
    path = OUT_DIR / name
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        print(f"warning: {path.name} is not valid JSON ({error})", file=sys.stderr)
        return {}


def table(headers: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |"]
    lines.append("| " + " | ".join("---" for _ in headers) + " |")
    lines.extend("| " + " | ".join(row) + " |" for row in rows)
    return "\n".join(lines)


def size_section() -> str:
    rows = []
    for key, label in APPROACHES:
        ios = load(f"ios-{key}.json")
        android = load(f"android-{key}.json")
        rows.append([
            label,
            mib(ios.get("app_bytes")),
            mib(ios.get("executable_bytes")),
            mib(android.get("apk_universal_bytes")),
            mib(android.get("arm64_download_bytes")),
        ])
    return table(
        ["Approach", "iOS .app", "iOS executable", "Android APK", "Android arm64 download"],
        rows,
    )


def startup_section() -> str:
    rows = []
    for key, label in APPROACHES:
        data = load(f"startup-{key}.json")
        rows.append([
            label,
            millis(data.get("ios_cold_start_ms")),
            millis(data.get("ios_first_frame_ms")),
            millis(data.get("android_cold_start_ms")),
            millis(data.get("android_first_frame_ms")),
        ])
    return table(
        ["Approach", "iOS cold start", "iOS first frame", "Android cold start", "Android first frame"],
        rows,
    )


def second_feature_section() -> str:
    """The number the whole demo exists to produce.

    One runtime with one surface against the same runtime with three. Everything else in
    this file can be found in somebody else's benchmark; this one cannot, because nobody
    else builds three features over a shared runtime just to weigh the differences.

    The first feature is the least interesting of the three: it pays for whatever the
    runtime only pulls in once a real screen uses it. Features two and three are the ones
    to quote, and the fighter profile is the cleanest of all — it is pure presentation, so
    what it adds is close to the floor for "one more screen".

    Split by platform because the two do not agree: the same TypeScript ships as Hermes
    bytecode on iOS and as minified JavaScript on Android, and each feature drags a
    different amount of native code behind it.
    """
    rows = []
    for key, label in (("03-sdk-rn", "React Native SDK"), ("04-sdk-skip", "Skip SDK")):
        for prefix, platform_label, field in (
            ("ios", "iOS", "app_bytes"),
            ("android", "Android", "arm64_download_bytes"),
        ):
            # Read the per-stage files the measurement script leaves behind rather than an
            # aggregate, so the two platforms can be measured in separate CI jobs on
            # separate runners and still land in one table.
            sizes = [
                load(f"{prefix}-{key}-{stage}.json").get(field)
                for stage in ("runtime", "deposit", "both", "all")
            ]

            def marginal(before: int | None, after: int | None) -> str:
                if not isinstance(before, int) or not isinstance(after, int):
                    return DASH
                return kib(after - before)

            rows.append([
                f"{label} · {platform_label}",
                *(mib(size) for size in sizes),
                marginal(sizes[1], sizes[2]),
                marginal(sizes[2], sizes[3]),
            ])
    return table(
        [
            "Approach",
            "Runtime only",
            "+ deposit",
            "+ betslip",
            "+ fighter",
            "Feature 2",
            "Feature 3",
        ],
        rows,
    )


def contract_section() -> str:
    data = load("contract.json")
    results = data.get("results")
    if not isinstance(results, dict) or not results:
        return "_Not run yet._"
    rows = [
        [core, str(res.get("passed", DASH)), str(res.get("failed", DASH)), str(res.get("total", DASH))]
        for core, res in sorted(results.items())
    ]
    return table(["Core", "Passed", "Failed", "Total"], rows)


def main() -> None:
    if not OUT_DIR.exists():
        sys.exit("tools/out does not exist — run a measure workflow first")

    sections = [
        "# fightdeck receipt",
        "",
        "Generated by `measure.yml`. Every figure below came out of a build in this "
        "repository, not out of a blog post.",
        "",
        "## Binary size",
        "",
        size_section(),
        "",
        "## Startup",
        "",
        startup_section(),
        "",
        "## What the next feature costs",
        "",
        "One shared runtime, then one, two and three features on top of it. The last two "
        "deltas are the honest answer to \"what if we had five of these screens?\" — the "
        "first feature is inflated by runtime it is merely the first to touch.",
        "",
        second_feature_section(),
        "",
        "## Contract tests",
        "",
        "Every core runs the same golden fixtures. A row that is not all-green is a core "
        "that disagrees with the others about money.",
        "",
        contract_section(),
        "",
    ]
    print("\n".join(sections))


if __name__ == "__main__":
    main()
