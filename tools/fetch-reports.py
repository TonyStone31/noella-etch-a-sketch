#!/usr/bin/env python3
"""Collect bug reports out of the Filebin bin and file them locally.

The bins are disposable and GitHub is the rendezvous, so this does what the
program does: read the endpoint config from GitHub, then work with whatever
bin it names.  It also remembers every bin it has ever seen, because a bin
that has just been rotated away may still have reports in it that nobody has
collected yet.

Nothing here is authenticated and nothing needs to be.  Run it whenever, or
from cron:

    */30 * * * * cd /path/to/repo && ./tools/fetch-reports.py >>/tmp/hsk.log 2>&1

Reports land under reports/, newest first in the index:

    reports/
      index.md                     every report, newest first
      2026-09-04/
        bug-20260904-011959-....txt
        bug-20260904-011959-....png
"""

import json
import os
import sys
import urllib.request
import urllib.error
import http.cookiejar
from datetime import datetime, timezone

ENDPOINT = ("https://raw.githubusercontent.com/TonyStone31/"
            "noella-etch-a-sketch/main/docs/bug-report-endpoint.json")

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "reports")
SEEN = os.path.join(OUT, ".seen.json")

# Filebin shows a one-time interstitial before a download and remembers the
# answer in a cookie, so every request goes through one jar.
JAR = http.cookiejar.CookieJar()
OPENER = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(JAR))
OPENER.addheaders = [("User-Agent", "heckers-sketch-report-collector")]


def get(url, accept=None):
    req = urllib.request.Request(url)
    if accept:
        req.add_header("Accept", accept)
    with OPENER.open(req, timeout=30) as r:
        return r.read()


def load_seen():
    try:
        with open(SEEN) as f:
            d = json.load(f)
            return set(d.get("files", [])), list(d.get("bins", []))
    except Exception:
        return set(), []


def save_seen(files, bins):
    os.makedirs(OUT, exist_ok=True)
    with open(SEEN, "w") as f:
        json.dump({"files": sorted(files), "bins": bins}, f, indent=2)


def bin_listing(base):
    """What is in this bin, or None if it has gone."""
    try:
        raw = get(base, accept="application/json")
    except urllib.error.HTTPError as e:
        if e.code in (401, 403, 404, 405, 409, 410, 423):
            return None
        raise
    except Exception:
        return None
    try:
        return json.loads(raw).get("files", [])
    except Exception:
        return None


def main():
    try:
        cfg = json.loads(get(ENDPOINT))
    except Exception as e:
        print("could not read the endpoint config:", e)
        return 1

    seen_files, seen_bins = load_seen()
    current = cfg.get("current_bin", "")
    for b in (current, cfg.get("previous_bin", "")):
        if b and b not in seen_bins:
            seen_bins.insert(0, b)

    # Newest bin first, and never more than a handful of old ones - a bin
    # Filebin has expired answers 404 and drops off the list on its own.
    fetched = 0
    live_bins = []
    for b in seen_bins[:8]:
        base = "https://filebin.net/" + b
        files = bin_listing(base)
        if files is None:
            print("bin gone:", b)
            continue
        live_bins.append(b)
        for f in files:
            name = f.get("filename", "")
            if not name or name in seen_files:
                continue
            if name.startswith("_") or name.startswith("roundtrip"):
                seen_files.add(name)
                continue
            day = (name.split("-")[1][:8] if "-" in name else "unsorted")
            try:
                day = datetime.strptime(day, "%Y%m%d").strftime("%Y-%m-%d")
            except Exception:
                day = "unsorted"
            folder = os.path.join(OUT, day)
            os.makedirs(folder, exist_ok=True)
            try:
                data = get(base + "/" + name)
            except Exception as e:
                print("could not fetch", name, e)
                continue
            # The interstitial is HTML; ask again now that the cookie is set.
            if data[:15].lower().startswith(b"<!doctype html"):
                try:
                    data = get(base + "/" + name)
                except Exception as e:
                    print("could not fetch", name, e)
                    continue
            with open(os.path.join(folder, name), "wb") as fh:
                fh.write(data)
            seen_files.add(name)
            fetched += 1
            print("got", day + "/" + name, len(data), "bytes")

    save_seen(seen_files, live_bins or seen_bins[:8])
    write_index()
    print(f"{fetched} new, {len(seen_files)} known, bins: {', '.join(live_bins) or 'none live'}")
    return 0


def write_index():
    """One page listing every report, newest first, with its first few lines."""
    rows = []
    for day in sorted(os.listdir(OUT), reverse=True):
        d = os.path.join(OUT, day)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d), reverse=True):
            if not name.endswith(".txt"):
                continue
            path = os.path.join(d, name)
            said, ver, tool = "", "", ""
            try:
                with open(path, errors="replace") as f:
                    lines = [l.rstrip("\n") for l in f]
                for i, l in enumerate(lines):
                    if l.startswith("version:"):
                        ver = l.split(":", 1)[1].strip()
                    if l.startswith("what they said:") and i + 1 < len(lines):
                        said = lines[i + 1].strip()
                    if l.startswith("tool="):
                        tool = l
                    if l.startswith("this one followed a crash"):
                        said = "[CRASH] " + said
            except Exception:
                pass
            shot = name[:-4] + ".png"
            has_shot = os.path.exists(os.path.join(d, shot))
            rows.append((day, name, ver, said, tool, has_shot))

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "index.md"), "w") as f:
        f.write("# Bug reports\n\n")
        f.write(f"_{len(rows)} reports, collected {datetime.now(timezone.utc):%Y-%m-%d %H:%M UTC}_\n\n")
        for day, name, ver, said, tool, has_shot in rows:
            f.write(f"## {day} — {said or '(nothing written)'}\n\n")
            f.write(f"- `{day}/{name}`{'  ·  picture alongside' if has_shot else ''}\n")
            if ver:
                f.write(f"- version {ver}\n")
            if tool:
                f.write(f"- `{tool}`\n")
            f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
