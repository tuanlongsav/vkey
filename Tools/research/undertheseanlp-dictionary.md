# Research — undertheseanlp/dictionary integration (v1.6.1)

**Date**: 2026-05-19
**Source**: https://github.com/undertheseanlp/dictionary
**License**: GPL-3.0 (compatible với vkey GPL-3.0)
**Author**: Vũ Anh ([@undertheseanlp](https://github.com/undertheseanlp))

## Dataset structure

Repo cung cấp `dictionary/words.txt` định dạng JSON Lines:

```
{"text": "công ty", "source": ["hongocduc", "tudientv"]}
{"text": "a dua", "source": ["hongocduc", "tudientv", "wiktionary"]}
```

Tổng hợp từ 3 nguồn:

| Source | Entries |
|--------|---------|
| Hồ Ngọc Đức | 73,172 |
| tudientv | 36,533 |
| Wiktionary VN | 32,484 |
| **Merged total** | **79,226** |

## Phân bố entries

| Type | Count |
|------|-------|
| Single-token (no space) | 9,626 |
| Phrases 2-token (vd "công ty") | 52,778 |
| Phrases 3-token (vd "kính gửi anh") | 6,472 |
| Phrases 4+ token (vd "A Di Đà Phật") | 10,345 |
| Has dash (transliterations) | 1,907 |
| Pure ASCII (loanwords) | 3,605 |

## Filter cho v1.6.1

Engine vkey match per-syllable trong runtime (`LexiconManager.isVietnameseWord`)
→ chỉ ghép single-token vào dictionary mở rộng:

- Lowercase + NFC normalize
- Skip entries chứa whitespace (phrases — defer)
- Skip entries chứa digit hoặc dash
- Skip entries có ký tự non-alpha

**Sau filter**: 7,687 unique syllables (từ 9,626 single-token raw — filter loại transliteration + edge cases).

## Merge với lexicon hiện tại

Before (v1.6.0): 7,184 từ trong `lexicon-update.json` (build từ Wiktionary EN + wordfreq + hand-curated).

After (v1.6.1): **9,412 từ** (+2,228 mới).

Diff chủ yếu là syllables miền cụ thể (địa danh, tên thực vật/động vật, từ chuyên ngành) mà 7184 từ phổ biến không cover.

## Architecture

- Build script: [Tools/build_underthesea_package.py](../build_underthesea_package.py) — chạy local trên máy maintainer.
- Output: `vkey/lexicon-update.json` (commit vào repo).
- vkey app fetch qua GitHub Contents API: `https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json`
- `LexiconManager.checkAndPromptForDictionaryUpdate()` throttle 24h, auto-apply khi `package.version > currentVersion`.

## Open items (defer v1.7.0+)

- **Phrase corpus** (~70k phrases 2-4 token) — có thể dùng cho:
  - Mở rộng `EmbeddedBigrams.commonPairs` (prediction engine layer 3)
  - Suggest phrase macros (Issue 4 extension)
- **Quality audit** — review syllables hiếm / archaic (vd "a dốt", "a-dong") có thể không phù hợp cho gõ phổ thông.
- **Performance** — fetch + decode `lexicon-update.json` ~95KB → 9412 entries; cần đo cold-start latency.
- **A/B impact** — verify thêm 2,228 từ không gây false-positive trong `keepVietnamese` decision (vd "abc" giờ là VN word).

## Attribution requirement (per GPL-3.0)

- Credit Vũ Anh ([@undertheseanlp](https://github.com/undertheseanlp)) trong [LICENSE-DATA.md](../../LICENSE-DATA.md).
- Source list embed vào `_meta.sources` của `lexicon-update.json` (đã auto-add bởi build script).
- vkey app codebase đã GPL-3.0 → license aggregate compatible.
