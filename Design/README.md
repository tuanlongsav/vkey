# vkey Design System — "Tonal" + "Liquid Glass"

A complete design system for **vkey**, a personal Vietnamese input-method-editor (IME) for macOS 14+ (Sonoma). vkey lives as a small menu-bar app and HUD overlay; this system covers tokens, type, icons, and recreations of every screen the user actually sees.

> Use it to mock new screens, generate marketing assets, prototype new HUDs, or write production SwiftUI/HTML that stays on-brand.

## Source material

This system is distilled from the upstream codebase. If you have access, dig deeper there:

- **GitHub:** https://github.com/tuanlongsav/vkey (Swift / AppKit / SwiftUI · GPL-3.0)
  - Codebase: `/vkey/View/*.swift` for the live Settings UI, `/vkey/Assets.xcassets/` for icons, `VKeyDesign.swift` for design tokens centralised in Swift.
  - Existing design folders explored: `Design/` ("Tonal" — current baseline), `Design2/` (Liquid Glass variants), `Design4/` (compositional canvas).
  - `images/` — real product screenshots (menu-bar dropdown, all 5 settings tabs).
  - `web/index.html` + `web/app-screenshot.png` — marketing site copy and tone.

The brand itself is upstream from **Caffee** (Khanh Nguyen, GPL-3.0) — the Vietnamese typing engine — and learns from **XKey** and **GoNhanh.org**. vkey is non-commercial; the name is not affiliated with any registered "VKey" trademark.

---

## What vkey is

A small, opinionated macOS Vietnamese IME with one job: type Vietnamese accurately in **Telex** or **VNI**, then get out of the way.

The product has three product surfaces:

1. **Menu-bar app** — flag icon (🇻🇳 / 🇺🇸 / 🔒 / ⚙️) + a translucent dropdown menu with quick toggles.
2. **Settings window** — five tabs: *Chung · Smart Switch · Macro · Chính tả · Thống kê & Sao lưu*. The bulk of vkey's UI surface.
3. **HUDs** — full-screen glassmorphic toggle HUD ("Tiếng Việt" / "English") and a small inline prediction HUD next to the caret.

A **marketing site** (`web/index.html`) and a small **onboarding sheet** round it out.

---

## Index — files in this system

| Path | What |
|---|---|
| `colors_and_type.css` | All design tokens — colors, type scale, radii, spacing, shadows, motion. Light + dark via `[data-theme="dark"]`. |
| `components.css` | Generic component CSS — buttons, toggles, segmented, tabs, rows, keycaps, badges, inputs, HUD. |
| `fonts/` | Be Vietnam Pro & JetBrains Mono load from Google Fonts; Noto Sans Display + Carter One are bundled locally for full Vietnamese diacritic coverage. |
| `assets/icons/` | 43 custom SVG icons — 24px box, 1.5px stroke, `currentColor`. Use these instead of emoji. |
| `assets/logo/` | App icon, wordmark, lockup, tone-mark glyph. |
| `assets/vkey-app-icon-*.png` | Pre-rendered macOS app icon at 128 / 256 / 1024. |
| `assets/screenshots/` | Real product screenshots captured from the running app. |
| `preview/*.html` | One-glance cards (≈700×170 each) for the Design System tab. |
| `ui_kits/macos/` | High-fidelity recreations of the real Settings window, menu-bar dropdown, and onboarding sheet. |
| `_research/` | Raw screenshots & overview imagery used during exploration; safe to ignore. |
| `SKILL.md` | Cross-compatible Agent Skill front-matter — drop this folder into a Claude Code skill and it works. |

---

## Content fundamentals

vkey speaks **Vietnamese first**, with English as a thin technical fallback. The voice is the voice of an indie developer talking to other Vietnamese power-users: precise, terse, slightly playful about diacritics, never marketing-corporate.

