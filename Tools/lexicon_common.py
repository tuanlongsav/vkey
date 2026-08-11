#!/usr/bin/env python3
"""
Tools/lexicon_common.py — thứ mà MỌI script chạm vào `lexicon-update.json`
phải dùng chung.

Trước file này, bốn script (`build_lexicon`, `merge_en_vn_mapping`,
`merge_underthesea_deep`, `audit_lexicon`) mỗi cái tự mang một bản sao của
`VN_DIACRITIC_CHARS`, whitelist Tier C, và cách ghi file riêng. Chúng lệch nhau
theo thời gian, và cái lệch nguy hiểm nhất là bộ lọc va chạm Telex: chỉ
`merge_en_vn_mapping.py` có, nên `build_lexicon.py` dựng lại gói là mất sạch.

Ba thứ ở đây, theo thứ tự quan trọng:

  1. `collides_with_vietnamese` — chặn key tiếng Anh trùng cách gõ Telex của
     một âm tiết tiếng Việt. Đây KHÔNG phải chuyện gọn gàng dữ liệu: mọi key
     trong `en_vn_mapping` được `SpellDecisionEngine` coi là "từ tiếng Anh"
     (vkey/Input/SpellDecisionEngine.swift:159), nên một key trùng khiến Space
     Restore khôi phục về phím thô ĐÚNG LÚC người dùng vừa gõ xong một từ
     tiếng Việt.
  2. `atomic_write_json` — mọi script đều ghi đè chính file đầu vào
     (`--in` và `--out` mặc định trùng nhau). `write_text` cắt file trước khi
     ghi, nên Ctrl-C giữa chừng để lại JSON hỏng.
  3. Hằng số dùng chung + giới hạn của `LexiconUpdatePackage.validated()`
     phía Swift, để script không sinh ra gói mà client sẽ từ chối.

License: GPL-3.0 (như phần còn lại của dự án).
"""

from __future__ import annotations

import json
import os
import unicodedata
from pathlib import Path

# --- Giới hạn phản chiếu vkey/Lexicon/LexiconUpdatePackage.swift ---
# Vượt bất kỳ giới hạn nào ⇒ `validated()` ném lỗi ⇒ client bỏ nguyên gói,
# im lặng. Script phải tự chặn trước khi ghi.
MAX_ENTRIES = 200_000
MAX_STRING_LENGTH = 256

# Schema của gói, KHÔNG phải `version` ở top level (cái đó là counter để client
# quyết định tải). Ghi cố định; đừng tăng khi chỉ merge thêm dữ liệu.
SCHEMA_VERSION = 5

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

# Cluster phụ âm đầu rõ rệt VN (không có trong English) — dấu hiệu phụ trợ khi
# entry không có diacritic nhưng vẫn là VN syllable.
VN_INITIAL_CLUSTERS = {"ng", "ngh", "nh", "kh", "ph", "th", "tr", "ch", "gh", "gi", "qu"}

# Loanword phổ biến trong tiếng Việt, ASCII và không có marker nào — không suy
# ra được bằng luật, phải curate. Dùng chung giữa merge_underthesea_deep.py
# (cổng nhận Tier C) và audit_lexicon.py (miễn trừ khỏi luật drop).
TIER_C_ASCII_LOANWORDS: set[str] = {
    # Chemistry / units
    "acid", "axit", "kali", "oxy", "ion", "clo", "nitrat", "kalium",
    "celsius", "fahrenheit",
    # Science / tech
    "alpha", "beta", "logic", "euclid", "radio", "video", "internet",
    "diesel", "cassette", "apacthai",
}


# --- Telex ---

TELEX_TONE_KEYS = "sfrxj"

# Dấu thanh tổ hợp → phím Telex.
_TONE_TO_KEY = {
    "́": "s",  # sắc
    "̀": "f",  # huyền
    "̉": "r",  # hỏi
    "̃": "x",  # ngã
    "̣": "j",  # nặng
}

# Nguyên âm biến đổi → cách gõ Telex. Đây là lớp mà bộ lọc cũ bỏ sót: nó chỉ
# xét phím dấu cuối (sfrxj), nên "mow" (= "mơ"), "sow" (= "sơ"), "coo" (= "cô")
# lọt qua và trở thành key tiếng Anh.
_BASE_TO_TELEX = {
    "â": "aa", "ê": "ee", "ô": "oo",
    "ă": "aw", "ơ": "ow", "ư": "uw",
    "đ": "dd",
}


def bare(word: str) -> str:
    """Dạng không dấu của một âm tiết tiếng Việt ('cấm' → 'cam')."""
    word = word.replace("đ", "d").replace("Đ", "d")
    return "".join(
        c for c in unicodedata.normalize("NFD", word)
        if unicodedata.category(c) != "Mn"
    ).lower()


