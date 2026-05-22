---
name: vkey-design
description: Use this skill to generate well-branded interfaces and assets for vkey, a personal Vietnamese input-method-editor (IME) for macOS — for production code or throwaway prototypes/mocks. Contains essential design guidelines, colors, type, fonts, custom icons, and UI kit components for prototyping macOS-native Vietnamese-typographic interfaces.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

Key things to know about this brand before you start:
- **macOS-native, dark-mode-first.** Brand-red `#E04434` replaces system blue. Warm paper neutrals (not cool grey).
- **Vietnamese diacritics are sacred.** Use Be Vietnam Pro for body, the bundled Noto Sans Display for marketing display, JetBrains Mono for keystrokes. Never use Carter One on Vietnamese text — it has no diacritic glyphs.
- **No emoji in chrome.** Replace with the bespoke SVG set in `assets/icons/`.
- **Glass is for overlays only** (HUDs, menu-bar dropdown). Settings window interiors are solid surfaces.
- **Voice is precise + slightly playful Vietnamese-first.** Sentence case, middot delimiters, technical examples in hints.

The 5 product surfaces this system covers: menu-bar app, Settings window (5 tabs), toggle HUD, prediction HUD, marketing site. Recreations of the first three live in `ui_kits/macos/`.