### Tone
- **First person plural is rare.** The app addresses the user as *bạn* implicitly; commands are infinitival ("Bật / Tắt gõ TV", "Thêm macro"). No "we", no "your data is safe with us" — it just says "không gửi đi đâu, không telemetry".
- **Technical precision wins over softness.** Settings hints quote real keystrokes: `thfi → thì`, `dinhjd → định`, `phuowgn → phương`. Version notes name internal mechanisms (Vowel Inclusion Pairs, AX Probing, Levenshtein > max(2, len/4)).
- **Self-aware and slightly playful.** Themes are named *Tonal*, *Mực* (ink), *Sơn Mài* (Vietnamese lacquerware), *Liquid Glass*. Macros default to `vn → Việt Nam`, `kga → Kính gửi anh`.
- **Bilingual code-switching is fine.** "Smart Switch v2.0+" lives next to "Bộ gõ tiếng Việt cá nhân". English is reserved for nouns of art (IME, FFI, EdDSA, AX Probing, Sparkle).

### Casing & punctuation
- **Sentence case** for labels and headings. Never title case. Never ALL CAPS except for tiny eyebrows (`.eyebrow` — uppercase + 0.14em tracking).
- Diacritics are sacred. Always NFC. Vietnamese always uses **kiểu mới** in chrome (`thuỷ`, `khoẻ`, `hoà`, `uý`) — kiểu cũ is a user setting, not the default voice.
- Section titles tend to be short noun phrases: *Nhập liệu*, *Phím tắt*, *Hệ thống*.

### Emoji
- **No emoji in the chrome.** The codebase explicitly replaced every emoji (🚀, ✨, 🇻🇳, 🤖, 🔒) with custom SVGs in `assets/icons/`. The only "emoji" survivors are the four flag/lock state glyphs the menu-bar icon mimics — and even those are drawn as SVGs (`flag-vn.svg`, `flag-us.svg`, `lock.svg`, `gear.svg`).
- **Markdown READMEs may use ✅** for feature checklists (this is a GitHub-only affordance, not in-app).

### Specific copy examples
- Pithy hint under a toggle: `thfi → thì · veeitj → việt · phuowgn → phương`
- Brand description: *"Bộ gõ tiếng Việt cho macOS · Telex & VNI"* (note the middot delimiter — used throughout)
- Version badges read **v2.2.2** in a soft red `badge--brand` pill, never "Version 2.2.2".
- Empty/error states are deadpan factual: *"34 macros"*, *"+18% so tuần trước"*, *"tracked locally, nothing sent"*.
- The CTA verb of choice is **"Cập nhật ngay"** ("update now"), not "Update available!". Imperative + tense compression.

---

## Visual foundations

### Personality
**macOS-native, dark-mode-first, Vietnamese-typographic.** Imagine the System Settings window if a Vietnamese type-nerd redesigned it: same chrome (traffic lights, 38px titlebar, pill tabs), but with brand-red accents replacing system blue, and warmer paper-tone neutrals instead of pure-cool greys. Glassmorphic backdrop-blur HUDs sit over a dark desktop with a faint red+gold radial wash.

### Colors
- **Anchor:** `--vkey-red-500: #E04434` — slightly deeper than the icon red of v1.x, applied to toggles, badges, primary buttons, focus rings, prediction highlights.
- **Saigon gold** (`--gold-400: #F5C645`) — used **very sparingly**: VN-flag star, "new" badges, prediction-HUD accent, the linear gradient inside stat bars (`vkey-red-500 → gold-400`).
- **Warm paper neutrals** (`--paper-*`, `#FAF8F4` canvas) for light mode — never cool grey. Light mode exists but the app overwhelmingly runs dark.
- **Deep ink neutrals** (`--ink-500: #131519` dark bg, `--ink-400: #1A1C22` elevated, `--ink-600: #0E0F12` sunken). Dark elevation goes *darker* for sunken, not lighter — opposite of typical Material.
- **Semantic colors stay soft.** Success/warning/danger have a `*-soft` companion (`--success-soft: #DCF3E7`) used for badge backgrounds; the saturated tone is reserved for icons and text.

### Type
- **Display & UI body:** `Be Vietnam Pro` (300-800). Full diacritic coverage; the workhorse.
- **Display-only Latin moments:** `Carter One` (loaded as `--font-brand`) — only ever paired with Latin characters because it has *no* Vietnamese glyphs. There's a deliberate `--t-display-vi` token (Be Vietnam Pro 800) for Vietnamese display.
- **Mono:** `JetBrains Mono` — keystroke examples, bundle IDs, version strings, raw lexicon tokens.
- **Bonus:** `Noto Sans Display` (variable width + weight) is bundled as a brand display face for marketing.
- The scale runs `--t-brand 64px → t-display-vi 60px → t-h1 36 → t-h2 26 → t-h3 19 → t-h4 15 → body 14 → small 12.5 → micro 11`. Letter-spacing tightens as size grows (`-0.02em` for h1, neutral for body).

