# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project Overview

vkey is a macOS Vietnamese Input Method Editor (IME) - a native keyboard input system for typing Vietnamese with diacritical marks. It supports Telex and VNI input methods with app-specific input mode memory.

**Current release**: read it, don't trust a number written here — `grep MARKETING_VERSION vkey.xcodeproj/project.pbxproj`, or the top *versioned* entry of [CHANGELOG.md](CHANGELOG.md) (a `## [Chưa phát hành]` section above it holds merged-but-unreleased work). Release process: [RELEASE.md](RELEASE.md).

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

**App/** - Application lifecycle, coordination, settings & migration
- `AppDelegate.swift` / `WindowCoordinator.swift` / `AccessibilityWatchdog.swift` - Lifecycle, window/activation-policy orchestration, trust polling & 2s revocation/tap-health/secure-input watchdog
- `AppState.swift` - Observable state container with Combine publishers for enabled state, typing method, Smart Switch transitions, and per-app input mode memory
- `InputProcessor.swift` - Main keyboard event coordinator wiring `WordBuffer`, `AutoCapitalizer`, `MacroExpander`, `SpellDecisionEngine`, `EmitPlan`, and `EventSimulator`
- `Setting.swift` / `SettingsModels.swift` / `ThemeModels.swift` / `DefaultsDerivedCache.swift` - Persistent settings & cached derived values
- `UserDataMigration.swift` / `UserDataExport.swift` / `UpgradeBackupPrompt.swift` / `StartupMigrations.swift` - Backup/restore & idempotent startup migrations
- `Updater.swift` - Sparkle wrapper · `FileExportService.swift` - shared `NSSavePanel`/`NSOpenPanel` JSON/text helpers

**Engine/** - Pure Foundation Vietnamese typing logic (zero `AppKit` / `Defaults`)
- `EngineOptions.swift` - Explicit options struct injected into engine operations
- `TiengViet.swift` - Vietnamese syllable model: tone marks (DauThanh), diacritics (DauMu), immutable consonant Tries, vowels
- `TiengVietParser/Transformer/Validator.swift` - parse a syllable, place marks, reject impossible ones (phonotactics)
- `Telex.swift` / `VNI.swift` - Input method implementations following TypingMethod protocol

**Input/** - Word state, diffing & commit pipelines
- `EmitPlan.swift` - Type-enforced NFC/NFD axis + transport plan invariant
- `WordBuffer.swift` - Syllable buffer, recovery mode, snapshot rollback, `dd` toggle
- `TextDiff.swift` - Pure Foundation NFC grapheme & NFD scalar diffing + UTF-16 caret step-back
- `AutoCapitalizer.swift` - Sentence-start auto-capitalization state machine
- `MacroExpander.swift` - Macro matching (exact + auto-capitalized variant) & case preservation
- `SpellDecisionEngine.swift` - Keep Vietnamese vs restore English decision logic

**Platform/** - macOS system interaction
- `EventHook.swift` - Global CGEvent tap for keyboard interception (requires Accessibility permission)
- `SecureInputMonitor.swift` / `RemoteInputPolicy.swift` / `ModifierHotkeyTracker.swift` - Secure Input scoping, Screen Sharing / remote-desktop stand-aside, and modifier-only hotkeys
- `EventSimulator.swift` / `AXDirectInjector.swift` - Synthetic CGEvent posting + Accessibility direct value replacement for Spotlight/omnibox
- `AppCompatibilityRegistry.swift` - Single source of truth for per-app sending strategies, NFC/NFD classification, terminals, browsers, overlays, remote viewers, and `canonicalAppBundle`
- `Focused.swift` / `AXHelpers.swift` / `FocusContextTracker.swift` - Accessibility API helpers, `FieldKind`, and coalesced focus tracking
- `FloatingHUDPanel.swift` / `ToggleHUDWindow.swift` / `NoticeHUDWindow.swift` - Borderless floating HUDs · `AccessibilityPermissionPane.swift` · `InputSourceMonitor.swift`

**KeyLayout/** - Keyboard mapping
- `KeyboardUS.swift` - US keyboard layout key code to character mapping
- `Keys.swift` - TaskKey enum for special keys (Enter, Tab, Space, arrows)
- `ModifierFormatting.swift` - Canonical macOS modifier glyph formatting (`⌃⌥⇧⌘`)

**Lexicon/** - Embedded word lists (`Resources/syllables.txt`) + GitHub `lexicon-update.json` fetch path
**Stats/** - Local-only usage statistics (`UsageStatistics.swift`, `StatsModels.swift`, `StatsStore.swift`, `PhraseTracker.swift`, `PersonalDictMiner.swift`, `SmartSwitchLearner.swift`)
**View/** - SwiftUI organized by role: `DesignSystem/`, `MenuBar/`, `Settings/`, `Sheets/`, `HUD/`, `Onboarding/`, `DonateView.swift`
**Marketing/** - `--export-marketing` screenshot exporter (dev tool, Debug builds only)

### Dependencies (Swift Packages)
- **Defaults** - UserDefaults wrapper
- **KeyboardShortcuts** - Shortcut recording/binding
- **LaunchAtLogin** - Auto-start functionality
- **Sparkle** - Silent auto-update; drives `appcast.xml` and the whole release flow

The Settings window is hand-built SwiftUI (`View/Settings/VKSettingsView.swift`),
not the `Settings` package. `vkey` and `vkeyTests` use Xcode `PBXFileSystemSynchronizedRootGroup`, so adding/moving/deleting files syncs automatically without editing `project.pbxproj`.

## Working copy location

The maintainer's checkout lives at `/Volumes/DATA/Claude/vkey` (`~/Desktop/Claude`
is a symlink to `/Volumes/DATA/Claude`). It moved there on 2026-08-23, **out of
iCloud Drive**, because syncing it had produced conflicted copies of `.git/index`
itself — five of them, `index 2` … `index 6`, May–June 2026 — plus three under
`.codegraph/`, one a duplicated live SQLite database. That race is gone; the
rules below survive it only as rationale.

Note `getcwd(2)` returns the physical path, so tools see `/Volumes/DATA/Claude/vkey`
even when you `cd` in via the Desktop symlink.

1. **Never point `-derivedDataPath` inside the repo.** Everything documented
   here writes to `/tmp` — `Tools/release_build.sh` uses `/tmp/vkey-<ver>-*`,
   `Tools/capture_marketing.sh` uses `/tmp/vkey-marketing-dd`, and the
   commands above use `/tmp/vkey-dd`. Xcode's GUI builds go to the shared
   `~/Library/Developer/Xcode/DerivedData`, also outside the repo. This is now
   about keeping the repo small, not about sync: an ad-hoc run with a relative
   path once left **637 MB** in `build/`. `.gitignore` does not delete anything —
   anything worth ignoring is worth deleting.

2. **Conflicted copies are legacy.** iCloud named them `<name> <n>`; nothing
   generates them any more, but old ones may still be lying around. To sweep —
   the pattern skips look-alike filenames by requiring the original to exist:

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

## Vietnamese Linguistics Reference

**Telex keys**: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng, aa=â, oo=ô, ee=ê, aw=ă, ow=ơ, uw=ư, dd=đ

**VNI keys**: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng, 6=circumflex, 7=horn, 8=breve, 9=đ
