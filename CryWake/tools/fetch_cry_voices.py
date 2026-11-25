#!/usr/bin/env python3
"""Fetch, verify, condition and encode the recorded baby-cry voices used by Cry Wake.

Pipeline (one run per voice listed in voice_sources.json):

  1. fetch     Download the original recording over the network and re-verify its
               license against the live source page (Freesound page / Wikimedia
               Commons API). Anything not in `allowed_licenses` aborts the run.
  2. condition Decode to mono 44.1 kHz, pick the loudest window of at most
               `max_seconds`, high-pass at 80 Hz, loudness-normalise to -14 LUFS
               and add short fades so the clip loops cleanly.
  3. encode    Encode to Core Audio Format (IMA4 ADPCM), the format iOS accepts for
               notification sounds (<= 30 s) and that AVAudioPlayer plays natively.

The result is written to Resources/Sounds/cry_<id>.caf together with
Resources/Sounds/voices.json, which is both the provenance log and the catalog the
app loads at runtime.

Requires: python3 (stdlib only) and ffmpeg/ffprobe on PATH.
Usage:    python3 tools/fetch_cry_voices.py
"""
from __future__ import annotations

import array
import datetime as dt
import hashlib
import json
import math
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "tools" / "voice_sources.json"
CACHE = ROOT / ".asset-cache"
OUT_DIR = ROOT / "Resources" / "Sounds"
USER_AGENT = "CryWakeAssetFetcher/1.0 (open-source alarm app build; python-urllib)"
SAMPLE_RATE = 44100
ANALYSIS_RATE = 8000


def http_get(url: str, *, retries: int = 6) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as err:
            if err.code == 429 and attempt + 1 < retries:
                retry_after = err.headers.get("Retry-After", "")
                wait = min(int(retry_after) if retry_after.isdigit() else 15 * (attempt + 1), 60)
                print(f"  rate limited, retrying in {wait}s", flush=True)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError(f"unreachable: {url}")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(cmd: list[str]) -> str:
    res = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return res.stdout


# --------------------------------------------------------------------------- stage 1


def verify_freesound(voice: dict, allowed: dict) -> dict:
    page = http_get(voice["page_url"]).decode("utf-8", "replace")
    links = set(re.findall(r"creativecommons\.org/(?:publicdomain|licenses)/[a-z\-]+/[0-9.]+/?", page))
    matched = [name for name, url in allowed.items() if url.split("//", 1)[1] in {l.rstrip("/") + "/" for l in links}]
    if len(matched) != 1:
        raise SystemExit(f"[{voice['id']}] license on {voice['page_url']} not in allowlist: {sorted(links)}")
    preview = voice["audio_url"].rsplit("/", 1)[1].split("-")[0]
    if preview not in page:
        raise SystemExit(f"[{voice['id']}] audio {voice['audio_url']} is not referenced by its source page")
    return {"license": matched[0], "license_url": allowed[matched[0]], "audio_url": voice["audio_url"], "source_sha1": None}


def verify_wikimedia(voice: dict, allowed: dict) -> dict:
    params = {
        "action": "query",
        "titles": voice["file_title"],
        "prop": "imageinfo",
        "iiprop": "url|sha1|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist",
        "format": "json",
    }
    data = json.loads(http_get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)))
    page = next(iter(data["query"]["pages"].values()))
    info = page["imageinfo"][0]
    lic = info["extmetadata"]["LicenseShortName"]["value"]
    if lic not in allowed:
        raise SystemExit(f"[{voice['id']}] Commons license {lic!r} not in allowlist")
    url = info["url"].split("?", 1)[0]
    return {"license": lic, "license_url": allowed[lic], "audio_url": url, "source_sha1": info["sha1"]}


def stage_fetch(voice: dict, allowed: dict) -> tuple[Path, dict]:
    verify = {"freesound": verify_freesound, "wikimedia": verify_wikimedia}[voice["provider"]]
    meta = verify(voice, allowed)
    if meta["license"] != voice["expected_license"]:
        raise SystemExit(f"[{voice['id']}] expected {voice['expected_license']}, source says {meta['license']}")
    ext = Path(urllib.parse.urlparse(meta["audio_url"]).path).suffix or ".bin"
    raw = CACHE / "raw" / f"{voice['id']}{ext}"
    raw.parent.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(http_get(meta["audio_url"]))
    if meta["source_sha1"]:
        got = hashlib.sha1(raw.read_bytes()).hexdigest()
        if got != meta["source_sha1"]:
            raise SystemExit(f"[{voice['id']}] SHA-1 mismatch: {got} != {meta['source_sha1']}")
    meta["raw_sha256"] = sha256(raw)
    meta["raw_bytes"] = raw.stat().st_size
    return raw, meta


# --------------------------------------------------------------------------- stage 2


def probe_duration(path: Path) -> float:
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)])
    return float(out.strip())


