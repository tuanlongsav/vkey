#!/usr/bin/env python3
"""
Tools/build_lexicon.py — assemble lexicon-update.json (schema v5).

Combines three open-licensed sources into vkey's distribution lexicon:

  1. English Wiktionary via Wiktextract / Kaikki.org (CC BY-SA 4.0)
     → en_vn_mapping (English → [Vietnamese candidates])

  2. wordfreq by Robyn Speer (MIT for code, CC BY-SA 4.0 for Wiktionary-
     derived data inside the package)
     → english[] (top-N most common English words, used for spell-check
       restoration regardless of whether they have a Vietnamese translation)

  3. Hand-curated seed bundled at the bottom of this file (mostly
     programming / business / day-to-day terms that have very obvious
     Vietnamese renderings we don't want to wait on Wiktionary for)

All three are GPL-3.0 / CC BY-SA 4.0 compatible. Attribution is written into
`_meta.sources` so downstream readers can audit.

Usage:

    pip install wordfreq requests
    python3 Tools/build_lexicon.py \\
        --out lexicon-update.json \\
        --top-english 5000 \\
        --kaikki-download

The `--kaikki-download` flag pulls the latest English Wiktextract dump
(2.5GB compressed). Omit it to skip the bilingual expansion entirely —
useful for fast smoke runs where you only need the wordlist shape.

License: GPL-3.0 (same as the vkey project).
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from lexicon_common import (
    SCHEMA_VERSION,
    add_source,
    atomic_write_json,
    build_blocklist,
    clamp_mapping,
    collides_with_vietnamese,
)

KAIKKI_URL = "https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz"

# Dump thật ~2,5 GB nén. Bất cứ thứ gì nhỏ hơn ngưỡng này là tải dở hoặc là
# trang lỗi HTML — dùng nó thì từ điển thiếu mà không có dấu hiệu gì.
MIN_KAIKKI_BYTES = 1_000_000_000

# ---------------------------------------------------------------------------
# Hand-curated seed
# ---------------------------------------------------------------------------
#
# This is the minimum English → Vietnamese map vkey ships with even without
# running the Wiktionary extraction. Kept small (~120 entries) and skewed
# toward terms that vkey users actually mistype into the wrong mode (we
# learned this from the existing English wordlist in EmbeddedLexiconData,
# which only ships "function-word" frequencies — no nouns or verbs).
#
# When extending: prefer one or two canonical translations per entry. The
# spell engine doesn't disambiguate, so a long synonyms list won't help.
# Every entry must come from public-domain / open knowledge — do NOT
# transcribe definitions from commercial dictionaries.
#
# Entries here are NOT exempt from the Telex collision filter. About a sixth of
# this list ("the", "of", "if", "do", "go", "see"…) happens to spell a
# Vietnamese syllable in Telex, and every key in `en_vn_mapping` is read as an
# English word by SpellDecisionEngine — so keeping them would fire Space Restore
# right after the user typed "thế" / "ổ" / "ì". `build()` drops them and says
# how many; do not add a bypass.

SEED_EN_VN_MAPPING: dict[str, list[str]] = {
    # Function words & connectives
    "and": ["và"],
    "or": ["hoặc", "hay"],
    "of": ["của"],
    "if": ["nếu"],
    "but": ["nhưng"],
    "with": ["với"],
    "for": ["cho"],
    "the": ["cái", "con"],
    "this": ["này"],
    "that": ["đó", "kia"],
    "all": ["tất cả"],
    "some": ["một số", "vài"],
    "many": ["nhiều"],
    "few": ["ít"],

    # Day-to-day nouns
    "name": ["tên"],
    "house": ["nhà"],
    "country": ["nước", "quốc gia"],
    "city": ["thành phố"],
    "school": ["trường", "trường học"],
    "book": ["sách"],
    "table": ["bàn"],
    "chair": ["ghế"],
    "water": ["nước"],
    "food": ["thức ăn", "đồ ăn"],
    "money": ["tiền"],
    "time": ["thời gian", "giờ"],
    "day": ["ngày"],
    "night": ["đêm"],
    "year": ["năm"],
    "people": ["người", "mọi người"],
    "friend": ["bạn"],
    "family": ["gia đình"],
    "love": ["tình yêu", "yêu"],
    "life": ["cuộc sống", "đời"],
    "work": ["công việc", "việc"],
    "home": ["nhà"],
    "world": ["thế giới"],
    "music": ["âm nhạc", "nhạc"],
    "phone": ["điện thoại"],
    "car": ["xe hơi", "ô tô"],

    # Verbs
    "see": ["thấy", "nhìn"],
    "go": ["đi"],
    "come": ["đến"],
    "do": ["làm"],
    "say": ["nói"],
    "think": ["nghĩ"],
    "know": ["biết"],
    "want": ["muốn"],
    "have": ["có"],
    "make": ["làm", "tạo"],
    "find": ["tìm"],
    "give": ["cho", "đưa"],
    "take": ["lấy", "nhận"],
    "use": ["dùng", "sử dụng"],
    "read": ["đọc"],
    "write": ["viết"],
    "listen": ["nghe"],
    "speak": ["nói"],
    "learn": ["học"],
    "teach": ["dạy"],
    "buy": ["mua"],
    "sell": ["bán"],

    # Adjectives
    "good": ["tốt"],
    "bad": ["xấu", "tệ"],
    "big": ["to", "lớn"],
    "small": ["nhỏ"],
    "happy": ["vui", "hạnh phúc"],
    "sad": ["buồn"],
    "fast": ["nhanh"],
    "slow": ["chậm"],
    "easy": ["dễ"],
    "hard": ["khó"],
    "new": ["mới"],
    "old": ["cũ", "già"],

    # Technology / programming (vkey users skew tech-heavy)
    "computer": ["máy tính"],
    "developer": ["lập trình viên", "nhà phát triển"],
    "code": ["mã"],
    "function": ["hàm", "chức năng"],
    "class": ["lớp"],
    "variable": ["biến"],
    "test": ["kiểm tra", "thử nghiệm"],
    "deploy": ["triển khai"],
    "release": ["phát hành"],
    "version": ["phiên bản"],
    "update": ["cập nhật"],
    "fix": ["sửa"],
    "bug": ["lỗi"],
    "feature": ["tính năng"],
    "design": ["thiết kế"],
    "user": ["người dùng"],
    "server": ["máy chủ"],
    "client": ["máy khách"],
    "database": ["cơ sở dữ liệu"],
    "file": ["tệp", "tập tin"],
    "folder": ["thư mục"],
    "internet": ["mạng", "internet"],
    "website": ["trang web"],
    "email": ["thư điện tử"],
    "password": ["mật khẩu"],
    "username": ["tên đăng nhập"],
    "login": ["đăng nhập"],
    "register": ["đăng ký"],

    # Business
    "business": ["doanh nghiệp", "kinh doanh"],
    "company": ["công ty"],
    "office": ["văn phòng"],
    "meeting": ["cuộc họp"],
    "project": ["dự án"],
    "team": ["nhóm", "đội"],
    "manager": ["quản lý"],
    "report": ["báo cáo"],
}


def load_wordfreq_top(n: int) -> list[str]:
    """Top-N most frequent English words via the `wordfreq` library."""
    try:
        from wordfreq import top_n_list  # type: ignore
    except ImportError:
        print("[build_lexicon] wordfreq not installed — skipping english[] expansion.",
              file=sys.stderr)
        return []
    return top_n_list("en", n, wordlist="best")


def parse_kaikki_stream(stream: io.IOBase, max_entries: int | None = None) -> Iterable[dict]:
    """Yield decoded JSONL entries from a Kaikki wiktextract dump."""
    for i, line in enumerate(stream):
        if max_entries is not None and i >= max_entries:
            break
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


def extract_en_vn_pairs(stream: io.IOBase, limit: int | None = None) -> dict[str, list[str]]:
    """
    Walk a Kaikki English Wiktextract stream and pull English → Vietnamese
    translation pairs out of the `translations` field of each entry.

    `wiktextract` schema: each entry has a `word`, `senses[]`, and a
    flattened `translations[]` array. Each translation has `code` (ISO),
    `word` (target), and optionally `sense`. We don't try to disambiguate by
    sense — vkey's downstream consumer wants 1–3 canonical renderings.
    """
    out: dict[str, list[str]] = {}
    for entry in parse_kaikki_stream(stream, max_entries=limit):
        en_word = (entry.get("word") or "").strip().lower()
        if not en_word or not en_word.isascii() or not en_word.replace("-", "").isalpha():
            continue
        translations = entry.get("translations") or []
        vi_words: list[str] = []
        for t in translations:
            if t.get("code") != "vi" and t.get("lang_code") != "vi":
                continue
            target = (t.get("word") or "").strip()
            if target and target not in vi_words:
                vi_words.append(target)
            if len(vi_words) >= 3:
                break
        if vi_words:
            existing = out.get(en_word, [])
            for candidate in vi_words:
                if candidate not in existing:
                    existing.append(candidate)
            out[en_word] = existing[:3]
    return out


def download_kaikki(target: Path) -> Path:
    """
    Stream-download the Kaikki dump if not already present.

    Downloads to a `.part` file and only renames on success. The previous
    version wrote straight to `target` and treated any existing file as
    complete, so a Ctrl-C (or a dropped connection) 2 GB into a 2.5 GB download
    left a truncated archive that every later run happily reused: gzip stops at
    the truncation point without erroring, and you get a quietly short
    dictionary with no indication anything went wrong.
    """
    if target.exists():
        size = target.stat().st_size
        if size < MIN_KAIKKI_BYTES:
            raise SystemExit(
                f"[build_lexicon] cached dump looks truncated: {target} is "
                f"{size:,} bytes, expected at least {MIN_KAIKKI_BYTES:,}.\n"
                f"Delete it and re-run to download again."
            )
        return target

    print(f"[build_lexicon] downloading {KAIKKI_URL} → {target} (large file, ~2.5GB)…",
          file=sys.stderr)
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_name(target.name + ".part")
    try:
        with urllib.request.urlopen(KAIKKI_URL, timeout=120) as r, open(part, "wb") as f:
            while True:
                chunk = r.read(1 << 20)  # 1 MiB
                if not chunk:
                    break
                f.write(chunk)
        size = part.stat().st_size
        if size < MIN_KAIKKI_BYTES:
            raise SystemExit(
                f"[build_lexicon] download ended at {size:,} bytes, expected at "
                f"least {MIN_KAIKKI_BYTES:,} — server error page or dropped "
                f"connection. Not caching it."
            )
        os.replace(part, target)
    except BaseException:
        part.unlink(missing_ok=True)
        raise
    return target


def build(
    output_path: Path,
    top_english: int,
    kaikki_download: bool,
    kaikki_path: Path | None,
    max_kaikki_entries: int | None,
) -> None:
    # Vietnamese list: keep whatever the previous version of the file already
    # carries (we don't regenerate vietnamese[] in this script — that data
    # comes from common-vietnamese-syllables by @hieuthi, see CHANGELOG).
    previous: dict = {}
    if output_path.exists():
        with open(output_path, "r", encoding="utf-8") as f:
            previous = json.load(f)

    vietnamese = previous.get("vietnamese") or []
    keep = previous.get("keep") or []

    english_top = load_wordfreq_top(top_english)
    english: list[str] = sorted(set(english_top + list(previous.get("english") or [])))

    # `en_vn_mapping` bắt đầu từ NỘI DUNG CŨ, không từ SEED. Trước đây dòng này
    # là `dict(SEED_EN_VN_MAPPING)` và `previous["en_vn_mapping"]` không bao giờ
    # được đọc — chạy script lên gói hiện tại là thay 3.000 cặp đã qua bộ lọc
    # va chạm bằng ~110 seed cộng dump Kaikki thô, rồi vẫn bump version nên mọi
    # client tải về. SEED và Kaikki từ đây chỉ ĐIỀN CHỖ TRỐNG.
    en_vn: dict[str, list[str]] = dict(previous.get("en_vn_mapping") or {})
    carried_over = len(en_vn)
    for k, v in SEED_EN_VN_MAPPING.items():
        en_vn.setdefault(k, v)

    if kaikki_path is None and kaikki_download:
        kaikki_path = Path.home() / ".cache" / "vkey" / "raw-wiktextract-data.jsonl.gz"
        download_kaikki(kaikki_path)

    if kaikki_path is not None and kaikki_path.exists():
        print(f"[build_lexicon] parsing {kaikki_path}…", file=sys.stderr)
        opener = gzip.open if str(kaikki_path).endswith(".gz") else open
        with opener(kaikki_path, "rt", encoding="utf-8") as stream:
            extracted = extract_en_vn_pairs(stream, limit=max_kaikki_entries)
        for k, v in extracted.items():
            en_vn.setdefault(k, v)
        print(f"[build_lexicon] +{len(extracted)} entries from Kaikki "
              f"(total en_vn_mapping = {len(en_vn)})",
              file=sys.stderr)
    else:
        extracted = {}

    # Bộ lọc va chạm Telex + giới hạn của `validated()` phía Swift. Hai thứ này
    # trước đây chỉ có trong merge_en_vn_mapping.py, nên đường build này sinh ra
    # gói mà (a) làm Space Restore bắn nhầm giữa lúc gõ tiếng Việt, và (b) có
    # thể vượt giới hạn 256 ký tự khiến client từ chối NGUYÊN gói, im lặng.
    blocked, telex_forms = build_blocklist(vietnamese)
    colliding = [k for k in en_vn if collides_with_vietnamese(k, blocked, telex_forms)]
    for k in colliding:
        del en_vn[k]
    en_vn, over_limit = clamp_mapping(en_vn)
    if colliding or over_limit:
        print(f"[build_lexicon] bỏ {len(colliding)} key trùng cách gõ Telex của "
              f"âm tiết VN, {over_limit} entry vượt giới hạn độ dài "
              f"(còn {len(en_vn)})", file=sys.stderr)
    print(f"[build_lexicon] en_vn_mapping: giữ {carried_over} cặp có sẵn, "
          f"tổng {len(en_vn)}", file=sys.stderr)

    # Version PHẢI chỉ tăng: app so sánh `package.version > currentVersion` để
    # quyết định tải. Trước đây chỗ này ghi cứng 5, nên chạy script lên một file
    # đã ở version 10 sẽ hạ version → không client nào nhận cập nhật nữa.
    next_version = int(previous.get("version") or 0) + 1

    # Mang nguyên `_meta` cũ sang rồi mới sửa từng trường: `cleanup` là nhật ký
    # các đợt audit và `sources` là chuỗi attribution tích luỹ — dựng lại từ
    # đầu là xoá dấu vết của những script khác đã chạy trước.
    meta = dict(previous.get("_meta") or {})
    # SCHEMA của gói, không phải counter tải về (cái đó là `version` top level).
    # Trước đây build_underthesea_package.py tăng dần trường này mỗi lần merge,
    # nên nó trôi khỏi số schema thật.
    meta["version"] = SCHEMA_VERSION
    meta["generated_at"] = datetime.now(timezone.utc).isoformat()
    meta.setdefault("license_of_aggregate", "CC BY-SA 4.0 (data) + GPL-3.0 (code)")
    meta.setdefault("cleanup", [])

    # Attribution chỉ ghi cho nguồn THỰC SỰ dùng trong lần chạy này. Liệt kê cả
    # ba vô điều kiện là khai sai license khi chạy không có --kaikki.
    if vietnamese:
        add_source(meta, {
            "name": "common-vietnamese-syllables",
            "url": "https://github.com/vietnameselanguage/syllable",
            "license": "Open / public (per upstream project)",
            "used_for": "vietnamese[]",
        })
    if extracted:
        add_source(meta, {
            "name": "English Wiktionary via Wiktextract / Kaikki.org",
            "url": "https://kaikki.org/dictionary/rawdata.html",
            "license": "CC BY-SA 4.0",
            "used_for": "en_vn_mapping{}",
        })
    if english_top:
        add_source(meta, {
            "name": "wordfreq (Robyn Speer)",
            "url": "https://github.com/rspeer/wordfreq",
            "license": "MIT (data: CC BY-SA 4.0 for Wiktionary-derived portion)",
            "used_for": "english[] frequency selection",
        })

    package = {
        "_meta": meta,
        "version": next_version,
        "vietnamese": vietnamese,
        "english": english,
        "keep": keep,
        "en_vn_mapping": en_vn,
    }

    atomic_write_json(output_path, package)
    print(f"[build_lexicon] wrote {output_path} — "
          f"english={len(english)}, en_vn_mapping={len(en_vn)}, "
          f"version {previous.get('version')} → {next_version}",
          file=sys.stderr)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", type=Path, default=Path("lexicon-update.json"))
    p.add_argument("--top-english", type=int, default=10000,
                   help="How many wordfreq top English words to include in english[]")
    p.add_argument("--kaikki-download", action="store_true",
                   help="Download the full Kaikki dump (2.5GB) if not cached")
    p.add_argument("--kaikki", type=Path, default=None,
                   help="Path to a pre-downloaded Kaikki wiktextract JSONL[.gz]")
    p.add_argument("--max-kaikki-entries", type=int, default=None,
                   help="Limit the number of Kaikki entries processed (smoke runs)")
    args = p.parse_args(argv)

    build(
        output_path=args.out,
        top_english=args.top_english,
        kaikki_download=args.kaikki_download,
        kaikki_path=args.kaikki,
        max_kaikki_entries=args.max_kaikki_entries,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
