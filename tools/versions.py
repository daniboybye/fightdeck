#!/usr/bin/env python3
"""Read a pinned version out of versions.lock.toml.

Every workflow and script goes through this so that a version lives in exactly one
place. Bumping a toolchain should be a one-line diff in the lock file, never a
find-and-replace across twenty YAML files.

    ./tools/versions.py android.compile_sdk        -> 37
    ./tools/versions.py react_native.version       -> 0.87.0
    ./tools/versions.py --github-env ANDROID_SDK android.compile_sdk

Exits non-zero with a readable message when a key is missing, so a typo in a
workflow fails loudly instead of silently expanding to an empty string.
"""

from __future__ import annotations

import argparse
import os
import sys
import tomllib
from pathlib import Path
from typing import Any

LOCK_FILE = Path(__file__).resolve().parent.parent / "versions.lock.toml"


def load() -> dict[str, Any]:
    if not LOCK_FILE.exists():
        sys.exit(f"versions.lock.toml not found at {LOCK_FILE}")
    with LOCK_FILE.open("rb") as handle:
        return tomllib.load(handle)


def lookup(data: dict[str, Any], dotted_key: str) -> Any:
    node: Any = data
    walked: list[str] = []
    for part in dotted_key.split("."):
        walked.append(part)
        if not isinstance(node, dict) or part not in node:
            available = ", ".join(sorted(node)) if isinstance(node, dict) else "(not a table)"
            sys.exit(
                f"key '{dotted_key}' not found in versions.lock.toml\n"
                f"  failed at: {'.'.join(walked)}\n"
                f"  available here: {available}"
            )
        node = node[part]
    return node


def render(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return " ".join(str(item) for item in value)
    return str(value)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("key", help="dotted key, e.g. android.compile_sdk")
    parser.add_argument(
        "--github-env",
        metavar="NAME",
        help="also append NAME=<value> to $GITHUB_ENV when running inside Actions",
    )
    args = parser.parse_args()

    value = render(lookup(load(), args.key))
    print(value)

    if args.github_env:
        github_env = os.environ.get("GITHUB_ENV")
        if github_env:
            with open(github_env, "a", encoding="utf-8") as handle:
                handle.write(f"{args.github_env}={value}\n")


if __name__ == "__main__":
    main()
