#!/usr/bin/env python3
"""Download real photographs for the fightdeck dataset and resize to app dimensions.

    ./tools/fetch-real-art.py

Generates placeholders first (so missing sources keep deterministic art), then overlays
Wikimedia Commons photographs listed in tools/image-sources.json. Writes
dataset/image-credits.json with source URL and licence for every real image.

Requires macOS `sips` for resize/crop. Run from repo root after build-dataset.py.
"""

from __future__ import annotations

import html
import json
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = REPO_ROOT / "dataset"
SOURCES_PATH = REPO_ROOT / "tools" / "image-sources.json"
CACHE_PATH = REPO_ROOT / "tools" / ".commons-cache.json"
USER_AGENT = "fightdeck-demo/1.0 (conference talk dataset; contact: local)"
API_DELAY_SECONDS = 4.0
DOWNLOAD_DELAY_SECONDS = 8.0


@dataclass
class CommonsMeta:
    file_title: str
    source_url: str
    download_url: str
    license_name: str
    artist: str
    width: int | None
    height: int | None


def load_sources() -> tuple[dict[str, str | None], dict[str, int], dict[str, int]]:
    payload = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    portrait = payload["portrait"]
    landscape = payload["landscape"]
    return payload["assets"], portrait, landscape


def target_size(relative_path: str, portrait: dict[str, int], landscape: dict[str, int]) -> tuple[int, int]:
    if "/fighters/" in relative_path:
        return portrait["width"], portrait["height"]
    return landscape["width"], landscape["height"]


