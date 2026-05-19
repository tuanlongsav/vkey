#!/usr/bin/env python3
"""
Tools/merge_underthesea_deep.py — deep extraction & merge của undertheseanlp tokens
vào lexicon-update.json. Khác với `build_underthesea_package.py` chỉ lấy single-token
entries, script này:

  - Extract TẤT CẢ tokens (kể cả split từ multi-word phrases như "công ty" → ["công", "ty"])
  - Phân loại theo 3 tier signal:
      A: có VN marker (dấu thanh/cluster) + xuất hiện ≥2 phrases → high confidence
      B: có VN marker nhưng chỉ 1 phrase → medium (apply phonotactic filter)
      C: ASCII không marker, ≥3 phrases → loanword (whitelist hardcode)
  - Áp phonotactic filter (initial/final consonant + length) cho Tier A và B
  - Tier C: chỉ giữ loanword phổ biến đã được curate sẵn

Mục tiêu: bổ sung ~600+ syllables hợp lệ mà `build_underthesea_package.py` bỏ sót,
KHÔNG đưa vào Wiktionary noise / English false-positive.

Usage:
    git clone https://github.com/undertheseanlp/dictionary.git /tmp/undertheseanlp-dictionary
    python3 Tools/merge_underthesea_deep.py \\
        --underthesea /tmp/undertheseanlp-dictionary/dictionary/words.txt \\
        --in vkey/lexicon-update.json \\
        --out vkey/lexicon-update.json

License: GPL-3.0
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


# ── Phonotactic rules learned từ baseline 7,184 curated syllables ──

VN_DIACRITIC_CHARS = set(
    "àáảãạăắằẳẵặâấầẩẫậ"
    "èéẻẽẹêếềểễệ"
    "ìíỉĩị"
    "òóỏõọôốồổỗộơớờởỡợ"
    "ùúủũụưứừửữự"
    "ỳýỷỹỵ"
    "đ"
)

VN_INITIAL_CLUSTERS = {"ng", "ngh", "nh", "kh", "ph", "th", "tr", "ch", "gh", "gi", "qu"}

# Valid syllable initial consonants (single + clusters)
VALID_INITIALS = {
    "", "b", "c", "ch", "d", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n",
    "ng", "ngh", "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
}

# Valid syllable final consonants
VALID_FINALS = {"", "c", "ch", "m", "n", "ng", "nh", "p", "t"}

# Curated whitelist cho Tier C — loanwords phổ biến trong VN
TIER_C_WHITELIST = {
    # Chemistry / units
    "acid", "axit", "kali", "oxy", "ion", "clo", "nitrat", "kalium",
    "celsius", "fahrenheit",
    # Science / tech
    "alpha", "beta", "logic", "euclid", "radio", "video", "internet",
    "diesel", "cassette", "apacthai",
}


def strip_diacritics(s: str) -> str:
    """Remove tone marks, preserve đ → d."""
    nfd = unicodedata.normalize("NFD", s)
    base = "".join(c for c in nfd if unicodedata.category(c) != "Mn")
    return base.replace("đ", "d").replace("Đ", "d")


def has_vn_marker(w: str) -> bool:
    low = w.lower()
    if any(c in VN_DIACRITIC_CHARS for c in low):
        return True
    for cluster in VN_INITIAL_CLUSTERS:
        if low.startswith(cluster) and len(low) > len(cluster):
            return True
    return False


def is_valid_vn_syllable(w: str) -> bool:
    """Phonotactic validator — strict shape check."""
    base = strip_diacritics(w.lower())
    if len(base) > 7 or len(base) < 1:
        return False
    # Find vowel core
    vowel_idx = next((i for i, c in enumerate(base) if c in "aeiouy"), -1)
    if vowel_idx < 0:
        return False  # no vowel
    end_vowel = vowel_idx
    while end_vowel < len(base) and base[end_vowel] in "aeiouy":
        end_vowel += 1
    initial = base[:vowel_idx]
    final = base[end_vowel:]
    if initial not in VALID_INITIALS:
        return False
    if final not in VALID_FINALS:
        return False
    return True


def extract_tokens(jsonl_path: Path) -> dict[str, int]:
    """Extract tokens + phrase-occurrence count.

    Skips:
      - Empty / wiktionary template lines (`Bản mẫu:`, contains `:`)
      - Tokens with digits / dashes
      - Tokens < 2 chars or > 15 chars
    """
    counts: dict[str, int] = {}
    with jsonl_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = (obj.get("text") or "").strip()
            if not text or "bản mẫu:" in text.lower() or ":" in text:
                continue
            for tok in text.lower().split():
                tok = unicodedata.normalize("NFC", tok)
                if not all(c.isalpha() or c == "-" for c in tok):
                    continue
                if "-" in tok or len(tok) < 2 or len(tok) > 15:
                    continue
                counts[tok] = counts.get(tok, 0) + 1
    return counts


def classify(tokens: dict[str, int], current_vn: set[str]) -> tuple[set, set, set, dict]:
    """Return (tier_a, tier_b, tier_c, raw_stats)."""
    new_tokens = {t for t in tokens if t not in current_vn}
    tier_a = set()  # marker + ≥2 phrases
    tier_b = set()  # marker + 1 phrase
    tier_c = set()  # ASCII no marker, ≥3 phrases
    for t in new_tokens:
        cnt = tokens[t]
        marker = has_vn_marker(t)
        if marker and cnt >= 2:
            tier_a.add(t)
        elif marker and cnt == 1:
            tier_b.add(t)
        elif not marker and cnt >= 3:
            tier_c.add(t)
    stats = {
        "new_tokens": len(new_tokens),
        "tier_a_raw": len(tier_a),
        "tier_b_raw": len(tier_b),
        "tier_c_raw": len(tier_c),
    }
    return tier_a, tier_b, tier_c, stats


def apply_filters(tier_a, tier_b, tier_c):
    """Phonotactic filter cho A & B; hardcoded whitelist cho C."""
    a_filtered = {t for t in tier_a if is_valid_vn_syllable(t)}
    b_filtered = {t for t in tier_b if is_valid_vn_syllable(t)}
    c_filtered = {t for t in tier_c if t in TIER_C_WHITELIST}
    return a_filtered, b_filtered, c_filtered


def merge_meta(pkg: dict, stats: dict) -> dict:
    meta = pkg.get("_meta") or {}
    cleanup_log = meta.get("cleanup") or []
    cleanup_log.append({
        "at": datetime.now(timezone.utc).isoformat(),
        "rule": "merge_underthesea_deep.py — Tier A+B (phonotactic) + Tier C (curated whitelist)",
        "additions": stats,
    })
    meta["cleanup"] = cleanup_log

    sources = list(meta.get("sources") or [])
    if not any(s.get("name") == "undertheseanlp/dictionary (deep)" for s in sources):
        sources.append({
            "name": "undertheseanlp/dictionary (deep)",
            "url": "https://github.com/undertheseanlp/dictionary",
            "license": "GPL-3.0",
            "used_for": "vietnamese[] supplemental — phrase-token extraction with phonotactic filter",
        })
    meta["sources"] = sources
    pkg["_meta"] = meta
    return pkg


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--underthesea", required=True, type=Path)
    p.add_argument("--in", dest="in_path", required=True, type=Path)
    p.add_argument("--out", dest="out_path", required=True, type=Path)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args(argv)

    if not args.underthesea.exists():
        print(f"error: underthesea not found: {args.underthesea}", file=sys.stderr)
        return 1

    pkg = json.loads(args.in_path.read_text(encoding="utf-8"))
    current_vn = set(pkg.get("vietnamese") or [])
    print(f"current v{pkg.get('version')}: {len(current_vn)} syllables")

    tokens = extract_tokens(args.underthesea)
    print(f"extracted {len(tokens)} unique tokens from undertheseanlp")

    tier_a, tier_b, tier_c, raw_stats = classify(tokens, current_vn)
    a_f, b_f, c_f = apply_filters(tier_a, tier_b, tier_c)

    print()
    print(f"Tier A (marker + cross-validated): {raw_stats['tier_a_raw']} → {len(a_f)} after phonotactic")
    print(f"Tier B (marker, single phrase):    {raw_stats['tier_b_raw']} → {len(b_f)} after phonotactic")
    print(f"Tier C (ASCII loanword ≥3):        {raw_stats['tier_c_raw']} → {len(c_f)} after curated whitelist")

    additions = a_f | b_f | c_f
    new_vn = current_vn | additions

    additions_stats = {
        "tier_a": sorted(a_f)[:50],
        "tier_b": sorted(b_f)[:50],
        "tier_c": sorted(c_f),
        "total_added": len(additions),
    }

    print()
    print(f"total additions: {len(additions)}")
    print(f"new vietnamese[] size: {len(new_vn)}")
    print()
    print("Sample additions Tier A:", sorted(a_f)[:15])
    print("Sample additions Tier B:", sorted(b_f)[:15])
    print("Tier C kept:", sorted(c_f))

    if args.dry_run:
        return 0

    pkg["vietnamese"] = sorted(new_vn)
    pkg["version"] = (pkg.get("version") or 0) + 1

    pkg = merge_meta(pkg, {
        "tier_a_added": len(a_f),
        "tier_b_added": len(b_f),
        "tier_c_added": len(c_f),
        "total_added": len(additions),
    })

    args.out_path.write_text(
        json.dumps(pkg, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print()
    print(f"new package version: {pkg['version']}")
    print(f"wrote: {args.out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
