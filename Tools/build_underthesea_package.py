#!/usr/bin/env python3
"""
Tools/build_underthesea_package.py — merge undertheseanlp/dictionary syllables
into vkey's `lexicon-update.json` (schema v5).

Source: https://github.com/undertheseanlp/dictionary (License: GPL-3.0)
        Tác giả: Vũ Anh (@undertheseanlp)
        Tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN

The repo provides `dictionary/words.txt` as JSON Lines:
    {"text": "công ty", "source": ["hongocduc", "tudientv"]}

vkey's runtime engine matches per-syllable, so we extract single-token
Vietnamese syllables only (multi-word phrases are deferred to a future
phrase-aware feature). Result is union'd with the existing `vietnamese[]`
list in `lexicon-update.json`, version is bumped, and attribution is
appended to `_meta.sources`.

Usage:
    git clone https://github.com/undertheseanlp/dictionary.git /tmp/undertheseanlp-dictionary
    python3 Tools/build_underthesea_package.py \\
        --underthesea /tmp/undertheseanlp-dictionary/dictionary/words.txt \\
        --in vkey/lexicon-update.json \\
        --out vkey/lexicon-update.json

License: GPL-3.0 (same as vkey project).
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


def extract_syllables(jsonl_path: Path) -> set[str]:
    """Extract unique single-token Vietnamese syllables from undertheseanlp JSONL.

    Filter rules:
      - Lowercase, strip whitespace
      - Skip entries with whitespace (multi-word phrases) — phrase support
        is deferred
      - Skip entries containing digits or dashes (transliterations like
        'a-ba-toa', 'a-dốt' are noise for the per-syllable engine)
      - Skip entries with non-letter characters
      - Apply NFC normalization to match vkey's runtime lookup
    """
    syllables: set[str] = set()
    with jsonl_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = (obj.get("text") or "").strip().lower()
            if not text or " " in text:
                continue
            if any(c.isdigit() or c == "-" for c in text):
                continue
            if not all(c.isalpha() for c in text):
                continue
            syllables.add(unicodedata.normalize("NFC", text))
    return syllables


def load_existing(in_path: Path) -> dict:
    with in_path.open(encoding="utf-8") as f:
        return json.load(f)


def merge_meta(pkg: dict) -> dict:
    """Add undertheseanlp source entry to _meta.sources, dedup by name."""
    meta = pkg.get("_meta") or {}
    sources = list(meta.get("sources") or [])
    existing_names = {s.get("name") for s in sources}
    if "undertheseanlp/dictionary" not in existing_names:
        sources.append({
            "name": "undertheseanlp/dictionary",
            "url": "https://github.com/undertheseanlp/dictionary",
            "license": "GPL-3.0",
            "used_for": "vietnamese[] syllable union (Hồ Ngọc Đức + tudientv + Wiktionary VN)",
        })
    meta["sources"] = sources
    meta["generated_at"] = datetime.now(timezone.utc).isoformat()
    meta["version"] = (meta.get("version") or 0) + 1
    if "license_of_aggregate" not in meta:
        meta["license_of_aggregate"] = "GPL-3.0"
    pkg["_meta"] = meta
    return pkg


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--underthesea", required=True, type=Path,
                   help="Path to undertheseanlp dictionary/words.txt (JSONL).")
    p.add_argument("--in", dest="in_path", required=True, type=Path,
                   help="Existing lexicon-update.json to merge into.")
    p.add_argument("--out", dest="out_path", required=True, type=Path,
                   help="Output path (can equal --in for in-place update).")
    p.add_argument("--bump-version", action="store_true", default=True,
                   help="Bump top-level `version` by 1 so apps re-download.")
    args = p.parse_args(argv)

    if not args.underthesea.exists():
        print(f"error: underthesea path not found: {args.underthesea}", file=sys.stderr)
        print("clone first: git clone https://github.com/undertheseanlp/dictionary.git /tmp/undertheseanlp-dictionary",
              file=sys.stderr)
        return 1
    if not args.in_path.exists():
        print(f"error: input package not found: {args.in_path}", file=sys.stderr)
        return 1

    pkg = load_existing(args.in_path)
    before = set(pkg.get("vietnamese") or [])
    new_syllables = extract_syllables(args.underthesea)

    merged = before | new_syllables
    added = len(merged) - len(before)
    pkg["vietnamese"] = sorted(merged)

    if args.bump_version:
        pkg["version"] = (pkg.get("version") or 0) + 1

    pkg = merge_meta(pkg)

    args.out_path.write_text(
        json.dumps(pkg, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )

    print(f"existing vietnamese: {len(before)}")
    print(f"underthesea syllables: {len(new_syllables)}")
    print(f"merged total: {len(merged)} (+{added})")
    print(f"new package version: {pkg['version']}")
    print(f"wrote: {args.out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
