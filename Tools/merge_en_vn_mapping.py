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

  - Loại mọi key trùng cách gõ Telex của một âm tiết tiếng Việt — dạng trần
    ("ban", "cam", "tao"), dạng có phím dấu cuối ("cas" = "cá", "banj" =
    "bạn"), VÀ dạng có phím biến nguyên âm ("mow" = "mơ", "coo" = "cô",
    "hoof" = "hồ"). Đây là bộ lọc quan trọng nhất: không có nó, vkey sẽ
    khôi phục về phím thô đúng lúc người dùng vừa gõ xong một từ tiếng Việt.
    Luật nằm ở `Tools/lexicon_common.py` để mọi script dùng chung một bản.
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
from datetime import datetime, timezone
from pathlib import Path

from lexicon_common import (
    MAX_STRING_LENGTH,
    add_source,
    atomic_write_json,
    build_blocklist,
    collides_with_vietnamese,
)

KEY_RE = re.compile(r"^[a-z][a-z-]{2,}$")
MAX_CANDIDATES = 2
MAX_CANDIDATE_LEN = 48
# Bỏ phần chú giải trong ngoặc: "máy tính (điện tử)" → "máy tính"
PAREN_RE = re.compile(r"\s*[（(\[].*?[）)\]]\s*")


def clean_candidate(raw: str) -> str | None:
    value = PAREN_RE.sub(" ", raw).strip().strip(",;/")
    value = re.sub(r"\s+", " ", value)
    if not value or len(value) > MAX_CANDIDATE_LEN:
        return None
    # Chỉ chấp nhận chữ Latin (kể cả có dấu tiếng Việt), khoảng trắng, gạch nối.
    if not all(c.isalpha() or c in " -'" for c in value):
        return None
    return value


def extract_pairs(stream, blocked: set[str], telex_forms: set[str],
                  allowed: set[str], limit: int | None):
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
        # Chỉ lấy mục từ tiếng Anh của English Wiktionary. Trước đây chỗ này
        # nhận cả entry KHÔNG khai `lang_code`, trái với chính comment của nó —
        # dump có mục nhiều ngôn ngữ, bỏ trống không có nghĩa là tiếng Anh.
        if entry.get("lang_code") != "en":
            continue
        word = (entry.get("word") or "").strip().lower()
        if not word or not word.isascii() or not KEY_RE.match(word):
            continue
        seen += 1
        if word not in allowed:
            continue
        if collides_with_vietnamese(word, blocked, telex_forms):
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
    blocked, telex_forms = build_blocklist(vietnamese)
    problems: list[str] = []

    if not mapping:
        problems.append("en_vn_mapping rỗng")

    collisions = sorted(k for k in mapping
                        if collides_with_vietnamese(k, blocked, telex_forms))
    if collisions:
        problems.append(
            f"{len(collisions)} key trùng âm tiết VN, vd {collisions[:8]}")

    bad_keys = sorted(k for k in mapping if not KEY_RE.match(k))
    if bad_keys:
        problems.append(f"{len(bad_keys)} key sai dạng, vd {bad_keys[:8]}")

    # Giới hạn của LexiconUpdatePackage.validated() phía Swift.
    over_key = [k for k in mapping if len(k) > MAX_STRING_LENGTH]
    over_val = [k for k, v in mapping.items()
                if len(v) > 3 or any(len(c) > MAX_STRING_LENGTH for c in v)]
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


