#!/usr/bin/env python3
"""
Verify every station URL in stations.json. Replace dead URLs with fresh ones
from Radio-Browser when a match by name can be found. Preserves all curated
metadata (callLetters, frequency, description, city).

Writes back to stations.json in place. Exits 0 regardless — the workflow
commits whatever changed.
"""

from __future__ import annotations

import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional

STATIONS_PATH = pathlib.Path(__file__).resolve().parent.parent / "BayWave" / "BayWave" / "Resources" / "stations.json"
RB_HOSTS = ["https://de1.api.radio-browser.info", "https://fi1.api.radio-browser.info", "https://at1.api.radio-browser.info"]
UA = "BayWave-RefreshBot/1.0"
TIMEOUT = 8


def http_head(url: str) -> int:
    """Return status code. 0 on network error. Streams 1KB to be gentle."""
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Range": "bytes=0-1024"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def is_live(code: int) -> bool:
    return code in (200, 206)


def rb_search(name: str) -> list:
    """Ask Radio-Browser for a station by name. Try hosts until one responds."""
    query = urllib.parse.quote(name)
    for host in RB_HOSTS:
        url = f"{host}/json/stations/byname/{query}?hidebroken=true&limit=10"
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                return json.loads(r.read())
        except Exception:
            continue
    return []


def search_key(station: dict) -> str:
    """What to query Radio-Browser with. Prefer call letters, fall back to name."""
    call = station.get("callLetters", "")
    if call and call not in ("SOMA", "BFF"):
        return call
    return re.sub(r"\s*\(.*?\)\s*", "", station["name"]).strip()


def find_replacement(station: dict) -> Optional[str]:
    candidates = rb_search(search_key(station))
    for c in candidates:
        if c.get("lastcheckok") != 1:
            continue
        url = c.get("url_resolved") or c.get("url")
        if not url or url == station["streamURL"]:
            continue
        if is_live(http_head(url)):
            return url
    return None


def main() -> int:
    data = json.loads(STATIONS_PATH.read_text())
    stations = data["stations"]
    report = {"checked": 0, "live": 0, "replaced": [], "still_dead": []}

    for s in stations:
        report["checked"] += 1
        if is_live(http_head(s["streamURL"])):
            report["live"] += 1
            continue

        replacement = find_replacement(s)
        if replacement:
            print(f"  REPLACED {s['name']}: {s['streamURL']} -> {replacement}")
            s["streamURL"] = replacement
            report["replaced"].append(s["id"])
            report["live"] += 1
        else:
            print(f"  DEAD     {s['name']}: {s['streamURL']} (no replacement found)")
            report["still_dead"].append(s["id"])

    STATIONS_PATH.write_text(json.dumps(data, indent=2) + "\n")

    print()
    print(f"checked={report['checked']} live={report['live']} "
          f"replaced={len(report['replaced'])} still_dead={len(report['still_dead'])}")

    # Emit a summary for the workflow step.
    summary = pathlib.Path(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/null"))
    try:
        with summary.open("a") as f:
            f.write(f"# Station refresh\n\n")
            f.write(f"- Checked: **{report['checked']}**\n")
            f.write(f"- Live: **{report['live']}**\n")
            f.write(f"- Replaced: **{len(report['replaced'])}** — {', '.join(report['replaced']) or '—'}\n")
            f.write(f"- Still dead: **{len(report['still_dead'])}** — {', '.join(report['still_dead']) or '—'}\n")
    except Exception:
        pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
