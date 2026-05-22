# macOS App UI Kit

Pixel-fidelity recreations of vkey's macOS app surfaces using the "Tonal" design system. Built as plain HTML + CSS (no React) so any element can be direct-edited.

## Files

| File | What it is |
|---|---|
| `index.html` | **Main Settings window** — 5 tabs (Chung, Smart Switch, Macro, Chính tả, Thống kê), interactive |
| `MenuBar.html` | macOS status-bar dropdown menu, with HUD toast + prediction overlay on desktop |
| `Onboarding.html` | First-run setup window (4 steps, progress pips) |
| `macos.css` | window chrome, titlebar, tabbar, statusbar, menu, HUD styles |

## Design notes

- **Dark mode only**. The native app is most often used over a dark macOS desktop; the system can extend to light mode by adding `data-theme="light"` to `<html>`.
- **Native chrome**: traffic lights, 38px titlebar with centred title; matches macOS Sequoia.
- **No emoji icons** — every emoji in the current app (🚀, ✨, 🇻🇳, 🤖, 🔒…) has been replaced with the custom SVG set in `assets/icons/`.
- **Brand red toggles** replace the system blue. Spring-eased thumb (1.56 overshoot) for a tactile feel.
- **Tabs** are pill tabs with subtle elevation, much lighter than the heavy textured tabs of the current app.

## Components used
Setting row (`.row` / `.row-group`), tab (`.tab` / `.tabs`), segmented control (`.segmented`), toggle (`.toggle`), button (`.btn` variants), keycap (`.keycap`), badge (`.badge--*`), input (`.input`), surface (`.surface-dark`).

## Cross-references
- Tokens: `../../colors_and_type.css`
- Generic component CSS: `../../components.css`
- All icon sources: `../../assets/icons/*.svg`
- All logo sources: `../../assets/logo/*.svg`
