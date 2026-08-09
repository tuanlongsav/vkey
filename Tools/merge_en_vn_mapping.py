#!/usr/bin/env python3
"""
Tools/merge_en_vn_mapping.py — thêm `en_vn_mapping` vào lexicon-update.json.

Vì sao có script riêng thay vì dùng Tools/build_lexicon.py:
`build_lexicon.py` dựng lại TOÀN BỘ file và ghi cứng `"version": 5` cùng một
khối `_meta` mới. Chạy nó lên file hiện tại (version 10) sẽ hạ version →
KHÔNG client nào nhận cập nhật nữa, và xoá sạch `_meta.cleanup` (nhật ký các
đợt audit). Script này chỉ chạm đúng một trường, giữ nguyên phần còn lại.

    python3 Tools/merge_en_vn_mapping.py \\
        --kaikki ~/.cache/vkey/raw-wiktextract-data.jsonl.gz \\
        --in lexicon-update.json --out lexicon-update.json

Bộ lọc — quan trọng hơn số lượng entry:

`en_vn_mapping` KHÔNG chỉ là dữ liệu tra cứu. Hiện KHÔNG view nào đọc
`EnVnReference.enToVn`; tác dụng thật duy nhất là `SpellDecisionEngine` coi
mọi key trong đó là "từ tiếng Anh" (chú thích 1.5.0 trong file đó), tức mỗi
entry thêm vào đều nới rộng phạm vi Space Restore. Nghĩa tiếng Việt được giữ
lại vì schema hứa vậy và một UI tra cứu sau này sẽ cần, nhưng hôm nay chúng
chỉ là payload. Vì vậy phải chặt tay:

  - Loại mọi key trùng cách gõ Telex của một âm tiết tiếng Việt — cả dạng
    trần ("ban", "cam", "tao") lẫn dạng có phím dấu cuối ("cas" = "cá",
    "banj" = "bạn"). Đây là bộ lọc quan trọng nhất: không có nó, vkey sẽ
    khôi phục về phím thô đúng lúc người dùng vừa gõ xong một từ tiếng Việt.
  - Chỉ nhận từ nằm trong top-N tiếng Anh theo tần suất (`--top-english`,
    mặc định 30000). Từ hiếm hơn thì gần như không ai gõ nhầm trong chế độ
    tiếng Việt, mà mỗi entry đều cộng vào dung lượng người dùng tải HÀNG NGÀY.
  - Bỏ key đã có trong `english[]`: chúng vốn đã được nhận là tiếng Anh nên
    entry chỉ làm phình file mà không đổi hành vi gì.
  - Chỉ nhận key ASCII thường, >= 3 ký tự, chỉ chữ cái và dấu gạch nối.
  - Bỏ nghĩa tiếng Việt quá dài / rỗng / trùng; giữ tối đa 2 ứng viên.

License: GPL-3.0 (như phần còn lại của dự án).
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

KEY_RE = re.compile(r"^[a-z][a-z-]{2,}$")
MAX_CANDIDATES = 2
MAX_CANDIDATE_LEN = 48
# Bỏ phần chú giải trong ngoặc: "máy tính (điện tử)" → "máy tính"
PAREN_RE = re.compile(r"\s*[（(\[].*?[）)\]]\s*")


TELEX_TONE_KEYS = "sfrxj"


def bare(word: str) -> str:
    """Dạng không dấu của một âm tiết tiếng Việt ('cấm' → 'cam')."""
    word = word.replace("đ", "d").replace("Đ", "d")
    return "".join(
        c for c in unicodedata.normalize("NFD", word)
        if unicodedata.category(c) != "Mn"
    ).lower()


def collides_with_vietnamese(word: str, blocked: set[str]) -> bool:
    """
    True nếu `word` chính là cách gõ Telex của một âm tiết tiếng Việt.

    Hai lớp:
      1. Trùng thẳng dạng không dấu — "ban", "cam", "tao".
      2. Trùng sau khi bỏ phím dấu cuối — "cas" là cách gõ "cá", "banj" là
         "bạn". Không lọc lớp này thì Space Restore sẽ khôi phục về phím thô
         đúng lúc người dùng vừa gõ xong một từ tiếng Việt có dấu.
    """
    b = bare(word)
    if b in blocked:
        return True
    if len(b) > 1 and b[-1] in TELEX_TONE_KEYS and b[:-1] in blocked:
        return True
    return False


def clean_candidate(raw: str) -> str | None:
    value = PAREN_RE.sub(" ", raw).strip().strip(",;/")
    value = re.sub(r"\s+", " ", value)
    if not value or len(value) > MAX_CANDIDATE_LEN:
        return None
    # Chỉ chấp nhận chữ Latin (kể cả có dấu tiếng Việt), khoảng trắng, gạch nối.
    if not all(c.isalpha() or c in " -'" for c in value):
        return None
    return value


def extract_pairs(stream, blocked: set[str], allowed: set[str], limit: int | None):
    """Duyệt dump Kaikki, trả về {en: [vi, ...]} đã lọc."""
    out: dict[str, list[str]] = {}
    seen = kept = 0
    for i, line in enumerate(stream):
        if limit is not None and i >= limit:
            break
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        # Chỉ lấy mục từ tiếng Anh của English Wiktionary.
        if entry.get("lang_code") not in (None, "en"):
            continue
        word = (entry.get("word") or "").strip().lower()
        if not word or not word.isascii() or not KEY_RE.match(word):
            continue
        seen += 1
        if word not in allowed:
            continue
        if collides_with_vietnamese(word, blocked):
            continue
        candidates: list[str] = []
        for t in entry.get("translations") or []:
            if t.get("code") != "vi" and t.get("lang_code") != "vi":
                continue
            value = clean_candidate(t.get("word") or "")
            if value and value not in candidates:
                candidates.append(value)
            if len(candidates) >= MAX_CANDIDATES:
                break
        if not candidates:
            continue
        merged = out.setdefault(word, [])
        for c in candidates:
            if c not in merged:
                merged.append(c)
        out[word] = merged[:MAX_CANDIDATES]
        kept += 1
    print(f"[merge_en_vn] mục EN hợp lệ: {seen:,} | có bản dịch VI: {kept:,} "
          f"| key duy nhất: {len(out):,}", file=sys.stderr)
    return out


def verify(path: Path) -> int:
    """Kiểm lại bất biến trên file đã ghi. Trả 0 nếu đạt."""
    pkg = json.loads(path.read_text(encoding="utf-8"))
    mapping = pkg.get("en_vn_mapping") or {}
    vietnamese = pkg.get("vietnamese") or []
    blocked = {bare(w) for w in vietnamese}
    problems: list[str] = []

    if not mapping:
        problems.append("en_vn_mapping rỗng")

    collisions = sorted(k for k in mapping if collides_with_vietnamese(k, blocked))
    if collisions:
        problems.append(
            f"{len(collisions)} key trùng âm tiết VN, vd {collisions[:8]}")

    bad_keys = sorted(k for k in mapping if not KEY_RE.match(k))
    if bad_keys:
        problems.append(f"{len(bad_keys)} key sai dạng, vd {bad_keys[:8]}")

    # Giới hạn của LexiconUpdatePackage.validated() phía Swift.
    over_key = [k for k in mapping if len(k) > 256]
    over_val = [k for k, v in mapping.items()
                if len(v) > 3 or any(len(c) > 256 for c in v)]
    if over_key:
        problems.append(f"{len(over_key)} key vượt 256 ký tự")
    if over_val:
        problems.append(f"{len(over_val)} entry vượt giới hạn giá trị")

    empty = sorted(k for k, v in mapping.items() if not v)
    if empty:
        problems.append(f"{len(empty)} entry không có nghĩa nào")

    print(f"[verify] {path}: en_vn_mapping={len(mapping):,} "
          f"version={pkg.get('version')} "
          f"vietnamese={len(vietnamese):,} english={len(pkg.get('english') or []):,}",
          file=sys.stderr)
    for p_ in problems:
        print(f"[verify] ✗ {p_}", file=sys.stderr)
    if not problems:
        print("[verify] ✓ mọi bất biến đều đạt", file=sys.stderr)
    return 1 if problems else 0


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--verify", type=Path,
                   help="Chỉ kiểm bất biến của một file đã ghi rồi thoát")
    p.add_argument("--kaikki", type=Path,
                   help="Dump Kaikki wiktextract (.jsonl hoặc .jsonl.gz)")
    p.add_argument("--in", dest="src", type=Path, default=Path("lexicon-update.json"))
    p.add_argument("--out", dest="dst", type=Path, default=Path("lexicon-update.json"))
    p.add_argument("--top-english", type=int, default=30000,
                   help="Chỉ nhận từ nằm trong top-N tiếng Anh theo wordfreq")
    p.add_argument("--limit", type=int, default=None,
                   help="Chỉ đọc N dòng đầu (smoke test)")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if args.verify:
        return verify(args.verify)
    if not args.kaikki:
        p.error("cần --kaikki (hoặc --verify)")

    pkg = json.loads(args.src.read_text(encoding="utf-8"))
    vietnamese = pkg.get("vietnamese") or []
    blocked = {bare(w) for w in vietnamese}

    import wordfreq  # noqa: PLC0415 — chỉ cần khi chạy script, không phải khi import
    already_english = {w.lower() for w in (pkg.get("english") or [])}
    allowed = {w for w in wordfreq.top_n_list("en", args.top_english)
               if KEY_RE.match(w)} - already_english
    print(f"[merge_en_vn] chặn {len(blocked):,} dạng âm tiết VN không dấu | "
          f"ứng viên EN sau khi trừ {len(already_english):,} từ đã có: "
          f"{len(allowed):,}", file=sys.stderr)

    opener = gzip.open if str(args.kaikki).endswith(".gz") else open
    with opener(args.kaikki, "rt", encoding="utf-8", errors="replace") as stream:
        mapping = extract_pairs(stream, blocked, allowed, args.limit)

    if not mapping:
        print("[merge_en_vn] LỖI: không trích được entry nào — dừng, không ghi.",
              file=sys.stderr)
        return 1

    old_version = int(pkg.get("version", 0))
    pkg["en_vn_mapping"] = dict(sorted(mapping.items()))
    pkg["version"] = old_version + 1
    meta = pkg.setdefault("_meta", {})
    meta.setdefault("sources", []).append({
        "name": "English Wiktionary via Wiktextract / Kaikki.org",
        "url": "https://kaikki.org/dictionary/rawdata.html",
        "license": "CC BY-SA 4.0",
        "used_for": "en_vn_mapping{}",
    })
    meta.setdefault("cleanup", []).append({
        "at": datetime.now(timezone.utc).isoformat(),
        "rule": "merge_en_vn_mapping.py — Kaikki EN→VI, bỏ key trùng âm tiết VN",
        "before": 0,
        "after": len(mapping),
        "baseline_ref": f"lexicon v{old_version}",
    })

    if args.dry_run:
        print(f"[merge_en_vn] DRY-RUN: sẽ ghi {len(mapping):,} entry, "
              f"version {old_version} → {pkg['version']}", file=sys.stderr)
        return 0

    args.dst.write_text(
        json.dumps(pkg, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print(f"[merge_en_vn] đã ghi {args.dst} — en_vn_mapping={len(mapping):,}, "
          f"version {old_version} → {pkg['version']}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
