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

from lexicon_common import SCHEMA_VERSION, add_source, atomic_write_json


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
    add_source(meta, {
        "name": "undertheseanlp/dictionary",
        "url": "https://github.com/undertheseanlp/dictionary",
        "license": "GPL-3.0",
        "used_for": "vietnamese[] syllable union (Hồ Ngọc Đức + tudientv + Wiktionary VN)",
    })
    meta["generated_at"] = datetime.now(timezone.utc).isoformat()
    # `_meta.version` là SCHEMA của gói, không phải counter. Chỗ này từng ghi
    # `(meta.get("version") or 0) + 1`, tăng nó mỗi lần merge dữ liệu — nên nó
    # trôi khỏi số schema thật (file đang ship ghi 1, trong khi schema là 5).
    # Counter mà client dùng để quyết định tải là `version` ở top level.
    meta["version"] = SCHEMA_VERSION
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
    # `action="store_true", default=True` khiến cờ này không bao giờ tắt được —
    # truyền hay không truyền đều ra True. Đảo thành cờ phủ định để nó thật sự
    # dùng được; mặc định vẫn là có bump.
    p.add_argument("--no-bump-version", dest="bump_version", action="store_false",
                   help="Đừng tăng `version` ở top level (mặc định là có tăng, "
                        "để client tải lại).")
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

    # `extract_syllables` bỏ qua mọi dòng không parse được, nên file sai định
    # dạng cho ra tập rỗng mà không báo lỗi. Ghi tiếp thì `version` vẫn +1 và
    # mọi client tải về một bản y hệt bản cũ.
    if not new_syllables:
        print(f"error: 0 âm tiết trích được từ {args.underthesea} — "
              f"sai định dạng? (mong đợi JSON Lines, mỗi dòng có trường 'text'). "
              f"Dừng, không ghi.", file=sys.stderr)
        return 1

    merged = before | new_syllables
    added = len(merged) - len(before)
    pkg["vietnamese"] = sorted(merged)

    if args.bump_version:
        pkg["version"] = (pkg.get("version") or 0) + 1

    pkg = merge_meta(pkg)

    atomic_write_json(args.out_path, pkg)

    print(f"existing vietnamese: {len(before)}")
    print(f"underthesea syllables: {len(new_syllables)}")
    print(f"merged total: {len(merged)} (+{added})")
    print(f"new package version: {pkg['version']}")
    print(f"wrote: {args.out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