def telex_spellings(word: str) -> set[str]:
    """
    Mọi cách gõ Telex hợp lý của một âm tiết tiếng Việt.

    'mơ' → {'mow'}, 'cá' → {'cas'}, 'cư' → {'cuw', 'cw'}.

    Trả về một tập vì `ư` có hai cách gõ phổ biến (`uw` và `w` trơn) và cả hai
    đều phải bị chặn. Các biến thể khác (gõ dấu giữa từ chứ không ở cuối) tạo ra
    cùng chuỗi ký tự nên không cần liệt kê riêng.
    """
    decomposed = unicodedata.normalize("NFD", word.lower())
    tone = ""
    out: list[str] = []
    for ch in decomposed:
        if ch in _TONE_TO_KEY:
            tone = _TONE_TO_KEY[ch]
            continue
        if unicodedata.category(ch) == "Mn":
            # Dấu mũ / móc / trăng — gắn ngược vào chữ cái vừa đọc.
            prev = out.pop() if out else ""
            combined = unicodedata.normalize("NFC", prev + ch)
            out.append(_BASE_TO_TELEX.get(combined, prev))
            continue
        out.append(_BASE_TO_TELEX.get(ch, ch))
    canonical = "".join(out) + tone
    spellings = {canonical}
    if "uw" in canonical:
        spellings.add(canonical.replace("uw", "w"))
    return spellings


def build_blocklist(vietnamese: list[str] | set[str]) -> tuple[set[str], set[str]]:
    """
    Dựng hai tập tra cứu cho `collides_with_vietnamese`, một lần cho cả lượt chạy.

    Trả về `(bare_forms, telex_forms)`. Tách riêng vì hai lớp chặn khác nhau về
    bản chất: `bare_forms` bắt trùng dạng không dấu, `telex_forms` bắt trùng
    chuỗi phím thật sự gõ ra.
    """
    bare_forms: set[str] = set()
    telex_forms: set[str] = set()
    for w in vietnamese:
        if " " in w:
            continue
        bare_forms.add(bare(w))
        telex_forms |= telex_spellings(w)
    return bare_forms, telex_forms


def collides_with_vietnamese(word: str, blocked: set[str],
                             telex_forms: set[str] | None = None) -> bool:
    """
    True nếu `word` là cách gõ Telex của một âm tiết tiếng Việt.

    Ba lớp:
      1. Trùng thẳng dạng không dấu — "ban", "cam", "tao".
      2. Trùng sau khi bỏ phím dấu cuối — "cas" = "cá", "banj" = "bạn".
      3. Trùng chính xác một chuỗi phím Telex — "mow" = "mơ", "coo" = "cô",
         "hoof" = "hồ". Lớp này bắt các phím biến nguyên âm (w, aa, ee, oo, dd)
         mà lớp 2 bỏ sót vì chúng không nằm ở cuối và không phải phím dấu.

    `telex_forms` để None thì bỏ lớp 3 (giữ tương thích với chỗ gọi cũ), nhưng
    mọi chỗ gọi mới đều nên truyền vào — đó là lớp chặt nhất.
    """
    b = bare(word)
    if b in blocked:
        return True
    if len(b) > 1 and b[-1] in TELEX_TONE_KEYS and b[:-1] in blocked:
        return True
    if telex_forms is not None and word.lower() in telex_forms:
        return True
    return False


# --- I/O ---

def atomic_write_json(path: Path, payload: dict) -> None:
    """
    Ghi `payload` ra `path` theo kiểu tất-cả-hoặc-không-gì.

    Mọi script trong Tools/ đều ghi đè chính file đầu vào, nên một lần ghi hỏng
    giữa chừng là mất `lexicon-update.json`. Ghi ra file tạm CÙNG thư mục (để
    `os.replace` là thao tác nguyên tử trong cùng filesystem), fsync, rồi mới
    đổi tên đè lên.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    text = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def add_source(meta: dict, entry: dict) -> None:
    """
    Thêm một mục attribution vào `_meta.sources`, bỏ qua nếu đã có cùng `name`.

    Không có bước dedup này thì mỗi lần chạy lại script là một bản sao nữa của
    cùng một nguồn — `_meta.sources` phình ra và không còn đọc được như một
    danh sách provenance.
    """
    sources = list(meta.get("sources") or [])
    if not any(s.get("name") == entry.get("name") for s in sources):
        sources.append(entry)
    meta["sources"] = sources


def clamp_mapping(mapping: dict[str, list[str]],
                  max_candidates: int = 3) -> tuple[dict[str, list[str]], int]:
    """
    Ép một mapping về đúng giới hạn `LexiconUpdatePackage.validated()`.

    Trả về `(mapping đã cắt, số entry bị bỏ)`. Bỏ hẳn entry có key quá dài hoặc
    không còn candidate nào hợp lệ — gửi đi thì client từ chối NGUYÊN GÓI, nên
    mất một entry vẫn hơn mất cả bản cập nhật.
    """
    out: dict[str, list[str]] = {}
    dropped = 0
    for key, candidates in mapping.items():
        if len(key) > MAX_STRING_LENGTH:
            dropped += 1
            continue
        kept = [c for c in candidates if c and len(c) <= MAX_STRING_LENGTH]
        if not kept:
            dropped += 1
            continue
        out[key] = kept[:max_candidates]
    return out, dropped
