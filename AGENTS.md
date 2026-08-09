# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project Overview

vkey is a macOS Vietnamese Input Method Editor (IME) - a native keyboard input system for typing Vietnamese with diacritical marks. It supports Telex and VNI input methods with app-specific input mode memory.

**Current release**: read it, don't trust a number written here — `grep MARKETING_VERSION vkey.xcodeproj/project.pbxproj`, or the top entry of [CHANGELOG.md](CHANGELOG.md). Release process: [RELEASE.md](RELEASE.md).

**Target**: macOS 14+ Sonoma
**Language**: Swift
**Frameworks**: AppKit, SwiftUI

## Build Commands

```bash
# Build (ad-hoc signed, into a scratch derived-data dir)
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Debug \
  -derivedDataPath /tmp/vkey-dd build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Run tests (uses vkey.xctestplan; vkeyUITests is disabled in that plan)
xcodebuild -project vkey.xcodeproj -scheme vkey \
  -destination 'platform=macOS' test
```

Formatting is manual; there is no formatting build phase in this personal fork.

Releasing is scripted end-to-end — do NOT hand-run the archive/notarize steps:
`Tools/release_build.sh X.Y` (see [RELEASE.md](RELEASE.md)).

## Architecture

### Data Flow
```
Keyboard Event → EventHook (CGEvent tap) → InputProcessor
    → Engine (Telex/VNI) → TiengVietTransformer.transform() → EventSimulator
```

### Key Components

**App/** - Application lifecycle and state
- `AppState.swift` - Observable state container with Combine publishers for enabled state, typing method, and per-app input mode memory
- `InputProcessor.swift` - Main keyboard event handler that maintains word state and delegates to the typing engine. Also owns the NFC/NFD decision per focused field and `canonicalAppBundle` (an app's own helper process is not an app switch)
- `Setting.swift` - Persistent settings using Defaults framework
- `Updater.swift` - Sparkle wrapper · `UserDataMigration.swift` - backup/restore of personal data

**Engine/** - Vietnamese typing logic
- `TiengViet.swift` - Vietnamese syllable model: tone marks (DauThanh), diacritics (DauMu), consonant clusters, vowels
- `TiengVietParser/Transformer/Validator.swift` - parse a syllable, place marks, reject impossible ones (phonotactics)
- `Telex.swift` / `VNI.swift` - Input method implementations following TypingMethod protocol

**Platform/** - macOS system interaction
- `EventHook.swift` - Global CGEvent tap for keyboard interception (requires Accessibility permission). `setEnabled` only resets the word buffer on a real state change
- `EventSimulator.swift` - Simulates backspace and text input to replace typed text; per-app sending strategy incl. `axDirect` for Chromium omnibox
- `Focused.swift` - Accessibility API: focused element, `FieldKind` (webContent / nativePanel / windowField)
- Also: HUD windows (Toggle/Prediction/Notice), clipboard history, window-title rules, input-source monitor

**KeyLayout/** - Keyboard mapping
- `KeyboardUS.swift` - US keyboard layout key code to character mapping
- `Keys.swift` - TaskKey enum for special keys (Enter, Tab, Space, arrows)

**Input/** - `PredictionEngine.swift` (next-word prediction), `SpellDecisionEngine.swift` (keep Vietnamese vs restore English)
**Lexicon/** - embedded word lists + the GitHub `lexicon-update.json` fetch path
**Stats/** - usage statistics and n-gram store (local only, no telemetry)
**View/** - SwiftUI. `View/Redesign/VK*` is the live design system; older top-level views are legacy
**Marketing/** - `--export-marketing` screenshot exporter (dev tool, ships in the binary)

### Dependencies (Swift Packages)
- **Defaults** - UserDefaults wrapper
- **KeyboardShortcuts** - Shortcut recording/binding
- **LaunchAtLogin** - Auto-start functionality
- **Sparkle** - Silent auto-update; drives `appcast.xml` and the whole release flow

The Settings window is hand-built SwiftUI (`View/Redesign/VKSettingsView.swift`),
not the `Settings` package.

## Working copy inside iCloud Drive

The maintainer's checkout lives under `~/Desktop`, which iCloud Drive syncs.
This is not a hypothetical hazard — it has already produced conflicted copies
of **`.git/index` itself** (five of them, `index 2` … `index 6`, accumulated
May–June 2026) plus three under `.codegraph/`, one of which was a duplicated
live SQLite database. git rewrites `.git/index` on nearly every command, so
iCloud keeps catching it mid-write and forking it. A stale `index N` is inert
on its own — git only ever reads `.git/index` — but it is proof the race is
happening, and a restore of the wrong copy would silently misstate the repo.

Rules that keep this survivable without moving the checkout:

1. **Leave "Optimize Mac Storage" OFF** (System Settings → Apple Account →
   iCloud → iCloud Drive). This is the single setting that matters. With it
   on, iCloud may evict file contents and leave `.icloud` placeholders — a
   build or a `git checkout` then fails, or blocks, when you are offline.
   Checked on this machine: off, and there are no placeholders anywhere in
   the project.

2. **Never point `-derivedDataPath` inside the repo.** Everything documented
   here writes to `/tmp` — `Tools/release_build.sh` uses `/tmp/vkey-<ver>-*`,
   `Tools/capture_marketing.sh` uses `/tmp/vkey-marketing-dd`, and the
   commands above use `/tmp/vkey-dd`. Xcode's GUI builds go to the shared
   `~/Library/Developer/Xcode/DerivedData`, also outside the repo. An ad-hoc
   run with a relative path once left **637 MB** in `build/`, which iCloud
   then had to upload and keep in sync.

   `.gitignore` does not help here: `build/`, `DerivedData/` and
   `build-release/` are all ignored by git and were still fully synced.
   **gitignore is not nosync.** Anything worth ignoring is worth deleting.

3. **Sweep for conflicted copies after heavy git work.** iCloud names them
   `<name> <n>`, so they are easy to find and easy to miss — a plain
   `find -name "* 2*"` will not catch `index 10`. This does catch them, and
   skips look-alike filenames by requiring the original to exist:

   ```bash
   find . \( -name "* [0-9]" -o -name "* [0-9].*" \
          -o -name "* [0-9][0-9]" -o -name "* [0-9][0-9].*" \) -print0 |
   while IFS= read -r -d '' f; do
     orig=$(printf '%s' "$f" | sed -E 's/ [0-9]{1,2}(\.[^.\/]+)?$/\1/')
     [ -e "$orig" ] && echo "$f"
   done
   ```

   Review the list, then delete. Follow with `git fsck` and `git status` to
   confirm the repo is intact.

If you ever want the race gone rather than managed, the fix that does not
move the working tree is `git init --separate-git-dir=<path outside iCloud>`,
which leaves a one-line `.git` file pointing elsewhere. Note it would need
the worktrees under `.claude/worktrees/` re-pointed as well.

## Vietnamese Linguistics Reference

**Telex keys**: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng, aa=â, oo=ô, ee=ê, aw=ă, ow=ơ, uw=ư, dd=đ

**VNI keys**: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng, 6=circumflex, 7=horn, 8=breve, 9=đ