### Spacing & radii
- **4px base spacing scale**: `--s-1: 4 → --s-10: 72`. Most paddings are 12–16px; row gaps cluster around 8–14px.
- **Radii grow with surface size**: 4 → 6 → 10 → 14 → 20 → 28 → 999 (pill). Settings rows use `--r-md (10)`, the surrounding `row-group` uses `--r-lg (14)`, HUDs use `--r-xl (20)`.

### Surfaces, cards, borders
- Cards (`.surface`, `.row-group`) = `bg-elevated` + `1px solid var(--border-1)` + `--r-lg`. **No glow, no thick borders, no left-accent-bar tropes.**
- Borders are deliberately thin. In dark mode they're translucent white (`rgba(255,255,255,0.08)` for `--border-1`, `0.14` for `--border-2`).
- `.row-group` collapses adjacent radii — first/last rows round, middle rows are flat with hairline dividers.

### Shadows
- **Layered light-mode shadows** mix a long soft drop with a short ambient: `--shadow-md` is `0 8px 24px -8px rgba(20,18,14,0.16), 0 2px 4px rgba(20,18,14,0.06)`.
- **`--shadow-window`** is the heavy macOS window drop: `0 30px 80px -20px rgba(0,0,0,0.45), 0 8px 24px rgba(0,0,0,0.18)`.
- **`--shadow-key`** for keycaps simulates a bottom rim + tiny drop — gives the small `.kbd` chips real tactility.
- Dark mode shadows are *more saturated, not less* — opacity climbs because the surface is darker.

### Glass & transparency
- HUDs use `backdrop-filter: blur(40px) saturate(180%)` with a `rgba(28,30,36,0.55)` fill — Apple's macOS Sequoia "Liquid Glass" recipe. Triple-layer: dark glass + edge highlights `inset 0 0 0 1px rgba(255,255,255,0.08)` + refractive corner tints on the Liquid-Glass theme variant.
- Menu-bar dropdown uses `rgba(38,38,42,0.92)` + `blur(50px) saturate(180%)` + a tiny arrow tab pointing at the menu-bar icon.
- Status bar is `rgba(20,20,22,0.6)` + `blur(20px)`. Transparency is *reserved for floating chrome that overlays the desktop* — never used inside the Settings window.

### Motion
- `--ease-out: cubic-bezier(0.22, 1, 0.36, 1)` for hover/press feedback (snappy decel).
- `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)` for the toggle thumb — 1.56 overshoot is intentional, gives a tactile "click".
- Durations: `--dur-fast 120ms` (hover), `--dur-base 180ms` (toggles, panels), `--dur-slow 280ms` (modal/window).
- No bouncy fade-and-scale entries. No parallax. No carousel animations.

### Hover / press / focus
- **Hover** is a small lift in surface tone: `--bg-elevated → --bg-hover` (= `--paper-100` light / `--ink-400` dark). Borders strengthen `--border-2 → --border-strong`.
- **Press** scales down: `transform: translateY(0.5px) scale(0.985)` on `.btn:active`. Buttons also darken (primary: red-500 → red-600 → red-700 between rest/hover/active).
- **Focus** is a 2px brand-red outline at 2px offset (`outline: 2px solid var(--vkey-red-400); outline-offset: 2px`). Inputs additionally get a soft 3px `color-mix` halo.
- No opacity-based hover. No underline-on-hover for in-app text (links are not a primary affordance — this is an app, not a website).

### Imagery
- The product is functional; imagery is minimal. The two real images are: (1) the app icon (a stylised "v" tone-mark glyph in brand red on warm cream) and (2) screenshots of itself. No stock photography, no illustration, no character mascot. If imagery is added, it should feel like macOS marketing — warm desaturated gradients, no grain, no high-contrast B&W.

