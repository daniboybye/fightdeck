#!/usr/bin/env python3
"""Break each measured release build down into what it is made of.

    ./tools/size-breakdown.py                    # every approach measured in tools/out
    ./tools/size-breakdown.py 03-sdk-rn          # one approach
    ./tools/size-breakdown.py --platform android # one platform

measure-ios.sh and measure-android.sh answer "how big"; this answers "big because of what".
It reads what they leave behind — the unsigned `.xcarchive` and the bundletool `.apks` — so
it adds no build of its own and cannot disagree with them about which binary was weighed.

iOS: every file inside the archived `.app`, grouped into the main executable, each embedded
framework, the asset catalog, the JavaScript bundle, resource bundles and everything else.
Sizes are exact bytes. The headline `.app` figure is `du`, which rounds every file up to a
4 KB block, so the parts here sum to slightly less than it; the difference is reported rather
than hidden.

Android: bundletool extracts the APKs a real arm64 phone would be sent — the base APK plus
its ABI, density and language splits — and every entry is weighed twice. *Install* is the
uncompressed size on the device. *Download* is the entry gzipped at level 9, which is how
bundletool itself estimates what Play delivers; the per-entry estimates are checked against
bundletool's own total so a drift between the two shows up as a number, not a surprise.

Writes tools/out/breakdown-<platform>-<approach>.json.
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "tools" / "out"
APPROACHES = ["00-native", "01-core-swift", "02-core-rust", "03-sdk-rn", "04-sdk-skip"]

# What an arm64 phone in English at ~xxhdpi is sent. The density only picks which drawable
# split comes along; the apps carry almost no density-specific resources.
DEVICE_SPEC = {
    "supportedAbis": ["arm64-v8a"],
    "supportedLocales": ["en"],
    "screenDensity": 420,
    "sdkVersion": 36,
}


# --- iOS -----------------------------------------------------------------------------------

def ios_breakdown(approach: str) -> dict | None:
    archive = OUT / f"{approach}.xcarchive"
    apps = sorted((archive / "Products" / "Applications").glob("*.app"))
    if not apps:
        return None
    app = apps[0]
    executable = app / app.stem

    groups: dict[str, int] = defaultdict(int)
    frameworks: dict[str, int] = defaultdict(int)
    bundles: dict[str, int] = defaultdict(int)
    total = 0

    for path in app.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        size = path.stat().st_size
        total += size
        rel = path.relative_to(app)
        top = rel.parts[0]
        if path == executable:
            groups["executable"] += size
        elif top == "Frameworks":
            name = rel.parts[1] if len(rel.parts) > 1 else top
            frameworks[name] += size
            groups["frameworks"] += size
        elif top == "Assets.car":
            groups["assets"] += size
        elif path.suffix in {".hbc", ".jsbundle"} or path.name.endswith(".ios.bundle"):
            groups["js"] += size
        elif top.endswith(".bundle"):
            bundles[top] += size
            groups["bundles"] += size
        elif top == "PlugIns":
            groups["plugins"] += size
        else:
            groups["other"] += size

    du_bytes = int(subprocess.run(["du", "-sk", str(app)], capture_output=True, text=True)
                   .stdout.split()[0]) * 1024
    return {
        "platform": "ios",
        "approach": approach,
        "app": app.name,
        "du_bytes": du_bytes,
        "exact_bytes": total,
        "groups": dict(groups),
        "frameworks": dict(sorted(frameworks.items(), key=lambda kv: -kv[1])),
        "bundles": dict(sorted(bundles.items(), key=lambda kv: -kv[1])),
    }


# --- Android -------------------------------------------------------------------------------

def bundletool() -> list[str]:
    version = subprocess.run([str(REPO / "tools" / "versions.py"), "android.bundletool"],
                             capture_output=True, text=True, check=True).stdout.strip()
    jar = OUT / f"bundletool-{version}.jar"
    if not jar.exists():
        sys.exit(f"missing {jar} — run tools/measure-android.sh once to fetch it")
    return ["java", "-jar", str(jar)]


def gz(data: bytes) -> int:
    return len(gzip.compress(data, compresslevel=9, mtime=0))


def android_group(name: str) -> tuple[str, str | None]:
    """(group, detail) for one APK entry. Detail names the individual native library."""
    if name.startswith("lib/") and name.endswith(".so"):
        return "native", name.rsplit("/", 1)[-1]
    if name.startswith("classes") and name.endswith(".dex"):
        return "dex", None
    if name == "resources.arsc":
        return "resources.arsc", None
    if name.startswith("res/"):
        return "res", None
    if name.startswith("assets/"):
        # React Native's bundle is the only asset worth naming on its own.
        return ("js", None) if name.endswith((".bundle", ".hbc", ".jsbundle")) else ("assets", None)
    if name.startswith("META-INF/"):
        return "signing/metadata", None
    if name.startswith("kotlin/") or name.endswith(".kotlin_builtins"):
        return "kotlin metadata", None
    return "other", None


def android_breakdown(approach: str) -> dict | None:
    apks = OUT / f"{approach}.apks"
    if not apks.exists():
        return None
    tool = bundletool()

    reported = subprocess.run(
        tool + ["get-size", "total", f"--apks={apks}", "--dimensions=ABI"],
        capture_output=True, text=True, check=True).stdout
    bundletool_arm64 = next(
        (int(line.split(",")[-1]) for line in reported.splitlines() if line.startswith("arm64-v8a")),
        0)

    workdir = Path(tempfile.mkdtemp(prefix="fd-breakdown-"))
    try:
        spec = workdir / "device.json"
        spec.write_text(json.dumps(DEVICE_SPEC))
        extracted = workdir / "apks"
        subprocess.run(tool + ["extract-apks", f"--apks={apks}", f"--device-spec={spec}",
                               f"--output-dir={extracted}"],
                       capture_output=True, text=True, check=True)

        groups_install: dict[str, int] = defaultdict(int)
        groups_download: dict[str, int] = defaultdict(int)
        libs: dict[str, dict[str, int]] = defaultdict(lambda: {"install": 0, "download": 0})
        split_files: dict[str, int] = {}
        for apk in sorted(extracted.glob("*.apk")):
            split_files[apk.name] = apk.stat().st_size
            with zipfile.ZipFile(apk) as archive:
                for info in archive.infolist():
                    if info.is_dir():
                        continue
                    group, detail = android_group(info.filename)
                    data = archive.read(info)
                    install, download = len(data), gz(data)
                    groups_install[group] += install
                    groups_download[group] += download
                    if detail:
                        libs[detail]["install"] += install
                        libs[detail]["download"] += download
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    estimated = sum(groups_download.values())
    return {
        "platform": "android",
        "approach": approach,
        "bundletool_arm64_download_bytes": bundletool_arm64,
        "estimated_download_bytes": estimated,
        "install_bytes": sum(groups_install.values()),
        "splits": split_files,
        "groups_install": dict(groups_install),
        "groups_download": dict(groups_download),
        "native_libraries": dict(sorted(libs.items(), key=lambda kv: -kv[1]["download"])),
    }


# --- Output --------------------------------------------------------------------------------

def mb(value: int) -> str:
    return f"{value / 1_048_576:.2f} MB"


def kb(value: int) -> str:
    return f"{value / 1024:,.0f} KB"


def human(value: int) -> str:
    return mb(value) if value >= 1_048_576 else kb(value)


def print_ios(result: dict) -> None:
    g = result["groups"]
    print(f"### {result['approach']} — iOS `{result['app']}`: {mb(result['du_bytes'])} (du), "
          f"{mb(result['exact_bytes'])} exact")
    for key in ("executable", "frameworks", "js", "assets", "bundles", "plugins", "other"):
        if g.get(key):
            print(f"  {key:<12} {human(g[key]):>12}")
    for name, size in result["frameworks"].items():
        print(f"    └ {name:<40} {human(size):>12}")
    for name, size in result["bundles"].items():
        print(f"    └ {name:<40} {human(size):>12}")
    print()


def print_android(result: dict) -> None:
    gi, gd = result["groups_install"], result["groups_download"]
    drift = result["estimated_download_bytes"] - result["bundletool_arm64_download_bytes"]
    print(f"### {result['approach']} — Android arm64: bundletool {mb(result['bundletool_arm64_download_bytes'])} "
          f"download, per-entry estimate {mb(result['estimated_download_bytes'])} "
          f"({drift / 1024:+,.0f} KB), install {mb(result['install_bytes'])}")
    for key in sorted(gd, key=lambda k: -gd[k]):
        print(f"  {key:<18} download {human(gd[key]):>10}   install {human(gi[key]):>10}")
    for name, sizes in result["native_libraries"].items():
        print(f"    └ {name:<34} download {human(sizes['download']):>10}   install {human(sizes['install']):>10}")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("approaches", nargs="*", default=APPROACHES)
    parser.add_argument("--platform", choices=["ios", "android", "both"], default="both")
    args = parser.parse_args()

    for approach in args.approaches:
        if args.platform in ("ios", "both"):
            result = ios_breakdown(approach)
            if result:
                (OUT / f"breakdown-ios-{approach}.json").write_text(json.dumps(result, indent=2))
                print_ios(result)
            else:
                print(f"(no iOS archive for {approach})\n")
        if args.platform in ("android", "both"):
            result = android_breakdown(approach)
            if result:
                (OUT / f"breakdown-android-{approach}.json").write_text(json.dumps(result, indent=2))
                print_android(result)
            else:
                print(f"(no .apks for {approach})\n")


if __name__ == "__main__":
    main()
