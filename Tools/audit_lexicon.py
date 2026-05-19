#!/usr/bin/env python3
"""
Tools/audit_lexicon.py — chuẩn hoá lexicon-update.json sau khi merge thô từ
nguồn ngoài (vd undertheseanlp/dictionary). Loại bỏ noise có thể gây sai
spell-check / typo correction.

Rules (giữ conservative):

  1. Loại HOÀN TOÀN entry single-char (a, b, c, à, á, ...). Chữ cái độc lập
     KHÔNG phải syllable; nếu để lại, engine sẽ nhận "I" là VN word → mọi
     thứ break.

  2. Với entry NEW (không có trong baseline curated 7184):
     - Phải chứa ít nhất 1 ký tự diacritic VN (à/á/ạ/ả/ã, ă, â, đ, ê,
       ơ, ư, ...) HOẶC
     - Phải có shape syllable VN rõ rệt (vd "ng"-prefix consonant cluster)
     Khác → loại (likely English/Latin loanword không phổ thông trong VN).

  3. Baseline curated 7184 (snapshot từ commit 1.6.0): giữ NGUYÊN — đã
     được audit thủ công + maintainer trusted.

Output: ghi đè lexicon-update.json với:
  - vietnamese[] đã cleaned + sort
  - version bumped +1
  - _meta.cleanup ghi nhận audit pass

Usage:
    python3 Tools/audit_lexicon.py \\
        --in lexicon-update.json \\
        --baseline-ref ac456f9 \\
        --out lexicon-update.json

License: GPL-3.0
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


# Tập ký tự VN có diacritic (NFC). Bao gồm dấu thanh + chữ riêng VN.
VN_DIACRITIC_CHARS = set(
    "àáảãạăắằẳẵặâấầẩẫậ"
    "èéẻẽẹêếềểễệ"
    "ìíỉĩị"
    "òóỏõọôốồổỗộơớờởỡợ"
    "ùúủũụưứừửữự"
    "ỳýỷỹỵ"
    "đ"
)

# Cluster phụ âm đầu rõ rệt VN (không có trong English) — dùng làm dấu
# hiệu phụ trợ khi entry không có diacritic nhưng vẫn là VN syllable.
VN_INITIAL_CLUSTERS = {"ng", "ngh", "nh", "kh", "ph", "th", "tr", "ch", "gh", "gi", "qu"}


def has_vn_diacritic(word: str) -> bool:
    return any(c in VN_DIACRITIC_CHARS for c in word.lower())


def has_vn_initial_cluster(word: str) -> bool:
    low = word.lower()
    for cluster in VN_INITIAL_CLUSTERS:
        if low.startswith(cluster) and len(low) > len(cluster):
            return True
    return False


def load_baseline(ref: str, repo_root: Path) -> set[str]:
    """Read lexicon-update.json from a git ref, returning the vietnamese[] set."""
    res = subprocess.run(
        ["git", "-C", str(repo_root), "show", f"{ref}:lexicon-update.json"],
        capture_output=True, text=True, check=True,
    )
    pkg = json.loads(res.stdout)
    return set(pkg.get("vietnamese") or [])


def audit(raw: set[str], baseline: set[str]) -> tuple[set[str], dict]:
    final: set[str] = set()
    dropped_single: list[str] = []
    dropped_no_vn_markers: list[str] = []
    kept_from_baseline = 0
    kept_new = 0

    for w in raw:
        word = unicodedata.normalize("NFC", w.strip().lower())
        if not word:
            continue
        if len(word) == 1:
            dropped_single.append(word)
            continue
        if word in baseline:
            final.add(word)
            kept_from_baseline += 1
            continue
        if has_vn_diacritic(word) or has_vn_initial_cluster(word):
            final.add(word)
            kept_new += 1
        else:
            dropped_no_vn_markers.append(word)

    return final, {
        "before": len(raw),
        "after": len(final),
        "dropped_total": len(dropped_single) + len(dropped_no_vn_markers),
        "dropped_single_char": len(dropped_single),
        "dropped_no_vn_markers": len(dropped_no_vn_markers),
        "kept_from_baseline": kept_from_baseline,
        "kept_new": kept_new,
        "dropped_single_sample": sorted(dropped_single)[:20],
        "dropped_no_vn_sample": sorted(dropped_no_vn_markers)[:30],
    }


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--in", dest="in_path", type=Path,
                   default=Path("lexicon-update.json"),
                   help="Input lexicon-update.json (default: ./lexicon-update.json)")
    p.add_argument("--out", dest="out_path", type=Path,
                   default=Path("lexicon-update.json"),
                   help="Output path (default: same as --in for in-place)")
    p.add_argument("--baseline-ref", default="ac456f9",
                   help="Git ref of curated baseline (default: ac456f9 = v1.6.0)")
    p.add_argument("--repo-root", type=Path, default=Path("."),
                   help="Git repo root for baseline lookup")
    p.add_argument("--dry-run", action="store_true",
                   help="Print stats only, don't write")
    args = p.parse_args(argv)

    if not args.in_path.exists():
        print(f"error: input not found: {args.in_path}", file=sys.stderr)
        return 1

    pkg = json.loads(args.in_path.read_text(encoding="utf-8"))
    raw_vn = set(pkg.get("vietnamese") or [])

    try:
        baseline = load_baseline(args.baseline_ref, args.repo_root)
    except subprocess.CalledProcessError as e:
        print(f"error: cannot load baseline at {args.baseline_ref}: {e.stderr}",
              file=sys.stderr)
        return 1

    print(f"baseline (curated) @ {args.baseline_ref}: {len(baseline)} entries")
    cleaned, stats = audit(raw_vn, baseline)

    print()
    print("=== Audit stats ===")
    for k, v in stats.items():
        if k.endswith("sample"):
            print(f"  {k}: {v}")
        else:
            print(f"  {k}: {v}")

    if args.dry_run:
        return 0

    pkg["vietnamese"] = sorted(cleaned)
    pkg["version"] = (pkg.get("version") or 0) + 1

    meta = pkg.get("_meta") or {}
    cleanup_log = meta.get("cleanup") or []
    cleanup_log.append({
        "at": datetime.now(timezone.utc).isoformat(),
        "rule": "audit_lexicon.py — drop single-char + drop new no-VN-marker",
        "before": stats["before"],
        "after": stats["after"],
        "baseline_ref": args.baseline_ref,
    })
    meta["cleanup"] = cleanup_log
    pkg["_meta"] = meta

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