### Layout rules
- Settings window is **fixed 900px wide**. Tabs are pill tabs in a 10px-padded `.tabbar`. The body inside sits in a 18/22/24 padding box.
- Setting rows are always `row__icon (32px tile) + body + control`, gap 12px, padding 12/16. The icon tile uses `bg-sunken` + `fg-accent` color for default state; the brand-tile variant uses a soft red tint.
- Keycaps in the body text are inline `.keycap` spans — small enough to flow inside a sentence.

### What to avoid
- Bluish-purple gradients.
- Card-with-rounded-corners-and-coloured-left-border patterns.
- Emoji icons.
- Centred hero text with a giant CTA. The system doesn't do landing-page tropes.
- "Frosted-glass over a Bezier-curve background" — glass only appears over the actual desktop.

---

## Iconography

vkey ships a **bespoke 24px / 1.5px-stroke SVG set** in `assets/icons/`. Every icon uses `stroke="currentColor"` so it inherits the parent's color and supports light/dark mode out of the box.

### Inventory (43 icons)
`abc · alert-triangle · arrow-right · backspace-key · chart-bar · check-circle · chevron-down · chevron-right · command · dictionary · download · edit · ellipsis · escape-key · flag-us · flag-vn · gear · globe · info-circle · keycap · layers · lightbulb · lock · lock-open · magic-wand · menubar-flag · minus · plus · refresh · return-key · robot · search · shift-key · shuffle · sliders · sparkles · tab-key · tone-mark · trash · upload · user · x-circle`

### Usage rules
- Default usage is `<img src="…/icon.svg" width="16" height="16">` inside an inline-flex element. For dark backgrounds, invert via `filter: invert(1)` or `filter: brightness(0) invert(1)`.
- The brand-flagged icon tile (`.icon-tile--brand`) uses a soft red bg + `--vkey-red-300` text in dark mode.
- **Flags** (`flag-vn.svg`, `flag-us.svg`) are full-color SVGs — *don't* invert these.
- Keyboard-key glyphs (`return-key`, `shift-key`, `tab-key`, `escape-key`, `backspace-key`, `command`) are meant to sit *inside* a `.keycap` chip, sized 13–14px.
- **No emoji.** Anywhere there's an emoji in OS chrome (status text, menu items, error toasts) the answer is the SVG set.
- **No icon font.** Don't add Feather/Lucide/Heroicons — the bespoke set is intentionally narrow.
- **No raster icons** at app-icon sizes — `assets/vkey-app-icon-*.png` are the macOS-icon renders; everywhere else uses SVG.
- Unicode characters are used sparingly: bullets (`·`), em-dash (`—`), arrows (`→` in keystroke hints, `↔` in mode-switch labels). Never used as *icons*, always as punctuation inside a string.

---

## Variations & themes

The shipping app has **4 themes** in the menu-bar picker (v2.2.2). This system models the canonical **Tonal** look; the other three are skin variants on the same tokens:

1. **Mặc định / Tonal** *(this system's baseline)* — flat SF-Symbol-style icons, warm paper neutrals, brand-red accents.
2. **Emoji vui tươi** — Unicode emoji replace the SVG set in menu-bar/HUD only. Not recommended for new screens.
3. **Tonal (dark)** — Tonal tokens with `[data-theme="dark"]` flipped. The dominant in-the-wild experience.
4. **Liquid Glass** *(v2.2.2)* — adds multi-layer refractive glass: brand red `#E04434` + `rgba(28,30,38,0.55)` glass + edge highlights + corner tints + `blur(40-60px) saturate(200%)`. Only applied to overlays (HUDs, menu bar), never to the Settings window interior.

`Design2/themes/` in the upstream repo carries token overrides for Mực, Sơn Mài, and Liquid Glass if you need to extend.

---

## Caveats & substitutions

- **Carter One** is loaded from Google Fonts (CDN) — no local TTF bundled in the original repo. If you need offline, download from https://fonts.google.com/specimen/Carter+One and drop into `fonts/`.
- **Be Vietnam Pro** and **JetBrains Mono** are also Google Fonts CDN. **Noto Sans Display** is bundled locally as it's the brand display face.
- Variable-font copies in `fonts/` are deduped to the canonical filenames; remove `.ttf` duplicates if you re-import upstream.
- The app icon PNG at 1024px is the source of truth; everything else is downsampled or SVG.