def loudest_window(path: Path, window: float) -> float:
    """Start time (s) of the `window`-second span with the highest mean energy."""
    pcm = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(ANALYSIS_RATE), "-f", "s16le", "-"],
        check=True, capture_output=True,
    ).stdout
    samples = array.array("h")
    samples.frombytes(pcm)
    hop = ANALYSIS_RATE // 4  # 250 ms blocks
    energy = [sum(s * s for s in samples[i:i + hop]) for i in range(0, len(samples) - hop + 1, hop)]
    blocks = max(1, int(window * 4))
    if len(energy) <= blocks:
        return 0.0
    best, best_i, acc = -1, 0, sum(energy[:blocks])
    for i in range(len(energy) - blocks + 1):
        if i:
            acc += energy[i + blocks - 1] - energy[i - 1]
        if acc > best:
            best, best_i = acc, i
    return best_i * 0.25


def stage_condition(voice: dict, raw: Path, max_seconds: float) -> tuple[Path, dict]:
    duration = probe_duration(raw)
    length = min(duration, max_seconds)
    start = loudest_window(raw, length) if duration > max_seconds else 0.0
    fade_out = min(0.6, length / 10)
    out = CACHE / "conditioned" / f"{voice['id']}.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    filters = ",".join([
        "highpass=f=80",
        "loudnorm=I=-14:TP=-1.0:LRA=11",
        f"afade=t=in:st=0:d=0.05",
        f"afade=t=out:st={length - fade_out:.3f}:d={fade_out:.3f}",
    ])
    run(["ffmpeg", "-v", "error", "-y", "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(raw),
         "-ac", "1", "-af", filters, "-ar", str(SAMPLE_RATE), "-c:a", "pcm_s16le", str(out)])
    vol =subprocess.run(["ffmpeg", "-i", str(out), "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    mean_db = float(re.search(r"mean_volume: (-?[\d.]+) dB", vol).group(1))
    max_db = float(re.search(r"max_volume: (-?[\d.]+) dB", vol).group(1))
    if mean_db < -40:
        raise SystemExit(f"[{voice['id']}] conditioned clip is near-silent (mean {mean_db} dB)")
    return out, {
        "source_duration_s": round(duration, 3),
        "window_start_s": round(start, 3),
        "window_length_s": round(length, 3),
        "filters": filters,
        "mean_volume_db": mean_db,
        "max_volume_db": max_db,
    }


# --------------------------------------------------------------------------- stage 3


def stage_encode(voice: dict, conditioned: Path) -> tuple[Path, dict]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"cry_{voice['id']}.caf"
    run(["ffmpeg", "-v", "error", "-y", "-i", str(conditioned), "-c:a", "adpcm_ima_qt", "-f", "caf", str(out)])
    info = json.loads(run(["ffprobe", "-v", "error", "-show_entries",
                           "stream=codec_name,sample_rate,channels:format=duration,format_name",
                           "-of", "json", str(out)]))
    stream, fmt = info["streams"][0], info["format"]
    duration = float(fmt["duration"])
    if fmt["format_name"] != "caf" or duration > 29.5 or int(stream["channels"]) != 1:
        raise SystemExit(f"[{voice['id']}] encoded file failed checks: {info}")
    return out, {
        "file": out.name,
        "container": "caf",
        "codec": stream["codec_name"],
        "sample_rate": int(stream["sample_rate"]),
        "channels": 1,
        "duration_s": round(duration, 3),
        "sha256": sha256(out),
        "bytes": out.stat().st_size,
    }


# --------------------------------------------------------------------------- main


def main() -> int:
    cfg = json.loads(SOURCES.read_text())
    allowed = cfg["allowed_licenses"]
    entries = []
    for voice in cfg["voices"]:
        print(f"[{voice['id']}] stage 1/3 fetch + license check", flush=True)
        try:
            raw, fetch_meta = stage_fetch(voice, allowed)
        except urllib.error.URLError as err:
            if voice.get("optional"):
                print(f"[{voice['id']}] skipped (optional source unavailable: {err})", flush=True)
                continue
            raise
        print(f"[{voice['id']}] stage 2/3 condition", flush=True)
        cond, cond_meta = stage_condition(voice, raw, cfg["max_seconds"])
        print(f"[{voice['id']}] stage 3/3 encode", flush=True)
        enc, enc_meta = stage_encode(voice, cond)
        entries.append({
            "id": voice["id"],
            "name": voice["name"],
            "subtitle": voice["subtitle"],
            "file": enc_meta["file"],
            "author": voice["author"],
            "source_title": voice["title"],
            "source_page": voice["page_url"],
            "license": fetch_meta["license"],
            "license_url": fetch_meta["license_url"],
            "provenance": {
                "retrieved_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
                "origin": "recorded",
                "stages": {
                    "fetch": {k: v for k, v in fetch_meta.items() if k not in ("license", "license_url")},
                    "condition": cond_meta,
                    "encode": enc_meta,
                },
            },
        })
        time.sleep(1)
    catalog = {"generated_by": "tools/fetch_cry_voices.py", "voices": entries}
    (OUT_DIR / "voices.json").write_text(json.dumps(catalog, indent=2) + "\n")
    print(f"wrote {len(entries)} voices to {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
