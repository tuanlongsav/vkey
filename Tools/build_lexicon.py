#!/usr/bin/env python3
"""
Tools/build_lexicon.py — assemble lexicon/lexicon-update.json (schema v5).

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
        --out vkey/lexicon/lexicon-update.json \\
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
from datetime import datetime
from pathlib import Path
from typing import Iterable

KAIKKI_URL = "https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz"

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
    "work_v": ["làm việc"],
    "read": ["đọc"],
    "write": ["viết"],
    "listen": ["nghe"],
    "speak": ["nói"],
    "learn": ["học"],
    "teach": ["dạy"],
    "buy": ["mua"],
    "sell": ["bán"],
    "love_v": ["yêu"],

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
    """Stream-download the Kaikki dump if not already present."""
    if target.exists():
        return target
    print(f"[build_lexicon] downloading {KAIKKI_URL} → {target} (large file, ~2.5GB)…",
          file=sys.stderr)
    target.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(KAIKKI_URL) as r, open(target, "wb") as f:
        while True:
            chunk = r.read(1 << 20)  # 1 MiB
            if not chunk:
                break
            f.write(chunk)
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

    en_vn: dict[str, list[str]] = dict(SEED_EN_VN_MAPPING)

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

    package = {
        "_meta": {
            "version": 5,
            "generated_at": datetime.utcnow().strftime("%Y-%m-%d"),
            "sources": [
                {
                    "name": "common-vietnamese-syllables",
                    "url": "https://github.com/vietnameselanguage/syllable",
                    "license": "Open / public (per upstream project)",
                    "used_for": "vietnamese[]",
                },
                {
                    "name": "English Wiktionary via Wiktextract / Kaikki.org",
                    "url": "https://kaikki.org/dictionary/rawdata.html",
                    "license": "CC BY-SA 4.0",
                    "used_for": "en_vn_mapping{}",
                },
                {
                    "name": "wordfreq (Robyn Speer)",
                    "url": "https://github.com/rspeer/wordfreq",
                    "license": "MIT (data: CC BY-SA 4.0 for Wiktionary-derived portion)",
                    "used_for": "english[] frequency selection",
                },
            ],
            "license_of_aggregate": "CC BY-SA 4.0 (data) + GPL-3.0 (code)",
        },
        "version": 5,
        "vietnamese": vietnamese,
        "english": english,
        "keep": keep,
        "en_vn_mapping": en_vn,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(package, f, ensure_ascii=False, indent=2, sort_keys=False)
    print(f"[build_lexicon] wrote {output_path} — "
          f"english={len(english)}, en_vn_mapping={len(en_vn)}",
          file=sys.stderr)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", type=Path, default=Path("vkey/lexicon/lexicon-update.json"))
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