def load_cache() -> dict[str, dict[str, object]]:
    if CACHE_PATH.exists():
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict[str, dict[str, object]]) -> None:
    CACHE_PATH.write_text(json.dumps(cache, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def fetch_with_retry(url: str, *, binary: bool = True) -> bytes | str:
    delay = 5.0
    last_error: Exception | None = None
    for _ in range(8):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
            return payload if binary else payload.decode("utf-8", "ignore")
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code in (429, 503):
                time.sleep(delay)
                delay = min(delay * 1.5, 60.0)
                continue
            raise
    raise last_error or RuntimeError(f"Failed to fetch {url}")


def thumbnail_url(file_title: str, max_edge: int) -> tuple[str, str, dict, dict]:
    """Resolve a sized Commons thumbnail via the API (avoids hammering originals)."""
    wiki_name = file_title.replace(" ", "_")
    page_url = f"https://commons.wikimedia.org/wiki/File:{urllib.parse.quote(wiki_name)}"
    api_url = (
        "https://commons.wikimedia.org/w/api.php?"
        + urllib.parse.urlencode(
            {
                "action": "query",
                "titles": f"File:{file_title}",
                "prop": "imageinfo",
                "iiprop": "url|size|extmetadata|thumbmime",
                "iiurlwidth": str(max_edge),
                "format": "json",
            }
        )
    )
    payload = json.loads(fetch_with_retry(api_url, binary=False))
    pages = payload["query"]["pages"]
    for page in pages.values():
        if "missing" in page:
            raise FileNotFoundError(f"Commons file not found: {file_title}")
        info = page["imageinfo"][0]
        download_url = info.get("thumburl") or info["url"]
        meta = info.get("extmetadata", {})
        return page_url, download_url, meta, info
    raise RuntimeError(f"Could not resolve thumbnail for {file_title}")


def scrape_commons(
    file_title: str,
    max_edge: int = 1600,
    *,
    cache: dict[str, dict[str, object]],
) -> CommonsMeta:
    cache_key = f"{file_title}@{max_edge}"
    if cache_key in cache:
        entry = cache[cache_key]
        return CommonsMeta(
            file_title=file_title,
            source_url=str(entry["source_url"]),
            download_url=str(entry["download_url"]),
            license_name=str(entry["license_name"]),
            artist=str(entry["artist"]),
            width=entry.get("width"),  # type: ignore[arg-type]
            height=entry.get("height"),  # type: ignore[arg-type]
        )

    time.sleep(API_DELAY_SECONDS)
    page_url, download_url, meta, info = thumbnail_url(file_title, max_edge)

    license_name = html.unescape(meta.get("LicenseShortName", {}).get("value", "Unknown"))
    artist = re.sub(
        r"<[^>]+>",
        "",
        html.unescape(meta.get("Artist", {}).get("value", "Unknown")),
    )[:200]
    width = info.get("width")
    height = info.get("height")

    cache[cache_key] = {
        "source_url": page_url,
        "download_url": download_url,
        "license_name": license_name,
        "artist": artist,
        "width": width,
        "height": height,
    }
    save_cache(cache)

    return CommonsMeta(
        file_title=file_title,
        source_url=page_url,
        download_url=download_url,
        license_name=license_name,
        artist=artist,
        width=width,
        height=height,
    )


def download(url: str, destination: Path) -> None:
    """Prefer curl — handles Wikimedia retries and Referer more reliably than urllib."""
    clean = url.split("?")[0]
    subprocess.run(
        [
            "curl",
            "-fsSL",
            "--retry",
            "5",
            "--retry-delay",
            "10",
            "--retry-all-errors",
            "-A",
            USER_AGENT,
            "-o",
            str(destination),
            clean,
        ],
        check=True,
        capture_output=True,
    )


def resize_cover(source: Path, destination: Path, width: int, height: int) -> None:
    """Center-crop to aspect ratio, then scale — matches avatar/poster layouts."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        working = tmp_dir / "working.jpg"
        cropped = tmp_dir / "cropped.jpg"

        subprocess.run(
            ["sips", "-s", "format", "jpeg", str(source), "--out", str(working)],
            check=True,
            capture_output=True,
        )

        probe = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(working)],
            check=True,
            capture_output=True,
            text=True,
        )
        current_w = int(re.search(r"pixelWidth: (\d+)", probe.stdout).group(1))
        current_h = int(re.search(r"pixelHeight: (\d+)", probe.stdout).group(1))

        target_ratio = width / height
        current_ratio = current_w / current_h

        if current_ratio > target_ratio:
            crop_h = current_h
            crop_w = int(current_h * target_ratio)
        else:
            crop_w = current_w
            crop_h = int(current_w / target_ratio)

        origin_x = max(0, (current_w - crop_w) // 2)
        origin_y = max(0, (current_h - crop_h) // 2)

        subprocess.run(
            [
                "sips",
                "-c",
                str(crop_h),
                str(crop_w),
                str(working),
                "--cropOffset",
                str(origin_y),
                str(origin_x),
                "--out",
                str(cropped),
            ],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["sips", "-z", str(height), str(width), str(cropped), "--out", str(destination)],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["sips", "-s", "formatOptions", "85", str(destination), "--out", str(destination)],
            check=True,
            capture_output=True,
        )


def generate_placeholders() -> None:
    print("  generating placeholders for fallbacks …")
    subprocess.run(["swift", "tools/generate-placeholder-art.swift"], cwd=REPO_ROOT, check=True)


def resolve_all_sources(
    assets: dict[str, str | None],
    portrait: dict[str, int],
    landscape: dict[str, int],
    cache: dict[str, dict[str, object]],
) -> dict[str, CommonsMeta]:
    """Resolve each unique Commons file once before downloading (respects rate limits)."""
    by_title: dict[str, int] = {}
    for relative_path, file_title in assets.items():
        if not file_title:
            continue
        max_edge = max(target_size(relative_path, portrait, landscape))
        by_title[file_title] = max(by_title.get(file_title, 0), max_edge * 2)

    resolved: dict[str, CommonsMeta] = {}
    for file_title, max_edge in sorted(by_title.items()):
        print(f"  resolve         {file_title}")
        resolved[file_title] = scrape_commons(file_title, max_edge=max_edge, cache=cache)
    return resolved


def main() -> int:
    download_only = "--download-only" in sys.argv
    assets, portrait, landscape = load_sources()
    credits_path = DATASET_DIR / "image-credits.json"
    cache = load_cache()

    if not download_only:
        generate_placeholders()

    manifest: dict[str, object] = {
        "generatedBy": "tools/fetch-real-art.py",
        "note": (
            "Real photographs from Wikimedia Commons (or generated placeholders where no "
            "suitable licensed portrait exists). Attribution for the talk."
        ),
        "images": {},
        "fallbacks": [],
    }

    if download_only:
        print("  download-only: using cached Commons metadata …")
        resolved_cache: dict[str, CommonsMeta] = {}
        by_title: dict[str, int] = {}
        for relative_path, file_title in assets.items():
            if not file_title:
                continue
            max_edge = max(target_size(relative_path, portrait, landscape))
            by_title[file_title] = max(by_title.get(file_title, 0), max_edge * 2)
        for file_title, max_edge in sorted(by_title.items()):
            cache_key = f"{file_title}@{max_edge}"
            if cache_key not in cache:
                print(f"  missing cache   {cache_key}", file=sys.stderr)
                continue
            entry = cache[cache_key]
            resolved_cache[file_title] = CommonsMeta(
                file_title=file_title,
                source_url=str(entry["source_url"]),
                download_url=str(entry["download_url"]),
                license_name=str(entry["license_name"]),
                artist=str(entry["artist"]),
                width=entry.get("width"),  # type: ignore[arg-type]
                height=entry.get("height"),  # type: ignore[arg-type]
            )
    else:
        print("  resolving Commons metadata …")
        try:
            resolved_cache = resolve_all_sources(assets, portrait, landscape, cache)
        except (urllib.error.URLError, FileNotFoundError, RuntimeError) as exc:
            print(f"  metadata resolution failed: {exc}", file=sys.stderr)
            return 1

    replaced = 0
    failed: list[str] = []

    for relative_path, file_title in sorted(assets.items()):
        destination = DATASET_DIR / relative_path
        if not file_title:
            manifest["fallbacks"].append(
                {"path": relative_path, "reason": "No suitable Wikimedia photograph found"}
            )
            print(f"  keep placeholder  {relative_path}")
            continue

        try:
            if file_title not in resolved_cache:
                raise RuntimeError(f"no cached metadata for {file_title}")

            meta = resolved_cache[file_title]

            with tempfile.TemporaryDirectory() as tmp:
                raw = Path(tmp) / "raw"
                download(meta.download_url, raw)
                w, h = target_size(relative_path, portrait, landscape)
                resize_cover(raw, destination, w, h)
                time.sleep(DOWNLOAD_DELAY_SECONDS)

            manifest["images"][relative_path] = {
                "status": "real",
                "commonsFile": meta.file_title,
                "sourcePage": meta.source_url,
                "downloadUrl": meta.download_url,
                "license": meta.license_name,
                "artist": meta.artist,
                "originalSize": (
                    f"{meta.width}x{meta.height}" if meta.width and meta.height else None
                ),
                "outputSize": f"{target_size(relative_path, portrait, landscape)[0]}x"
                f"{target_size(relative_path, portrait, landscape)[1]}",
            }
            replaced += 1
            print(f"  replaced        {relative_path}  ←  {file_title}")
        except (urllib.error.URLError, FileNotFoundError, RuntimeError, subprocess.CalledProcessError) as exc:
            failed.append(relative_path)
            manifest["fallbacks"].append(
                {"path": relative_path, "reason": f"Fetch failed ({exc}); kept placeholder"}
            )
            print(f"  fetch failed    {relative_path}  ({exc})", file=sys.stderr)

    manifest["summary"] = {
        "totalAssets": len(assets),
        "replacedWithReal": replaced,
        "keptPlaceholder": len(manifest["fallbacks"]),
        "fetchFailures": len([f for f in failed]),
        "noSourceListed": len([p for p, t in assets.items() if not t]),
    }

    credits_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"\n  {replaced} real images, {len(manifest['fallbacks'])} placeholders, "
        f"credits → {credits_path.relative_to(REPO_ROOT)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
