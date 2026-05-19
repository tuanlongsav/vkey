# Data License (vkey lexicon files)

> **TL;DR**: vkey's *source code* is **GPL-3.0**; the *dictionary data* in
> [`lexicon/`](lexicon/) is **CC BY-SA 4.0**. They're licensed separately
> because the data is partly derived from Wiktionary (CC BY-SA 4.0), which
> isn't redistributable under GPL alone. Both licences are share-alike —
> downstream forks must keep the same terms and credit the upstream sources.

---

## Why dual licensing?

Starting in **v1.5.0** vkey ships a bilingual reference dictionary
(`lexicon/lexicon-update.json`, schema v5) that includes:

- **Vietnamese syllable list (~9412 entries, v1.6.1+)** — hợp nhất từ hai nguồn:
  - [@hieuthi / common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable) (~7184 syllables phổ biến)
  - [@undertheseanlp / dictionary](https://github.com/undertheseanlp/dictionary) (~2228 syllables bổ sung, tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN), tác giả Vũ Anh, license **GPL-3.0** — tương thích share-alike với CC BY-SA 4.0 aggregate của vkey lexicon.
- **English word list (~2000 entries)** — selected by frequency using
  [wordfreq](https://github.com/rspeer/wordfreq) (MIT for the code, CC BY-SA
  4.0 for the Wiktionary-derived portion of its data).
- **English → Vietnamese mapping (1000+ entries)** — extracted from English
  Wiktionary via [Wiktextract](https://github.com/tatuylonen/wiktextract) +
  [Kaikki.org](https://kaikki.org/dictionary/rawdata.html), distributed
  under **CC BY-SA 4.0** by the Wikimedia community.

GPL-3.0 cannot relicense CC BY-SA 4.0 data — the two licences are
incompatible for joint redistribution **as a single artifact**. The
accepted practice for open-source projects in this situation is to license
each kind of artifact separately. That's what we do here.

---

## License terms

| Path | License |
|---|---|
| All Swift / Objective-C / Python source code (`vkey/`, `Tools/`, `vkeyTests/`, `vkeyUITests/`) | **GNU General Public License v3.0** ([LICENSE](LICENSE)) |
| Dictionary data (`lexicon/lexicon-update.json`, plus any future `lexicon/*.json` files) | **Creative Commons Attribution-ShareAlike 4.0 International** (CC BY-SA 4.0) — <https://creativecommons.org/licenses/by-sa/4.0/> |
| App assets / icons / screenshots in `images/` | Same as source (GPL-3.0) unless noted otherwise inside the file |

The build script that assembles the dictionary
([`Tools/build_lexicon.py`](Tools/build_lexicon.py)) is GPL-3.0; the **output
JSON file** it produces is CC BY-SA 4.0.

---

## What you must do when you fork or redistribute

If you fork vkey and want to ship the lexicon:

1. Keep `LICENSE-DATA.md` (this file) in the repo.
2. Keep the `_meta.sources` block at the top of `lexicon-update.json` intact
   — it carries upstream attribution and license info.
3. Provide attribution in your README pointing back to:
   - vkey ([@tuanlongsav](https://github.com/tuanlongsav/vkey))
   - English Wiktionary via Wiktextract / Kaikki.org
   - common-vietnamese-syllables by [@hieuthi](https://github.com/vietnameselanguage/syllable)
   - dictionary by [@undertheseanlp](https://github.com/undertheseanlp/dictionary) — Vũ Anh (GPL-3.0)
4. Any changes you make to the dictionary data must also be distributed
   under CC BY-SA 4.0 (share-alike clause).
5. Your source code changes must still be GPL-3.0 (copyleft clause).

---

## What's *not* in our dictionary

vkey deliberately does **not** include data scraped from:

- Cambridge / Oxford / Merriam-Webster
- Lạc Việt / vdict.com / Soha
- glosbe.com or bab.la
- Anki shared decks of uncertain provenance
- The 109k-word `English-Vietnamese-Dictionary` GitHub repos that lack a
  clear LICENSE file (their data is widely believed to be scraped from
  commercial dictionaries)

If you're contributing to the lexicon, please only submit data you can
attribute to a source we can legally redistribute under CC BY-SA 4.0 or a
license compatible with it.

---

## Questions

If you think we've made a mistake about attribution or licensing — please
open an issue at <https://github.com/tuanlongsav/vkey/issues>. We take
licensing seriously and will respond.