def prune_collisions(path: Path, dry_run: bool = False) -> int:
    """
    Xoá các key `en_vn_mapping` trùng cách gõ Telex của một âm tiết tiếng Việt.

    Cần đến hàm này vì bộ lọc siết dần: khi thêm một lớp chặn mới, dữ liệu đã
    ship vẫn mang những key lọt qua bộ lọc cũ. Chạy lại cả dump Kaikki 2,5 GB
    chỉ để bỏ vài key là không đáng, và cũng không tái lập được y hệt (dump
    thay đổi theo thời gian).
    """
    pkg = json.loads(path.read_text(encoding="utf-8"))
    mapping = pkg.get("en_vn_mapping") or {}
    blocked, telex_forms = build_blocklist(pkg.get("vietnamese") or [])

    bad = sorted(k for k in mapping
                 if collides_with_vietnamese(k, blocked, telex_forms))
    if not bad:
        print("[prune] không có key nào trùng — không đổi gì.", file=sys.stderr)
        return 0

    for k in bad:
        print(f"[prune] bỏ {k!r} (= cách gõ của một âm tiết VN) → {mapping[k]}",
              file=sys.stderr)
        del mapping[k]

    old_version = int(pkg.get("version", 0))
    if dry_run:
        print(f"[prune] DRY-RUN: sẽ bỏ {len(bad)} key, "
              f"version {old_version} → {old_version + 1}", file=sys.stderr)
        return 0

    pkg["en_vn_mapping"] = mapping
    pkg["version"] = old_version + 1
    meta = pkg.setdefault("_meta", {})
    meta.setdefault("cleanup", []).append({
        "at": datetime.now(timezone.utc).isoformat(),
        "rule": ("merge_en_vn_mapping.py --prune-collisions — bỏ key trùng "
                 "chuỗi phím Telex của âm tiết VN (lớp phím biến nguyên âm)"),
        "before": len(mapping) + len(bad),
        "after": len(mapping),
        "removed": bad,
        "baseline_ref": f"lexicon v{old_version}",
    })
    atomic_write_json(path, pkg)
    print(f"[prune] đã ghi {path} — bỏ {len(bad)} key, "
          f"version {old_version} → {pkg['version']}", file=sys.stderr)
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--verify", type=Path,
                   help="Chỉ kiểm bất biến của một file đã ghi rồi thoát")
    p.add_argument("--prune-collisions", type=Path,
                   help="Xoá khỏi file các key en_vn_mapping trùng cách gõ Telex "
                        "của một âm tiết VN, bump version, rồi thoát. Dùng khi "
                        "bộ lọc siết lại mà không muốn chạy lại cả dump Kaikki.")
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
    if args.prune_collisions:
        return prune_collisions(args.prune_collisions, dry_run=args.dry_run)
    if not args.kaikki:
        p.error("cần --kaikki (hoặc --verify / --prune-collisions)")

    pkg = json.loads(args.src.read_text(encoding="utf-8"))
    vietnamese = pkg.get("vietnamese") or []
    blocked, telex_forms = build_blocklist(vietnamese)

    import wordfreq  # noqa: PLC0415 — chỉ cần khi chạy script, không phải khi import
    already_english = {w.lower() for w in (pkg.get("english") or [])}
    allowed = {w for w in wordfreq.top_n_list("en", args.top_english)
               if KEY_RE.match(w)} - already_english
    print(f"[merge_en_vn] chặn {len(blocked):,} dạng không dấu + "
          f"{len(telex_forms):,} chuỗi phím Telex | "
          f"ứng viên EN sau khi trừ {len(already_english):,} từ đã có: "
          f"{len(allowed):,}", file=sys.stderr)

    opener = gzip.open if str(args.kaikki).endswith(".gz") else open
    with opener(args.kaikki, "rt", encoding="utf-8", errors="replace") as stream:
        mapping = extract_pairs(stream, blocked, telex_forms, allowed, args.limit)

    if not mapping:
        print("[merge_en_vn] LỖI: không trích được entry nào — dừng, không ghi.",
              file=sys.stderr)
        return 1

    old_version = int(pkg.get("version", 0))
    pkg["en_vn_mapping"] = dict(sorted(mapping.items()))
    pkg["version"] = old_version + 1
    meta = pkg.setdefault("_meta", {})
    add_source(meta, {
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

    atomic_write_json(args.dst, pkg)
    print(f"[merge_en_vn] đã ghi {args.dst} — en_vn_mapping={len(mapping):,}, "
          f"version {old_version} → {pkg['version']}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
