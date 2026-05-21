# vkey Changelog

> **Lưu ý về Bản quyền và Đóng góp (Credits & Attribution)**: Kể từ phiên bản v1.3.9 đến v1.5.0, vkey đã học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc từ các dự án mã nguồn mở **[Caffee](https://github.com/khanhicetea/Caffee)** của tác giả KhanhIceTea, **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen (@xmannv), **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** của tác giả Khaphan, và tích hợp bộ cơ sở dữ liệu từ điển 7.184 âm tiết tiếng Việt chuẩn từ dự án mã nguồn mở **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của tác giả Luông Hiếu Thi (@hieuthi). Từ **v1.5.0** ("Bilingual Reborn") còn tích hợp thêm nguồn dữ liệu Anh ↔ Việt từ **[English Wiktionary](https://en.wiktionary.org/)** qua [Wiktextract / Kaikki.org](https://kaikki.org) (CC BY-SA 4.0) và **[wordfreq](https://github.com/rspeer/wordfreq)** của Robyn Speer. Từ **v1.6.1** bổ sung **[undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary)** của tác giả Vũ Anh (GPL-3.0) — tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN. Xem [`LICENSE-DATA.md`](LICENSE-DATA.md) để biết chi tiết license dữ liệu.

## [1.9.5] - 2026-05-21 — "HUD Invisible Fix + ToggleHUD Compact"

🚨 Hotfix v1.9.3-1.9.4: HUD đoán từ không hiển thị text.

### 🚨 Fix HUD đoán từ INVISIBLE (chỉ thấy box trắng trống)

User báo: gõ xong + commit → HUD chỉ hiện 1 box nhỏ trống, không có text "→ word ⇥ Tab".

**Root cause**: v1.9.3 đã set `controller.sizingOptions = []` với ý định "disable automatic window size proposing". NHƯNG `sizingOptions = []` cũng DISABLE compute fittingSize → `controller.view.fittingSize` return 0 hoặc tiny → `panel.setContentSize(fitSize)` set panel quá nhỏ → text bị clip mất khỏi vùng visible.

**Fix v1.9.5**:
- `sizingOptions = .preferredContentSize` (macOS 13+) — đúng chế độ: controller compute size, gọi `preferredContentSize` cho window biết.
- Thêm `controller.view.layoutSubtreeIfNeeded()` trước khi đọc `fittingSize` — force layout pass để có giá trị correct.

### 🪟 ToggleHUD giảm size + clear hẳn

User feedback v1.9.4: HUD chuyển ngôn ngữ vẫn to + chưa đủ trong suốt.

- Icon **56 → 40pt**.
- Label "Tiếng Việt"/"English" **20 → 16pt**.
- Frame width **170 → 130**.
- Padding vertical **22 → 14**.
- CornerRadius **24 → 18**.
- Spacing VStack **10 → 6**.
- Background layered: dùng `Color.black.opacity(0.08/0.35)` + `.ultraThinMaterial` → cảm giác "kính trong suốt" rõ hơn.
- Stroke border opacity giảm `0.15/0.40 → 0.10/0.25` (mềm hơn).
- Shadow nhẹ hơn (15→10 radius).

### Verify

- 194/194 tests pass.
- Manual: HUD đoán từ hiện text rõ "→ word ⇥ Tab" với font 16pt semibold; ToggleHUD compact + glass clear.

## [1.9.4] - 2026-05-21 — "HUD Readability & Transparency"

2 fix UX HUD theo user feedback.

### 🔤 PredictionHUD chữ to + đậm rõ

User feedback: chữ HUD đoán từ quá bé, khó đọc trên material background.

- Default font size **13 → 16pt** (vẫn user-configurable).
- Range Stepper **10-20 → 12-24pt**.
- Font weight `medium → semibold` (đậm hơn rõ rệt).
- Thêm subtle text shadow để tăng contrast trên material blur.
- Padding tăng `14×8 → 16×10` để chữ không sát cạnh.
- Stroke border opacity `0.10 → 0.15`.

### 🪟 HUD trong suốt hơn

User feedback: HUD chuyển ngôn ngữ cần trong suốt hơn hiện tại.

- Default `hudOpacityPercent` **100 → 75%** (cho user mới install).
- Range Stepper **50-100 → 30-100%** — user có thể chỉnh xuống rất trong suốt.
- Bổ sung `NSPanel.isOpaque = false` cho PredictionHUDWindow (trước v1.9.4 thiếu, theo Apple docs cho transparent window cần cả `isOpaque = false` + `backgroundColor = .clear`).
- Áp dụng cho cả ToggleHUD (chuyển ngôn ngữ) và PredictionHUD (đoán từ).

### Verify

- 194/194 tests pass.
- Build clean.
- Manual: HUD đoán từ hiện chữ 16pt semibold rõ; ToggleHUD ở 75% opacity nhẹ nhàng hơn.

## [1.9.3] - 2026-05-21 — "Critical HUD Crash Fix"

Hotfix khẩn cấp: v1.9.0/1/2 vẫn crash dù 2 đợt fix trước. Root cause cuối cùng đã được xác định + sửa triệt để.

### 🚨 Fix crash NSHostingView trong PredictionHUDWindow

Crash log v1.9.2 cho thấy cùng pattern v1.9.0:
```
EXC_BREAKPOINT
↳ NSHostingView.updateWindowContentSizeExtremaIfNecessary
↳ NSHostingView.updateConstraints
↳ NSWindow updateConstraintsIfNeeded
↳ _postWindowNeedsUpdateConstraints → NSException
```

**Root cause cuối**: `PredictionHUDWindow` dùng **`NSHostingView`** (direct) làm `panel.contentView`. `NSHostingView` mặc định gửi window constraint update requests qua `updateWindowContentSizeExtrema` → trong `NSPanel` borderless không có constraint pipeline đầy đủ → NSException → SIGTRAP/SIGABRT.

**ToggleHUDWindow đã dùng `NSHostingController`** (`panel.contentViewController = controller`) — không crash trên cùng setup. Khác biệt critical: `NSHostingController` không tự đẩy constraints lên window.

v1.9.1 (bỏ @Default trong View) và v1.9.2 (fittingSize + background-in-shape) đều **không sửa root cause** — vẫn dùng `NSHostingView`.

**Fix v1.9.3**:
- [PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift): `NSHostingView` → `NSHostingController`.
- Set `controller.sizingOptions = []` (macOS 13+) để disable automatic window size proposing hoàn toàn.
- Thêm `.fullSizeContentView` style mask cho panel.
- `panel.contentViewController = controller` thay `panel.contentView = hosting`.
- Apply same pattern ToggleHUD đã verify ổn định.

### 🧹 Bỏ "Tra cứu từ điển" tab Chính tả

User feedback: section "Tra cứu từ điển" (thêm ở v1.9.0) gây phân tâm, không cần thiết.

**Action**:
- Xóa Section + UI (line ~670-689 SettingView.swift).
- Xóa `@State lexiconSearchQuery` + computed `lexiconSearchResult` (~30 lines).

### Verify

- 194/194 tests pass.
- Build clean.
- Manual: bật prediction HUD + gõ liên tục → KHÔNG crash (trước v1.9.3 crash sau ~30s-2min).

### Files

- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift) — NSHostingView → NSHostingController.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — bỏ section "Tra cứu từ điển" + helpers.

## [1.9.2] - 2026-05-21 — "HUD Visual Polish"

3 fix UX HUD.

### 📦 Gom HUD customization vào block "Đoán từ tiếp theo"

Trước v1.9.2: Stepper "Cỡ chữ HUD đoán từ" + "Độ đậm HUD" ở Tab Chung (đáy form). Stepper "Khoảng cách HUD đến caret" ở Tab Chính tả (block prediction). 3 cài đặt liên quan đoán từ nhưng tách 2 tab.

**v1.9.2**: gom tất cả 3 Stepper vào cùng block `if wordPredictionEnabled` trong Tab Chính tả → section "Cấu hình kiểm tra chính tả". Chỉ visible khi bật prediction. Logic gom: 3 cài đặt đều ảnh hưởng PredictionHUD nên nên gọi cùng nhau.

### 🔤 ToggleHUD font cố định to + nền trong suốt

User feedback: HUD báo chuyển Tiếng Việt / Tiếng Anh font nhỏ khó nhìn.

[ToggleHUDView](vkey/Platform/ToggleHUDWindow.swift):
- Icon size **38 → 56pt** (font symbol).
- Frame icon **44×44 → 64×64**.
- Label "Tiếng Việt"/"English" size **14 → 20pt**.
- Badge "VI"/"EN" size **11 → 13pt** + padding rộng hơn.
- Frame width **130 → 170**.
- Padding vertical **18 → 22**.
- CornerRadius **20 → 24**.

Áp dụng pattern `.background(.ultraThinMaterial, in: shape)` thay vì `RoundedRectangle.fill(material)` — đảm bảo nền clipped vào shape, trong suốt rõ hơn.

### 🚨 Fix bug bitmap bo góc HUD

User báo HUD có lỗi visual: "bên phải bo nhiều còn bên trái có hình đè vuông góc".

**Root cause**:
1. **PredictionHUDWindow**: `targetFrame` dùng heuristic `text.count × 9 + 40` cho width — không match SwiftUI intrinsic content width. Panel rộng hơn SwiftUI clipShape → vùng panel ngoài shape không có background → default panel chrome (vuông góc) lộ ra.
2. **ToggleHUDWindow**: styleMask thiếu `.borderless` → default window chrome render vuông góc cạnh shape SwiftUI.
3. SwiftUI pattern `.background(.material).clipShape(...)` đôi khi material vẽ trước clip → bitmap render khác nhau giữa các góc.

**Fix**:
- [PredictionHUDWindow.swift:55-69](vkey/Platform/PredictionHUDWindow.swift:55) — dùng `hosting.fittingSize` cho panel content size thay vì heuristic.
- [ToggleHUDWindow.swift:104](vkey/Platform/ToggleHUDWindow.swift:104) — thêm `.borderless` vào styleMask.
- Cả 2 HUD view — `.background(.ultraThinMaterial, in: RoundedRectangle(...))` thay pattern cũ.

### Verify

- 194/194 tests pass.
- Build clean.

## [1.9.1] - 2026-05-21 — "Crash Fix + Quick Config Preset"

Hotfix v1.9.0 crash + UX restructure tab Chính tả.

### 🚨 Fix crash khi bật Prediction HUD (URGENT)

User báo crash liên tục sau khi bật prediction HUD (tắt thì OK). Crash log cho thấy:

```
NSException trong _postWindowNeedsUpdateConstraints
↳ NSHostingView.invalidateSafeAreaInsets
↳ NSHostingView.windowDidLayout → updateAnimatedWindowSize
```

**Root cause v1.9.0**: thêm `@Default(.predictionHUDFontSize)` + `@Default(.hudOpacityPercent)` vào struct `PredictionHUDView` + `ToggleHUDView`. Khi Defaults change (hoặc publisher fires lúc launch), SwiftUI re-render → intrinsic content size change → hosting view request window resize → animation conflict trong NSPanel → NSException → SIGABRT.

**Fix**: refactor View structs — bỏ `@Default`, pass `fontSize`/`opacity` qua init parameters. `PredictionHUDWindow.show()` đọc Defaults 1 lần, recreate hosting view mỗi show (cost negligible: 1 lần / 3s). ToggleHUD opacity moved sang `panel.alphaValue` (NSPanel level, không phụ thuộc SwiftUI re-render).

### 🎨 HUD nền bo tròn hơn

User feedback HUD góc bo nhỏ. Tăng PredictionHUD cornerRadius **10 → 16** + stroke opacity **0.15 → 0.10** (mềm hơn). ToggleHUD giữ nguyên 20 (đã đẹp).

### 🧹 Bỏ "Kích hoạt nhanh tất cả tính năng"

Section "Phím tắt thông minh" trong tab Chính tả với toggle bulk 7 settings — đã bị thay thế bằng Quick Config Preset (4 mức rõ ràng hơn).

### 🎛️ Quick Config Preset 4-state

Section mới "Cấu hình nhanh" ở đầu tab Chính tả với Picker 4 mức:

| Toggle | Cao | Trung bình | Cơ bản | Người dùng |
|---|---|---|---|---|
| `spellCheckEnabled` | ✓ | ✓ | ✓ | _giữ_ |
| `spellCheckInSentenceEnabled` | ✓ | ✓ | _tắt_ | _giữ_ |
| `englishAutoRestoreEnabled` | ✓ | ✓ | _tắt_ | _giữ_ |
| `suggestionEnabled` | ✓ | ✓ | _tắt_ | _giữ_ |
| `autoApplyHighConfidenceSuggestion` | ✓ | _tắt_ | _tắt_ | _giữ_ |
| `personalDictionaryEnabled` | ✓ | ✓ | ✓ | _giữ_ |
| `autoPersonalDictFeedback` | ✓ | _tắt_ | _tắt_ | _giữ_ |
| `useEnVnReference` | ✓ | ✓ | _tắt_ | _giữ_ |
| `wordPredictionEnabled` | ✓ | _tắt_ | _tắt_ | _giữ_ |
| `autoTypoCorrection` | ✓ | ✓ | _tắt_ | _giữ_ |

**Logic giảm dần**:
- **Cao**: tất cả auto-features — vkey "hiểu ý" tối đa.
- **Trung bình**: spell-check + auto-restore + suggestion (không auto-apply) + personal dict + auto-typo. User vẫn review.
- **Cơ bản**: chỉ spell-check master + personal dict. Tắt mọi auto-feature.
- **Người dùng**: không thay đổi gì (custom).

### Files

- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift) — fix crash + cornerRadius 16.
- [vkey/Platform/ToggleHUDWindow.swift](vkey/Platform/ToggleHUDWindow.swift) — opacity ở panel.alphaValue.
- [vkey/App/Setting.swift](vkey/App/Setting.swift) — `quickConfigPreset` key mới.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — enum `QuickConfigPreset` + helpers + Picker UI.

### Verify

- 194/194 tests pass.
- Build clean.

## [1.9.0] - 2026-05-21 — "Deep Audit Patch + UX Upgrades"

Sau khi rà soát toàn diện qua 3 audit agents (Engine/Lexicon, Platform/UI, Stats/Data), v1.9.0 bao gồm: 1 bug fix HIGH, gỡ dead code, 4 upgrade nội bộ, và 4 feature mới.

### 🚨 Fix bug HIGH — EnVnReference Trie memory leak

[EnVnReference.swift:43](vkey/Lexicon/EnVnReference.swift:43) — `enPrefixTrie` là `let` từ v1.5.0 → swap-and-replace không thực sự xảy ra. `rebuildPrefixTrie()` chỉ insert thêm vào trie cũ → cumulative entries qua mỗi `load()` (lexicon update). Memory leak + stale prefix results.

**Fix**: Convert `let` → `var`, swap fresh Trie trong `load()`, xóa method `rebuildPrefixTrie()`. Idempotent, memory cấp phát đúng.

### Cleanup — gỡ dead code

[LexiconManager.swift](vkey/Lexicon/LexiconManager.swift) — `hasEnglishPrefix(_:)` + `enWordPrefixes` cache (~500KB) thêm ở v1.8.3 nhưng chưa hook vào Engine. v1.8.4 đã có solution thay thế (select-and-replace). Gỡ ~30 lines + 500KB memory.

### Upgrades

- **B2: Privacy gate cho export** — [UserDataMigration.swift:328-331](vkey/App/UserDataMigration.swift:328) — `currentExport` giờ tôn trọng `Defaults[.statisticsEnabled]`. Trước v1.9: kể cả khi user tắt stats, backup vẫn chứa data → privacy gap.

- **B3: Atomic clearAll** — [UsageStatistics.swift:638-654](vkey/Stats/UsageStatistics.swift:638) — xóa files TRƯỚC, reset counters SAU; cancel `pendingFlushItem`. Tránh inconsistent state khi crash giữa chừng.

- **B4: Backup retention cleanup** — [UserDataMigration.swift:368-403](vkey/App/UserDataMigration.swift:368) + AppDelegate launch hook — silent cleanup `~/Library/Application Support/vkey/backups/`: giữ ≥5 file gần nhất, xóa file > 30 ngày khi vượt 5. Tránh tích lũy vô hạn.

- **B5: Deterministic NGram pruning** — [NGramStore.swift](vkey/Stats/NGramStore.swift) — secondary sort by key alphabetical khi nhiều keys cùng max count. Output stable giữa các flush, dễ debug + test.

### 🎨 Features mới

- **C2: HUD customization** — Tab Chung → 2 Stepper mới:
  - "Cỡ chữ HUD đoán từ" (10-20pt, default 13)
  - "Độ đậm HUD" (50-100%, default 100%, áp dụng cả ToggleHUD và PredictionHUD)
  - User có thể giảm độ đậm để HUD trong suốt hơn, đỡ "tranh" với editor.

- **C4: Smart Switch auto-learn telemetry** — Tab Smart Switch hiển thị thêm 1 dòng: "Auto-learn: đã gợi ý X lần, áp dụng Y" + nút "Đặt lại số liệu". 2 Defaults counters mới (`smartSwitchSuggestionsTotal`, `smartSwitchSuggestionsAccepted`) increment trong SuggestionSheet.load() + applyAll().

- **C6: AX query timeout** — [Focused.setupAXTimeout(0.1)](vkey/Platform/Focused.swift:11) gọi ở AppDelegate launch. Áp dụng `AXUIElementSetMessagingTimeout` cho system-wide element → cover tất cả AX query. Tránh AX hang khi target app không responsive (giảm risk macOS disable event tap). Default macOS 6000ms → giờ 100ms.

- **C11: Tra cứu từ điển inline** — Tab Chính tả thêm Section "Tra cứu từ điển". User gõ 1 từ → realtime hiển thị từ đó thuộc lexicon nào: VN/EN/Embedded/Keep/Personal Allow/Keep/Deny. Useful để verify dictionary + train Personal Dict.

### Files

- [vkey/Lexicon/EnVnReference.swift](vkey/Lexicon/EnVnReference.swift) — bug fix Trie.
- [vkey/Lexicon/LexiconManager.swift](vkey/Lexicon/LexiconManager.swift) — gỡ dead code.
- [vkey/App/UserDataMigration.swift](vkey/App/UserDataMigration.swift) — privacy gate + backup retention.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — atomic clearAll.
- [vkey/Stats/NGramStore.swift](vkey/Stats/NGramStore.swift) — deterministic prune.
- [vkey/App/Setting.swift](vkey/App/Setting.swift) — 4 Defaults keys mới (HUD font/opacity + SS counters).
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — Stepper HUD + section tra cứu.
- [vkey/View/SmartSwitchView.swift](vkey/View/SmartSwitchView.swift) — telemetry row.
- [vkey/View/SmartSwitchSuggestionSheet.swift](vkey/View/SmartSwitchSuggestionSheet.swift) — telemetry increments.
- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift) — apply HUD settings.
- [vkey/Platform/ToggleHUDWindow.swift](vkey/Platform/ToggleHUDWindow.swift) — apply HUD opacity.
- [vkey/Platform/Focused.swift](vkey/Platform/Focused.swift) — setupAXTimeout.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — backup cleanup + setupAXTimeout calls.

### Verify

- 194/194 tests pass.
- Build clean.
- Backward-compat: import file backup v1.7.x-1.8.x cũ vẫn hoạt động (Defaults keys mới có default values).

## [1.8.4] - 2026-05-21 — "Settings Width + Telex Restoration Fix"

4 fix UX phát hiện qua dùng thực tế v1.8.3.

### 📐 Settings window mở rộng default

Default size 432×648 → **540×648**. Lý do: nút "Chạy compute đề xuất ngay" trong tab Thống kê bị truncate (`Chạy compute đề xuấ…`) ở 432px. Height giữ nguyên. Vì dùng `.contentMinSize`, user vẫn drag resize tự do; autosave lưu size đã chỉnh.

### 🚨 Fix bug Telex "teen → tên" regression

User báo bug: gõ "teen" mong ra "tên" (Telex t + ee→ê + n) nhưng output "teen" raw. Root cause: regression v1.7.9 — post-replay English check ở [InputProcessor.swift:330](vkey/App/InputProcessor.swift:330) dùng `isEnglishWord` (full enLexicon 9826 từ). Sau khi bump dict 126→9826, các từ EN ngắn match Telex VN pattern ("teen"/"men"/"tens"/...) bị nhầm sang raw thay vì giữ VN.

**Fix**: thay `isEnglishWord` → `isInstantRestoreEnglish` (narrow 126 từ embedded + userAllow). Khớp philosophy ở line 359-360 (doubled tone check). Các stem ngắn telex (cos/the/tee/see/tie/hop/thee) vẫn lock raw đúng vì có trong embedded list; "teen"/"men"/"tens"/... được giải phóng → giữ VN.

Test `testTelexPostReplayKeepsVN`: `teen → tên`, `tees → tế` (regression ko đụng), `theem → thêm`.

### 🤖 Personal Dict — loại từ đã có trong từ điển chung

[UsageStatistics.swift:1157](vkey/Stats/UsageStatistics.swift:1157) thêm filter `isEnglishWord` cho `.allow` candidates. Từ như "footer", "syntax", "abacus" đã có trong built-in enLexicon (9826 từ) — không cần promote vào Personal Dict (spell-check đã nhận diện). Tránh suggestion list trùng lặp.

### 📊 Top cụm 2-3 từ tiếng Việt — thêm "Xem chi tiết"

Trước v1.8.4: section "Top cụm 2-3 từ tiếng Việt" chỉ hiển thị `prefix(10)`, không có button. Section "Top từ tiếng Việt (tuần này)" đã có pattern button "Xem chi tiết" mở sheet — giờ replicate cho phrases.

- Extend `TopWordsDetailCategory` enum thêm `.vietnamesePhrases`.
- Phrase section render button "Xem chi tiết (N)" khi total > 10.
- `detailWords(for:)` switch case mới — return `aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)`.
- Reuse `TopWordsDetailSheet` — title "Top cụm 2-3 từ tiếng Việt".

### Verify

- 194/194 tests pass (từ 193, +1 `testTelexPostReplayKeepsVN`).
- Build clean.

### Files

- [vkey/vkeyApp.swift:63-66](vkey/vkeyApp.swift:63) — defaultSize width 432→540.
- [vkey/App/InputProcessor.swift:330-340](vkey/App/InputProcessor.swift:330) — isEnglishWord → isInstantRestoreEnglish.
- [vkey/Stats/UsageStatistics.swift:1156-1160](vkey/Stats/UsageStatistics.swift:1156) — filter isEnglishWord cho .allow.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — enum extension + phrase button + detailWords case.
- [vkeyTests/vkeyTests.swift](vkeyTests/vkeyTests.swift) — testTelexPostReplayKeepsVN.

## [1.8.3] - 2026-05-21 — "Spell-Check UX + Telex App Compat"

4 fix UX phát hiện qua dùng thực tế.

### Move Word Prediction UI Tab Chung → Tab Chính tả

Toggle "Đoán từ tiếp theo" + Stepper "Khoảng cách HUD đến caret" trước đây nằm ở Tab Chung. Vì prediction thuộc chức năng spell-checking (gợi ý từ tiếp theo dựa trên từ điển), giờ chuyển vào Tab Chính tả → section "Cấu hình kiểm tra chính tả" — gom cùng các toggle khác (auto-restore, suggestion, personal dict).

### 🚨 Fix Top từ ngoài tiếng Việt — loại các từ VN không dấu

Section "Top từ ngoài tiếng Việt" (tab Thống kê) đang hiển thị các từ tiếng Việt phổ thông không dấu như `hay`, `chi`, `cho`, `to`, ... Đây là từ VN trong lexicon, không phải từ ngoài VN. Lý do: khi user gõ "hay" không dấu, SpellDecisionEngine quyết định `.restoreRawEnglish` → counter `enWordCounts` tăng — UI cũ không filter.

**Fix**: [StatisticsView.swift:351-357](vkey/View/StatisticsView.swift:351) `isCleanTopWord` case `.english` giờ check `LexiconManager.shared.isVietnameseWord(word)` → return false. Section giờ chỉ hiển thị từ THỰC SỰ ngoài VN (raw English, ký tự đặc biệt, "lol", "okay"...).

### 🚨 Fix bug Telex "footer → foooter" trên target app

User báo bug: gõ "footer" + Space trên một số app (Word, Slack, Notion, browsers...) → output "foooter" (thừa 'o'). Root cause: Telex transform "oo" → "ô" ở giữa word, sau đó commit-time `restoreRawEnglish` dùng `sendReplacement` (backspace+insert). Trên các app có autocomplete inline / silent-swallow backspace, màn hình hiển thị bị chồng → raw 'o' + transformed 'ô' lẫn nhau.

**Fix**: [InputProcessor.swift:909-940](vkey/App/InputProcessor.swift:909) — commit-time `.restoreRawEnglish` giờ dùng `sendSelectAndReplace` (Shift+Left + insert) khi `isFixAutocompleteApp()` return true (search/combobox/per-app override). Khớp pattern đã dùng ở `handleKey` line 791. Tránh backspace strategy mismatch.

**Cũng tận dụng v1.8.2 `currentFocusedElementIsSearchOrCombo`**: nếu caret rơi vào search field hoặc combobox bất kể app — `isFixAutocompleteApp()` return true → cũng dùng select-and-replace path.

### Footer version label tiếng Việt

[SettingView.swift:259-266](vkey/View/SettingView.swift:259) — đổi `Version 1.8.2` italic sang `Phiên bản 1.8.3 ngày 21/5/2026` thường. Date hardcode cho release, update mỗi version.

### Verify

- 193/193 tests pass (từ 192, +1 test `testTelexEnglishOORecovery` cover footer/book/books/look/wood/food).
- Build clean.
- Lưu ý: một số từ tiếng Anh có "oo" + final cluster valid VN (room/door/foot) vẫn transform sang VN tại engine — đây là behavior intent (user thực sự muốn gõ "rôm"/"dổ"/"fôt"?). Fix UX bug "foooter" via select-and-replace path đảm bảo commit-time restore không thừa ký tự nếu user gõ rồi commit như English word.

### Files

- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — move Word Prediction UI + footer version label.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — filter VN words case `.english`.
- [vkey/Lexicon/LexiconManager.swift](vkey/Lexicon/LexiconManager.swift) — thêm `enWordPrefixes` cache + `hasEnglishPrefix(_:)` API (chưa dùng ở 1.8.3, để dành cho v1.9 nếu cần generic prefix lock).
- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift) — commit-time restore dùng select-and-replace khi fix-autocomplete app.
- [vkeyTests/vkeyTests.swift](vkeyTests/vkeyTests.swift) — `testTelexEnglishOORecovery`.

## [1.8.2] - 2026-05-21 — "Focus Tracking + Polish"

Bundle các cải tiến platform-layer + 4 fix nhỏ-trung bình phát hiện qua audit toàn dự án.

### Focus tracking nâng cấp

- **Focus-shifting key detection (EventHook)**: phím chuyển focus trong app (Tab, Enter, Esc, mũi tên) giờ cũng trigger `refreshFocusedBundleIdAsync()` — không chỉ mouse-click. Trước đây nếu user dùng phím để chuyển ô input, vkey chỉ cập nhật cached bundle ID khi click chuột tiếp theo → có thể miss tới lần keystroke kế.
- **Search/ComboBox auto fix-autocomplete**: thêm `Focused.isComboBoxOrSearchField()` query song song với bundle ID query trong async refresh. Khi caret rơi vào search field hoặc combo box (bất kể app nào), `isFixAutocompleteApp()` tự động return true → kích hoạt strategy chống dính chữ. Cải thiện UX với Spotlight, Find bar, autocomplete dropdown trong Safari/Chrome.

### Engine accuracy

- **Backspace replay accuracy**: `reconstructState` (InputProcessor) thêm `lastTransformedForStep` + `shouldStopProcessing` integration cho double-tap tone marks. Backspace replay giờ khớp luồng push() chính → đảm bảo cùng output transform với typing live (vd. "tess" sau backspace + replay = đúng "tess" English-locked, không nhầm tone).
- **Length-2 late D toggle**: `chuKhongDau.count >= 2` (trước >= 3) trong `tryLateDToggle` (TiengVietState). Cho phép gõ `dad → đa`, `da9 → đa`, `ded → đe` — không cần 3 ký tự mới trigger gạch D late.

### Polish + perf

- **🎨 Theme system hoàn thiện**: thêm 14 emoji mappings mới vào ThemedSymbol (arrow.up.and.down, envelope.fill, tray.full, rectangle.stack.badge.plus, list.bullet, stethoscope, tray, person.fill, lock.fill, nosign, gear.badge.questionmark, lock.square, character.bubble.fill, keyboard). Refactor 6 file View còn dùng `Image(systemName:)` sang `ThemedSymbol(name:)` — toàn app giờ consistent theme `.default`/`.threeD`/`.emoji`.
- **⚡ Levenshtein perf**: `looksLikeKeyboardMashing` (UsageStatistics) pre-build length-bucketed English lexicon (`[Int: [String]]`). Scan chỉ buckets có độ dài trong khoảng `[n-maxDist, n+maxDist]` thay vì full 9826 từ. **Performance**: ~50-100× faster cho weekly feedback pass.
- **📊 NGramStore trigram pruning log**: thêm `os_log` cho trigram pruning (trước chỉ có cho bigram). Giúp diagnose disk growth.
- **🛡️ HUD timer deinit**: `PredictionHUDWindow` thêm `deinit { hideTimer?.invalidate() }` — defensive cho future refactor (singleton hiện không bao giờ release, nhưng tránh timer fire vào freed memory).

### Verify

- 192/192 tests pass (từ 190 ở v1.8.1, +2 tests cho `dad/ded/da9` stroked D + revised `testBackspaceRollback`).
- Build clean trên Release.
- `secureInputActive` race con: rà soát kỹ — bypass IME check (EventHook:215) dùng `isSecureInput` LOCAL không phụ thuộc `appState.secureInputActive`, không có functional race ảnh hưởng IME. UI menu bar có lag ms-level (không đáng fix).

### Files

- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift) — `reconstructState` + `isSearchOrComboFocused`.
- [vkey/App/AppState.swift](vkey/App/AppState.swift) — `currentFocusedElementIsSearchOrCombo` + double-call `refreshFocusedBundleIdAsync` (init + activeApp change).
- [vkey/Platform/EventHook.swift](vkey/Platform/EventHook.swift) — focus-shifting key detection.
- [vkey/Engine/TiengVietState.swift](vkey/Engine/TiengVietState.swift) — chuKhongDau.count >= 2.
- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift) — deinit timer.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — length-bucketed mashing detector.
- [vkey/Stats/NGramStore.swift](vkey/Stats/NGramStore.swift) — trigram log.
- [vkey/View/ThemedSymbol.swift](vkey/View/ThemedSymbol.swift) — 14 emoji mappings mới.
- [vkey/vkeyApp.swift](vkey/vkeyApp.swift), [vkey/Platform/ToggleHUDWindow.swift](vkey/Platform/ToggleHUDWindow.swift), [vkey/View/MacroView.swift](vkey/View/MacroView.swift), [vkey/View/SmartSwitch*.swift](vkey/View/) — Image(systemName) → ThemedSymbol.
- [vkeyTests/vkeyTests.swift](vkeyTests/vkeyTests.swift) — +2 tests, total 192.

## [1.8.1] - 2026-05-21 — "Prediction UX Fix"

3 fix UX cho tính năng Đoán từ tiếp theo (`wordPredictionEnabled`):

### 🚨 Fix bug thừa space khi Tab accept prediction sau Space commit

User gõ "đoán" + Space → vkey commit "đoán " (đã có trailing space) + show HUD "từ" → user ấn Tab → kết quả `"đoán  từ"` (2 spaces). Gốc rễ: branch `wordBuffer.wordState.isBlank == true` trong [InputProcessor.swift:597](vkey/App/InputProcessor.swift:597) chèn `" \(prediction)"` (leading space) — nhưng caret đã ở sau space rồi.

**Fix**: branch buffer-sạch giờ chèn THẲNG prediction, không leading space. Branch buffer-dở (đang gõ chưa commit) giữ nguyên — `applySpellDecisionOnCommit` đã emit space khi commit nên chèn prediction sau đó đúng vị trí.

| Scenario | Trước (1.8.0) | Sau (1.8.1) |
|---|---|---|
| Gõ "đoán" + Space + HUD "từ" + Tab | `"đoán  từ"` (2 spaces) | `"đoán từ"` ✓ |
| Gõ "vi" + Tab (buffer dở) | `"việt"` | `"việt"` ✓ giữ nguyên |
| Gõ "viet nam vi" + Tab | `"viet nam việt"` | `"viet nam việt"` ✓ giữ nguyên |

### 🎯 HUD prediction cách caret N dòng (configurable)

Trước 1.8.1: HUD chỉ cách caret 4px → quá gần, hay che dòng đang gõ. Giờ HUD cách caret **N dòng văn bản** (default 4, range 1-10) — user chỉnh trong Settings → tab Chung.

Implementation: tính `lineHeight = max(caret.height, 16)` từ `kAXBoundsForRangeParameterizedAttribute`, separation = `lineHeight * N`. Logic flip-down giữ nguyên + thêm clamp out-of-bounds.

### Settings UI mới

Tab Chung → Stepper "Khoảng cách HUD đến caret" hiện ngay dưới mô tả "Đoán từ tiếp theo". Stepper chỉ visible khi toggle word prediction đang ON.

### Files

- [vkey/App/InputProcessor.swift:594-605](vkey/App/InputProcessor.swift:594) — bỏ leading space trong branch buffer-sạch.
- [vkey/App/Setting.swift:301-304](vkey/App/Setting.swift:301) — Defaults key `predictionHUDLineOffset` (default 4).
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — Stepper UI 1-10.
- [vkey/Platform/PredictionHUDWindow.swift:105-128](vkey/Platform/PredictionHUDWindow.swift:105) — separation theo `lineHeight * offsetLines` + clamp.

## [1.8.0] - 2026-05-21 — "Platform Plumbing: Event-Driven + File-Backed N-grams"

4 cải tiến platform-layer: Smart Switch 3-trạng thái hoàn chỉnh trong overlay path, event tap callback nhẹ hơn (gỡ AX call đồng bộ), Personal Dict thông minh hơn (lọc keyboard mashing), bigram/trigram tách ra file-backed store thay vì UserDefaults plist.

### 🚨 Fix Smart Switch trong overlay: hỗ trợ đủ 3 trạng thái

Phiên bản v1.7.0 đưa cấu hình Smart Switch 3-trạng thái (`.disabled` / `.englishMode` / `.vietnameseMode`), nhưng [Overlay Probing trong EventHook](vkey/Platform/EventHook.swift) chỉ phản ứng đúng với `.englishMode`. App được cấu hình `.vietnameseMode` (muốn bật bộ gõ trong overlay) không được kích hoạt; `.disabled` cũng không khớp pattern canonical trong `AppState.activeApplicationDidChange`.

**Fix**: thay decision boolean bằng decision 3-trạng thái dùng `Bool?` (nil = không can thiệp, true = bật, false = tắt). Khớp với pattern ở [AppState.swift:180-185](vkey/App/AppState.swift:180). Legacy `smartSwitchApps` fallback giữ behaviour cũ (tắt bộ gõ).

| Cấu hình | Hành vi cũ | Hành vi mới |
|---|---|---|
| `.englishMode` | ✓ Tắt | ✓ Tắt |
| `.vietnameseMode` | ✗ Không thay đổi | ✓ Bật bộ gõ |
| `.disabled` | ✗ Không thay đổi | ✓ Tắt |
| Legacy list | ✓ Tắt | ✓ Tắt |
| Không cấu hình | Restore | Restore |

### ⚡ Event Tap nhẹ hơn: gỡ AX call đồng bộ khỏi callback

Trước: mỗi `keyDown` callback trong [EventHook event tap](vkey/Platform/EventHook.swift) có thể trigger `Focused.focusedAppBundleId()` đồng bộ → gọi chuỗi AX API (`AXUIElementCopyAttributeValue`, `AXUIElementGetPid`, `NSRunningApplication(processIdentifier:)`). Dù throttle 300ms, vẫn có nguy cơ macOS vô hiệu hóa event tap khi callback chậm.

Fix: chuyển sang push-based. [AppState](vkey/App/AppState.swift) cache `currentFocusedBundleId`, cập nhật trên `NSWorkspace.didActivateApplicationNotification` (cross-app overlay như Spotlight/Raycast/Alfred) + async refresh trên mouse-click (in-app sub-window focus). Event tap callback chỉ đọc property cached → zero AX work trong hot path.

Gỡ luôn `lastAXQueryTime` + `cachedFocusedBundleId` (không còn dùng).

### 🤖 Personal Dict: lọc keyboard mashing trước khi gợi ý

Trước: `computePendingSuggestions` trong [UsageStatistics](vkey/Stats/UsageStatistics.swift) chỉ check restoration frequency ≥ 5. User vô tình gõ ngẫu nhiên (`asdfgh`, `xzcvbn`, `qwertyu`) đủ 5 lần → chuỗi này lọt vào Personal Dictionary suggestion list, gây nhiễu.

Fix: thêm filter `looksLikeKeyboardMashing` cho candidate `.allow`:
1. Độ dài > 18 ký tự → reject (không phải từ tiếng Anh hợp lý).
2. Không có nguyên âm → reject (loại `xzcvbn`, `qwrtp`).
3. Levenshtein distance > `max(2, len/4)` với MỌI từ trong English lexicon → reject (loại `asdfgh`).

Không áp dụng cho `.keep` (từ tiếng Việt có dấu — không nên so với English lexicon). Tái sử dụng `SuggestionService.levenshtein` (đổi từ `private` → `static internal`).

### 💾 Bigram/Trigram: tách khỏi UserDefaults plist

Trước: [PredictionEngine](vkey/Input/PredictionEngine.swift) lưu `userBigrams`/`userTrigrams` dạng `[String: [String: Int]]` trong Defaults. Mỗi commit từ → đọc-mutate-ghi toàn bộ dict trên main thread. Sau vài tháng dict có thể đạt vài MB → mỗi lần ghi block UI vài chục ms.

Fix: tách ra `NGramStore` mới ([vkey/Stats/NGramStore.swift](vkey/Stats/NGramStore.swift)), match pattern `UsageStatistics`:
- Concurrent queue + barrier writes (cho phép multiple readers từ `topPrediction` đồng thời).
- Throttled flush 10s ra atomic JSON tại `~/Library/Application Support/vkey/ngram/ngrams.json`.
- Migration 1 chiều khi launch: `Defaults[.userBigrams]/[.userTrigrams]` → file store → xóa Defaults (idempotent).
- Pruning bounded: mỗi prev key cap 50 next words, max 5000 bigram keys / 10000 trigram keys (giữ top theo count).

Refactor:
- [PredictionEngine.swift](vkey/Input/PredictionEngine.swift) — `collectCandidates` và `learnTransition` đi qua `NGramStore.shared`.
- [UserDataMigration.swift](vkey/App/UserDataMigration.swift) — import/export đọc qua `NGramStore.snapshot()` / `replaceAll()` / `merge()`.
- [Setting.swift](vkey/App/Setting.swift:322) — `userBigrams`/`userTrigrams` keys đánh dấu Deprecated 1.8.0.
- [AppDelegate.swift](vkey/App/AppDelegate.swift) — bootstrap `NGramStore.shared` lúc launch (chạy migration ngay) + `flushNowSync` lúc terminate.

### Verify

- Build clean: ✓
- Test suite: 190 tests pass (0 failures).
- Migration: idempotent — Defaults đã clear sẽ skip; data từ Defaults cũ copy nguyên vẹn sang file lần đầu launch.
- Backward-compat: import từ file backup v1.7.x cũ vẫn hoạt động (UserDataMigration đọc cùng JSON shape).

### Files

- [vkey/Platform/EventHook.swift](vkey/Platform/EventHook.swift) — 3-state overlay logic + bỏ AX query sync + bỏ cache properties.
- [vkey/App/AppState.swift](vkey/App/AppState.swift) — thêm `currentFocusedBundleId` + `refreshFocusedBundleIdAsync`.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — `looksLikeKeyboardMashing` filter trong `computePendingSuggestions`.
- [vkey/Lexicon/SuggestionService.swift](vkey/Lexicon/SuggestionService.swift) — `levenshtein` từ `private` → `static internal`.
- [vkey/Stats/NGramStore.swift](vkey/Stats/NGramStore.swift) — MỚI: file-backed n-gram store singleton.
- [vkey/Input/PredictionEngine.swift](vkey/Input/PredictionEngine.swift) — refactor read/write sites sang `NGramStore`.
- [vkey/App/UserDataMigration.swift](vkey/App/UserDataMigration.swift) — import/export qua `NGramStore` API.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — bootstrap + terminate flush.
- [vkey/App/Setting.swift](vkey/App/Setting.swift) — deprecated comments cho legacy keys.

## [data] - 2026-05-20 — lexicon v6 → v7 (deep merge undertheseanlp)

Lexicon data update (KHÔNG cần release app mới — chỉ commit + push `lexicon-update.json`; app v1.6.2+ tự fetch trong 24h hoặc bấm nút "Cập nhật từ điển ngay").

### Deep merge từ undertheseanlp/dictionary phrases

Phase v6 (1.6.1) chỉ extract single-token entries. Phase v7 này extract token từ TẤT CẢ multi-word phrases ("công ty" → ["công", "ty"]), cross-validate qua tần suất phrase, áp phonotactic filter học từ baseline 7,184 curated.

**Three-tier classification**:

| Tier | Filter | Raw | Phonotactic pass |
|------|--------|-----|------------------|
| A | VN marker + ≥2 phrases (cross-validated) | 173 | **157** |
| B | VN marker + 1 phrase | 550 | **483** |
| C | ASCII loanword + ≥3 phrases | 31 (curated → 20) | **20** |

**Phonotactic filter** loại: foreign words (`chlorhydric`, `mêga`), non-VN initial clusters (`drăm`, `kpăng`, `phlạo`), garbage from Wiktionary templates.

**Tier C whitelist** (20 từ vay phổ biến): acid, alpha, apacthai, axit, beta, cassette, celsius, clo, diesel, euclid, fahrenheit, internet, ion, kali, kalium, logic, nitrat, oxy, radio, video. SKIP: short/ambiguous (ya, ch, cd, cn, ph, gmt, ka).

**Final**: 8,234 → **8,894 syllables** (+660 từ chuyên ngành, regional, loanword).

### Verify

- File 103.8 KB (vẫn dưới safe ceiling 1 MB)
- Parse 0.34 ms, set construct 0.25 ms (zero perf impact)
- Spot-check additions: ✓ "axit", "internet", "video", "kali", "bàm", "chòe", "choàm" present
- Garbage filter: ✓ "chlorhydric", "drăm", "ya", "gmt", "cd", "ch" all dropped
- Baseline preserved: ✓ "của", "và", "tôi", "công", "kính", "an" all present

### Tooling

- Script mới: [Tools/merge_underthesea_deep.py](Tools/merge_underthesea_deep.py) — re-runnable, idempotent (skip nếu token đã có).
- Bump `lexicon-update.json` version 6 → 7 → app sẽ fetch tự động.

## [1.7.11] - 2026-05-20 — "VN Priority on Diacritic & Personal Dict UX"

3 fix sau v1.7.10: balanced policy ưu tiên VN khi có dấu (car→cả không bị restore EN), gộp 1 section ảnh trong README, di chuyển nút "Gửi cho tác giả" ra tab Chính tả.

### 🚨 Fix balanced policy: "car → cả" hiện đúng "cả" sau Space

User feedback: gõ "car " (telex của "cả") → vkey hiển thị "car" thay vì "cả". Cùng class: "the→thể", "nuut→nứt".

**Root cause**: ở chế độ **Cân bằng** ([SpellDecisionEngine.swift:151](vkey/Input/SpellDecisionEngine.swift:151)), code chỉ check `extremelyCommonVietnameseWords` (~45 từ cherry-picked) → "cả", "thể", "nứt" không trong list → restore raw EN.

**Fix**: balanced mode giờ ưu tiên VN khi `transformedToken` chứa dấu Việt (`ả`/`ư`/`đ`/...). User gõ telex để tạo dấu → giữ VN luôn. Common-words list chỉ fallback cho các từ phẳng không dấu.

Cases sau fix (balanced policy):
- raw="car" / transformed="cả" → **keepVN** ✓ (trước: restoreEN "car").
- raw="the" / transformed="thể" → **keepVN** ✓.
- raw="text" / transformed="tẽt" → restoreEN "text" (giữ behaviour cũ vì "tẽt" KHÔNG phải VN word hợp lệ, dù có dấu).

Test mới: `testSpellDecisionBalancedKeepsVnDiacritic`.

### UI: Đưa "Gửi từ điển cho tác giả" ra tab Chính tả

User feedback: nút "Gửi cho tác giả" nằm trong Personal Dict Editor modal, ít người tìm thấy.

**Fix**:
- Đưa nút ra **tab Chính tả** ngay cạnh nút "Sửa từ điển cá nhân" (đổi tên từ "Quản lý từ điển cá nhân").
- Nút gate `disabled` khi tổng số từ < 50 (Allow + Keep + Deny).
- Bỏ block trùng lặp trong Personal Dict Editor.

### README: gộp ảnh vào 1 section duy nhất

User feedback: README có 2 sub-section "Thao tác nhanh & HUD" + "Các tab Cài đặt" → cồng kềnh. Gộp thành **"Hình ảnh minh hoạ"** chứa 5 ảnh (menubar + 4 tabs: Chung/Macro/Chính tả/Thống kê).

Xoá file ảnh không còn tham chiếu: `smart-switch-settings.png`.

### Files

- [vkey/Input/SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift:151) — balanced check `hasVietnameseDiacritic` trước.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — 2 nút HStack + helpers `sendDictToAuthor` cho SpellCheckView; xoá block trong PersonalDictionaryEditorView; rename "Quản lý" → "Sửa".
- [README.md](README.md) — 1 section "Hình ảnh minh hoạ" 5 ảnh.
- [images/smart-switch-settings.png](images/smart-switch-settings.png) — removed.

## [1.7.10] - 2026-05-20 — "Hotfix Telex Collision"

🚨 HOTFIX cho regression nghiêm trọng v1.7.9 — telex stems ngắn không transform được do EN dict expansion. Kèm UI EN count + Stats filter relax.

### 🚨 HOTFIX: Telex stems "cos/the/tie/hop" không transform được

**Root cause v1.7.9**: bump EN dict 126 → 9826 từ chứa các stem ngắn ("cos", "hop", "the", "tie"). [InputProcessor.swift:286](vkey/App/InputProcessor.swift:286) line "Instantaneous English word restoration" check `isEnglishWord(keysStr)` (full 9826) → lock raw → bỏ qua engine.push transform. User gõ "cos " ra "cos" thay vì "có".

**Fix**: phân biệt 2 lexicon use-case:
- **Instant restore** (typing-time, lock raw ngay): dùng list HẸP `EmbeddedLexiconData.englishWords` (126 từ hand-curated) + `userAllowWords`. Method mới `LexiconManager.isInstantRestoreEnglish(_)`.
- **Spell decision** (commit-time): vẫn dùng full list 9826 cho restore decision tinh tế qua SpellDecisionEngine.

Cases sau hotfix:
- "cos " → "có" ✓ (telex sắc, không bị lock).
- "hopwj " → "hợp" ✓.
- "tieengs " → "tiếng" ✓.
- "theer " → "thể" ✓.
- "thoongs " → "thống" ✓.
- "off " → "off" ✓ (embedded list, instant lock vẫn hoạt động).
- "class"/"staff" → giữ raw ✓ (impossible cluster path).

### UI: Settings hiện số từ Anh

User feedback: section "Từ điển từ GitHub" chỉ hiện "8.960 từ tiếng Việt", không thấy số từ EN dù v1.7.9 đã có 9826 từ EN.

**Fix**:
- [LexiconManager.swift](vkey/Lexicon/LexiconManager.swift) — thêm `englishWordsSnapshot()` mirror VN.
- [SettingView.swift](vkey/View/SettingView.swift) — thêm state `lexiconEnVersion/Entries` + 2 dòng UI riêng cho VN và EN.

### Stats: nới filter "Top từ ngoài tiếng Việt"

User feedback: section vẫn không hiện các từ raw / ký tự lạ. Filter cũ yêu cầu `isEnglishWord || userAllowWords` — raw "hopwj", "lol", "!@#" bị lọc.

**Fix** ([StatisticsView.swift:347](vkey/View/StatisticsView.swift:347) `isCleanTopWord(.english)`): bỏ lexicon check, chỉ giữ length≥2 + deny check. Section "Top từ ngoài tiếng Việt" giờ hiện đầy đủ các từ user thực sự gõ → dễ thấy candidate bổ sung Personal Dict.

### Tests

Thêm 2 test cases trong [vkeyTests.swift](vkeyTests/vkeyTests.swift):
- `testTelexEnglishCollisionHotfix` — verify cos/hopwj/tieengs/theer/thoongs/cof/cor transform đúng.
- `testEnglishInstantRestoreEmbeddedStillWorks` — verify off/class/staff vẫn instant-lock.

189/189 tests pass.

### Files

- [vkey/Lexicon/LexiconManager.swift](vkey/Lexicon/LexiconManager.swift) — `isInstantRestoreEnglish`, `englishWordsSnapshot`.
- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift:272,294) — 2 chỗ lock raw dùng `isInstantRestoreEnglish`.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — UI EN count.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift:347) — filter nới.

## [1.7.9] - 2026-05-20 — "Stats, EN Dict, Smart HUD"

4 fix sau v1.7.8: tab Thống kê restructure + filter nới + cụm 2-3 từ, EN dict v7→v9 (126→9826), HUD prediction pixel-precise caret.

### Tab Thống kê & Sao lưu restructure

- **Section reorder**: "Quyền riêng tư" chuyển từ TOP xuống ngay TRƯỚC mảng số liệu (sau Backup + Personal Dict sync). User feedback "đặt sát các mục thống kê".
- **Filter `isCleanTopWord` nới**: length 3 → **2** (giữ lexicon + deny check). Top từ tiếng Việt từ ~1 entry mở rộng nhiều từ phổ biến 2 ký tự (`để`, `là`, `có`, `mà`, ...).
- **Rename header EN**: "Top từ tiếng Anh / ký tự đặc biệt" → **"Top từ ngoài tiếng Việt (gợi ý từ điển cá nhân)"** — rõ mục đích.
- **Top cụm 2-3 từ tiếng Việt** (mới): dùng API có sẵn `aggregatedTopVietnamesePhrases` (1.6.1+). Threshold 3 cho UI personal.
- **Top cụm ngoài tiếng Việt** (mới): backend mới `enPhraseCounts2/3` + sliding window `recentEnQueue` + helper `recordEnPhraseTransition`. Track khi commit `.restoreRawEnglish` hoặc `.keepRaw`, reset khi xen VN/suggest/SmartSwitch.

### Backend phrase tracking

- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — thêm `WeekBucket.enPhraseCounts2/3`, `recentEnQueue`, `recordEnPhraseTransition`, API `aggregatedTopEnglishPhrases`. Backward-compat Codable. Trim cap 300 mỗi dict.
- [vkey/Stats/UsageStatistics.swift WeekBucketExport](vkey/Stats/UsageStatistics.swift) — thêm 2 fields với default empty trong init (backward-compat call sites cũ).

### EN dictionary GitHub v7 → v9 (126 → 9826 từ)

User feedback: "từ điển GitHub chỉ có tiếng Việt". Thật ra schema từ 1.5.0 đã có field `english` nhưng pipeline chỉ output 126 từ embedded.

- [Tools/build_lexicon.py](Tools/build_lexicon.py) — bump `--top-english` default `2000` → `10000`.
- Re-generate `lexicon-update.json`: dùng `wordfreq.top_n_list('en', 10000)`, filter alphabetic ≥2 chars, union với 126 embedded → **9826 EN words**. Version 8 → 9.
- File size 257.6 KB (under 1 MB safe ceiling). Parse < 1ms. Set lookup O(1).
- App 1.6.2+ auto-fetch trong 24h hoặc qua nút "Cập nhật từ điển ngay". Không cần update app binary.

### HUD prediction: pixel-precise caret

User feedback: "vị trí HUD không linh hoạt theo con trỏ, hay che nội dung".

Root cause: [PredictionHUDWindow.focusedElementCaretRect](vkey/Platform/PredictionHUDWindow.swift:109) chỉ dùng `kAXPositionAttribute + kAXSizeAttribute` → trả bounds toàn focused element (vd TextEdit/VS Code editor 800×600), KHÔNG phải pixel caret. Multi-line editor → HUD đặt top editor che dòng đang gõ.

**Fix**: dùng AX parametric API `kAXSelectedTextRangeAttribute` + `kAXBoundsForRangeParameterizedAttribute` để lấy bounds pixel của caret range. Fallback element bounds nếu app không support.

**Bổ sung**:
- Flip-below logic: nếu HUD top edge vượt screen.maxY → đặt HUD dưới caret line (top of screen edge case).
- Multi-display: tìm `NSScreen` chứa caret thay vì luôn dùng `NSScreen.main`.

### Files

- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — reorder section, relax filter, rename EN, thêm 2 phrase sections.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — EN phrase tracking + API + WeekBucketExport.
- [Tools/build_lexicon.py](Tools/build_lexicon.py) — bump default top-english.
- [lexicon-update.json](lexicon-update.json) + [lexicon/lexicon-update.json](lexicon/lexicon-update.json) — version 9, EN 9826 từ.
- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift) — parametric AX + flip + multi-display.

## [1.7.8] - 2026-05-20 — "Right Names, Right Height"

2 chỉnh sau v1.7.7: thu chiều cao Settings 40% + restore tab labels gốc với font compact.

### Settings window chiều cao 1080 → 648 (-40%)

User feedback v1.7.7 "cửa sổ quá dài". Thu `.defaultSize` từ `(432, 1080)` → `(432, 648)`. Drag resize qua góc/cạnh vẫn hoạt động tự do qua `.windowResizability(.contentMinSize)`.

Bump autosave name `v177` → `v178` + cleanup orphan `v177` key trong NSUserDefaults → user upgrade nhận default 432×648 fresh.

### Tab labels gốc + font compact

User feedback v1.7.7: tab labels rút gọn (`"Smart Switch"` → `"Smart"`, `"Thống kê & Sao lưu"` → `"Sao lưu"`) làm mất ngữ nghĩa. Restore labels gốc.

Bù lại bằng `.font(.system(size: 10))` áp vào mỗi Label tabItem → font tab bar nhỏ hơn ~10-15%, fit width compact dù labels dài hơn.

### Files

- [vkey/vkeyApp.swift](vkey/vkeyApp.swift) — restore 2 labels, font cho 5 tabItem, defaultSize height 648.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift:284) — autosave v178 + cleanup v177.

## [1.7.7] - 2026-05-20 — "Compact Window & Right Imports"

4 fix sau v1.7.6: cửa sổ Settings 432×1080 compact + drag tự do, Import semantics đúng theo user intent, fix bug "d→đ", Prediction HUD lên trên + Tab smart-detect.

### Settings window: 432×1080 default + tab labels rút gọn

v1.7.6 thêm `.windowResizability(.contentMinSize)` nhưng vẫn quá to vì tab bar 5 labels dài (`"Smart Switch"`, `"Thống kê & Sao lưu"`) buộc content min ≥600px. Thiếu `.defaultSize` cũng làm window mở ở content's ideal size.

**Fix**: 
- Thêm `.defaultSize(width: 432, height: 1080)` modifier ([vkeyApp.swift](vkey/vkeyApp.swift)).
- Rút gọn tab labels: `"Smart Switch"` → `"Smart"`, `"Thống kê & Sao lưu"` → `"Sao lưu"`.
- 5 view files: minWidth/Height `320/480` → `200/720` (cho phép drag thu nhỏ width thêm).
- Bump autosave name `v176` → `v177` + cleanup orphan keys → user nâng cấp mở fresh ở 432×1080.

### Import semantics đúng theo user intent

User feedback: "Ghi đè" trước đây không thật sự xoá data default; "Kết hợp" với data trùng nhau dùng existing thay vì imported.

**Fix**:
- **Ghi đè (`replaceLists: true`)**:
  - **Macros**: clear sạch defaults, set bằng imported (trước đây append vào existing → duplicate). [UserDataMigration.swift:449](vkey/App/UserDataMigration.swift:449).
  - **Stats**: gọi `UsageStatistics.shared.clearAll()` trước `restoreFromBackup` để xoá toàn bộ tuần hiện có.
- **Kết hợp (`replaceLists: false`) — file thắng khi trùng**:
  - **Macros**: imported `to` overrides existing same `from`.
  - **mergeStringDict** (perAppOverride): imported value thắng khi trùng key.
  - **appSmartSwitchConfigs**: imported config thắng khi trùng bundle id.
  - **userBigrams/userTrigrams**: imported count overrides khi trùng (prev, next).
  - Lists (allow/keep/deny) union không cần winner (cùng string không có conflict).
- **Dialog text**: `"Gộp thêm (file thắng nếu trùng)"` vs `"Ghi đè toàn bộ (xoá data hiện tại)"`.

### Fix bug "d → đ" (gõ d hay hiện đ)

User: "gõ dùng nhưng hiện đùng, xoá nhiều lần mới gõ đúng d được".

Root cause: `tryLateDToggle` ([TiengVietState.swift](vkey/Engine/TiengVietState.swift)) trigger quá rộng — chỉ check `chuKhongDau.count >= 3 && first == 'd' && !gachD && trigger char là 'd'`. Không validate syllable structure → khi user gõ thêm 'd' trong/cuối từ chưa hoàn chỉnh, gạch D toggle on sai.

**Fix**: thêm 2 guards — chỉ trigger khi `conLai.isEmpty` (không còn leftover chars) AND `!nguyenAm.isEmpty` (có vowel). Ngăn gạch D toggle sai trong giữa từ chưa hoàn chỉnh, vẫn giữ behavior đúng cho cases như `"dinjhd"` → `"định"`.

### Prediction HUD lên trên dòng + Tab smart-detect

User feedback: HUD dưới dòng che cursor; Tab cần gõ Space trước rồi mới Tab, không tiện.

**Fix**:
- **HUD position** ([PredictionHUDWindow.swift:80](vkey/Platform/PredictionHUDWindow.swift:80)): đổi từ `caret.maxY` (dưới) → `caret.minY` (trên). HUD giờ hiển thị ngay trên dòng đang gõ.
- **Tab smart-detect** ([InputProcessor.swift:582](vkey/App/InputProcessor.swift:582)):
  - **Buffer sạch** (sau commit qua Space): Tab chèn `" prediction"` (space + word).
  - **Buffer có từ chưa commit**: Tab commit từ (emit space qua spell decision) rồi chèn prediction.
  - User có thể gõ "viet" + Tab → "việt Nam" (commit + insert prediction trong 1 phím).

### Files

- [vkey/vkeyApp.swift](vkey/vkeyApp.swift) — `.defaultSize` + tab labels rút gọn.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift:261) — autosave name v177.
- 5 view files — frame minWidth/Height 200/720.
- [vkey/App/UserDataMigration.swift](vkey/App/UserDataMigration.swift) — macros logic, dict/configs imported-wins, stats clearAll on replace.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift:407) — dialog text mới.
- [vkey/Engine/TiengVietState.swift](vkey/Engine/TiengVietState.swift:218) — `tryLateDToggle` guards.
- [vkey/Platform/PredictionHUDWindow.swift](vkey/Platform/PredictionHUDWindow.swift:80) — HUD lên trên.
- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift:582) — Tab smart-detect.

## [1.7.6] - 2026-05-20 — "Backup Complete & Resize Done"

2 fix lớn sau v1.7.5: cửa sổ Settings auto-fit + resize tự do; Export/Import lossless toàn bộ user state (9 fields mới + stats raw).

### 🚨 Settings window: auto-fit + user-resizable (đúng cách qua SwiftUI)

Root cause v1.7.4/1.7.5 không có hiệu lực: SwiftUI Settings scene mặc định dùng `.windowResizability(.automatic)` → trong macOS 13+ enforces **non-resizable** + sized-to-content. AppKit workaround (`win.styleMask.insert(.resizable)` + `setContentSize`) không override được SwiftUI scene policy.

**Fix đúng cách** ([vkeyApp.swift](vkey/vkeyApp.swift)):

```swift
Settings { TabView { ... } }
  .windowResizability(.contentMinSize)
```

- Window opens at content's ideal size (auto-fit theo tab bar + form content).
- User kéo góc/cạnh để resize xuống tới `minWidth/minHeight` của view content.
- AppDelegate `windowDidBecomeKey` đơn giản hoá: chỉ gắn `setFrameAutosaveName("VkeySettingsWindow.v176")` + cleanup orphan keys cũ (v174/v175/base name).
- 5 view files: đổi `.frame(minWidth: 160, minHeight: 720)` → `.frame(minWidth: 320, minHeight: 480)` — giới hạn dưới thực tế cho form content.

### 🚨 Export/Import: lossless full backup

**Bug A — Export thiếu 9 fields**: trước đây `UserDataExport` thiếu `wordPredictionEnabled`, `appSmartSwitchConfigs` (per-app 3-state Smart Switch — critical từ 1.7.0!), `translationHUDEnabled`, `translationHUDDurationMs`, `programmingMode`, `userBigrams`, `userTrigrams`, `statisticsEnabled`, `autoBackupOnUpgrade`. Backup file không có 9 fields này → import xong user mất config.

**Fix**: bổ sung 9 fields vào struct (optional cho backward-compat), populate trong `currentExport()`, apply trong `importExport()`.

**Bug B — Stats summary lossy**: `allSummariesForExport()` trả `[UsageSummary]` chỉ chứa aggregate counters + top 10% words. Mất raw frequency tables (`vnWordCounts`, `enWordCounts`), streaks (`vnKeepStreak`, `enRestoreStreak`), phrase counters (`vnPhraseCounts2/3`), per-app language tracking (`appLanguageVnCounts/EnCounts/Days`).

**Fix**: thêm `public struct WeekBucketExport: Codable` full mirror của `WeekBucket`. `UserDataExport.statistics` đổi từ `[UsageSummary]?` → `[WeekBucketExport]?`. Bump `currentSchemaVersion` 1 → 2. Decode backward-compat: thử v2 trước, fallback v1 (bridge → WeekBucketExport với raw maps rỗng).

**Bug C — Stats không restore**: `importExport()` trước đây không đọc `export.statistics` → tab Thống kê hiện 0 sau import.

**Fix**: thêm `UsageStatistics.shared.restoreFromBackup(_:)` — match current weekId → load thành `counters`; tuần khác → ghi file `<weekId>.json`. Gọi cuối `importExport()`.

**Bug D — Merge UX confusing**: dialog button "Gộp"/"Ghi đè" không rõ. User thấy data cũ vẫn còn → hiểu nhầm bug.

**Fix**: đổi text dialog:
- `"Gộp thêm (giữ data hiện tại)"` — union, thêm vào.
- `"Ghi đè toàn bộ (xoá data hiện tại)"` — replace.
- Mô tả rõ "Cả 2 chế độ đều khôi phục thống kê".

### Files

- [vkey/vkeyApp.swift](vkey/vkeyApp.swift) — thêm `.windowResizability(.contentMinSize)`.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift:261) — đơn giản hoá windowDidBecomeKey.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift), [StatisticsView.swift](vkey/View/StatisticsView.swift), [SmartSwitchView.swift](vkey/View/SmartSwitchView.swift), [MacroView.swift](vkey/View/MacroView.swift) — minWidth/Height 320/480.
- [vkey/App/UserDataMigration.swift](vkey/App/UserDataMigration.swift) — 9 fields + restore stats + Codable backward-compat.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — `WeekBucketExport` + `allWeekBucketsForExport` + `restoreFromBackup`.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — dialog text rõ semantics.

## [1.7.5] - 2026-05-20 — "Tone Cancel Fix"

2 fix dứt điểm hậu 1.7.4: tone-cancel "ả + r + m" + thu hẹp Settings.

### 🚨 Fix tone-cancel bị English doubled-tone preservation chặn (arrm)

User feedback v1.7.4: "tôi gõ ả rồi gõ thêm r để bỏ dấu hỏi và gõ m thì hiện thành arrm phải gõ ảm rồi ấn esc thì mới ra arm".

**Root cause**: `WordBuffer.push` có 2 nhánh "Doubled Tone Mark Preservation" (line 272) và "Instantaneous English word restoration" (line 286). Khi user gõ A → R (Ả) → R (cancel hỏi) → M:
- Buffer keys = [a, r, r]. keysStr = "arr". `isEnglishWord("arr") = true` (lexicon có "arr" như từ tiếng Anh).
- Nhánh 272 kick in: lock raw "arr" + stopProcessing.
- Gõ M → nhánh 221 (stopProcessing + !wasOnlyEnglishRestored) append raw → "arrm".

**Fix**: detect tone-cancel intent. Nếu state đã có tone applied AND char là tone key (s/f/r/x/j) → user đang xoá dấu → KHÔNG kích nhánh English preservation. Engine.push tiếp theo sẽ toggle tone off (state.withTone same-tone → .bang).

**Trade-off**: từ tiếng Anh hiếm như "pass"/"arr"/"ass" gõ tuần tự bị mất 1 ký tự (→ "pas"/"ar"/"as"). "off"/"class"/"staff" không ảnh hưởng (đi qua nhánh khác: English prefix "of" lock sớm hoặc impossible cluster "cl"/"st").

**Cũng update `SpellDecisionEngine.isLikelyEnglishAcronym`**: thêm `rr/ss/ff/xx/jj` vào danh sách double patterns không-acronym → "ARRM"/"OFFM" không bị restore raw sai khi commit.

[vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift:271) — `isPossibleToneCancel` guard tại 2 chỗ.
[vkey/Input/SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift) — mở rộng `vnDoublePatterns`.

### Settings window: thu hẹp default 180→160 + cleanup autosave cũ

- `minWidth` 5 view files + AppDelegate: 180 → **160** (chỉ đủ chữ theo bề ngang).
- Bump autosave name `VkeySettingsWindow.v174` → `VkeySettingsWindow.v175` để user upgrade từ 1.7.4 mở cửa sổ ở default 160×720 lần đầu.
- Cleanup các key orphan trong `NSUserDefaults`: `"NSWindow Frame VkeySettingsWindow"`, `"NSWindow Frame VkeySettingsWindow.v174"`.
- Vẫn `.resizable` styleMask + `setFrameAutosaveName` → user kéo góc/cạnh tuỳ chỉnh, kích thước mới được nhớ.

[vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift:257) — `windowDidBecomeKey`.

## [1.7.4] - 2026-05-20 — "Clean Stats"

4 fix + 1 redesign nhỏ tiếp cải tiến tab Thống kê và cửa sổ Settings, kèm fix bug gõ ARM/USA/API.

### Fix bug gõ initialism English (ARM → Ảm)

User gõ "ARM" (English initialism) bị vkey áp Telex tone hỏi từ "R" giữa A-M → output "Ảm" thay vì giữ "ARM". Tương tự "USA" → "Úa", "API" → "Apí", "OK", "AI", ...

**Fix tại commit time** (SpellDecisionEngine.evaluate): detect English acronym pattern → restoreRawEnglish.

Heuristic acronym:
- rawInput length 2-5 chars
- toàn ASCII uppercase letter
- KHÔNG chứa double-letter Telex signal (`dd/aa/oo/ee/uu/ww/uw/ow/aw`)
- KHÔNG kết bằng tone key (`s/f/r/x/j`)

Cách này preserve các trường hợp VN typing all-caps hợp lệ (VIEEJT → VIỆT do "ee" double, DDOR → Đỏ do "dd" double + "r" cuối là tone, VIETJ → VIỆT do "j" cuối là tone).

[vkey/Input/SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift) — `isLikelyEnglishAcronym` helper + sớm restore trong `evaluate()`.

### Fix biên dịch test target (vkeyTests)

Sau khi v1.7.0 gỡ `dictionaryUpdateChannel` / `dictionaryGitHubUpdateEnabled` (chuyển sang hybrid auto-update không có toggle), test target còn tham chiếu cũ → fail biên dịch ngay khi mở project. Sửa 6 chỗ trong [vkeyTests.swift](vkeyTests/vkeyTests.swift):

- Xoá `Defaults.reset(...)` cho 2 key đã gỡ (2 setUp method).
- Đổi `manager.reload(channel: ...)` → `manager.reload()` (3 test method) — `LexiconManager.reload(channel:)` đã được hợp nhất.
- Cập nhật `UserDataExport(...)` constructor: bỏ 2 field cũ, thêm 5 field mới (`macroEnabled`, `macrosSeeded`, `defaultMacrosVersion`, `appTheme`, `autoPersonalDictFeedback`) — match signature 1.5.5+.

### Fix SpellDecisionEngine: dấu Việt + raw EN

v1.7.1 thêm defense "nếu transformed có dấu Việt → luôn keep VN" nhưng quá rộng: case `text` (telex → `tẽt`) bị giữ là `tẽt` thay vì restore về `text`. Logic mới:

- Khi transformed có dấu Việt:
  - Là VN word hợp lệ → keep VN
  - Raw là EN word hợp lệ → restore raw
  - Không phải cả hai (từ mới/đặc biệt) → keep VN (defense ban đầu vẫn còn)

[vkey/Input/SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift) — guard tại line 87-95.

### Settings window: reset frame autosave

User upgrade từ v1.7.2 (270px) còn frame saved cũ → không hưởng default mới 180×720 của v1.7.3. Bump autosave name từ `"VkeySettingsWindow"` → `"VkeySettingsWindow.v174"` để mọi user (mới + nâng cấp) đều mở cửa sổ ở 180×720 lần đầu. Vẫn `.resizable` → user kéo góc/cạnh tuỳ chỉnh, frame mới được nhớ qua các lần mở.

[vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift:257) — windowDidBecomeKey.

### Tab Thống kê: top từ 10% + lọc lỗi gõ + Xem chi tiết

Top từ tiếng Việt / tiếng Anh trong tab Thống kê được redesign:

- **Loại commit qua đường recovery**: thêm `needsRecovery` param vào `UsageStatistics.recordCommit` — commit bị parser flag là lỗi gõ (telex/VNI không transform được) KHÔNG bơm vào `vnWordCounts/enWordCounts/vnKeepStreak/enRestoreStreak`. Aggregate stats (wordsTotal/category) vẫn cộng.
- **Top = 10% theo count**: `WeekBucket.summary` đổi cap cứng 20 từ → top 10% (không cap). Min 1 entry khi có data.
- **Display filter**: bỏ từ <3 ký tự, từ trong deny list, từ không có trong bất kỳ lexicon nào (VN/EN/Keep + user allow/keep). Stats raw vẫn lưu đủ, chỉ filter ở display layer (suggestion compute vẫn dùng streak để propose từ mới).
- **UI**: section top mặc định hiện 10; nếu filtered > 10 → nút "Xem chi tiết (N)" mở sheet liệt kê đầy đủ, cho xoá từng từ.

Files:
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — `recordCommit`, `applyCommit`, `WeekBucket.summary` (thêm `topPercent`).
- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift:755) — forward `needsRecovery` xuống stats.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — `isCleanTopWord` filter, `TopWordsDetailSheet`, button "Xem chi tiết".

## [1.7.3] - 2026-05-20 — "Minimalist"

3 cải tiến UI nhỏ tiếp tục stream "compact UI" của v1.7.x.

### Cửa sổ Cài đặt compact tối đa (-33%)

- `minWidth`: 270 → **180** (còn 2/3 so với v1.7.2).
- 5 view files + AppDelegate minSize cập nhật.
- Form `.grouped` style tự co content fit 180px; text label + monospace bundle ID đã có `lineLimit(1) + truncationMode(.middle)` từ v1.7.1.
- Vẫn resize lên rộng tuỳ ý qua drag corner; `setFrameAutosaveName` nhớ kích thước.

### Tab Chính tả: bỏ Dividers thừa

User feedback (screenshot v1.7.2): có nhiều khoảng trắng dư giữa các sub-toggle trong Section "Cấu hình kiểm tra chính tả".

**Root cause**: 3 `Divider()` explicit tôi thêm để tách 4 sub-section (master / suggestion / personal dict / auto-feedback). Form `.grouped` đã có row separator tự nhiên + Divider() thêm padding ~30px mỗi cái.

**Fix**: bỏ 3 Divider trong Section "Cấu hình kiểm tra chính tả" của SpellCheckView. Tiết kiệm ~90px chiều dọc, sub-toggle nối liền nhau như native macOS Settings.

### Smart Switch icon đổi cpu → 🤖

User feedback: icon "Tự động học" hiện là `cpu` (chip purple) — không trực quan với ý "vkey tự quyết". Đổi thành emoji 🤖 robot.

`AppSmartSwitchSource.emojiIcon` (mới) thay/bổ sung `iconSymbol`:
- `.user` → "👤"
- `.autoLearn` → "🤖"

Call sites updated (4 chỗ):
- Legend "Tự động học" ở header tab Smart Switch
- `AppConfigRow.stateIcon` khi source=.autoLearn → Text("🤖") thay Image(systemName: "cpu")
- `AppConfigPicker` row "Để vkey tự quyết" → Text("🤖")
- `SmartSwitchAutoLearnSheet` row current config indicator

### Files

- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — bỏ 3 Divider trong SpellCheckView; frame 180×720.
- [vkey/View/SmartSwitchView.swift](vkey/View/SmartSwitchView.swift) — đổi cpu → 🤖 (3 chỗ); frame 180×720.
- [vkey/View/SmartSwitchSuggestionSheet.swift](vkey/View/SmartSwitchSuggestionSheet.swift) — current config icon dispatch user/autoLearn.
- [vkey/View/MacroView.swift](vkey/View/MacroView.swift), [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — frame 180×720.
- [vkey/App/Setting.swift](vkey/App/Setting.swift) — thêm `AppSmartSwitchSource.emojiIcon`.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — minSize 180×720.

### Verify

- Mở Settings → window default 180px width đủ rộng cho content.
- Tab Chính tả → 4 sub-toggle Section "Cấu hình kiểm tra chính tả" nối liền nhau, không có khoảng trống thừa.
- Smart Switch → row có app source=autoLearn hiển thị 🤖 thay vì chip cpu. Picker option "Để vkey tự quyết" cũng dùng 🤖.

## [1.7.2] - 2026-05-20 — "Compact & Connect"

5 cải tiến UI và workflow — compact hơn, Smart Switch UX rõ ràng hơn, kết nối với tác giả qua mail.

### Cửa sổ Cài đặt compact (-25% width)

- `minWidth`: 360 → **270** (5 view files + AppDelegate).
- `minHeight`: 720 (không đổi).
- Stats "Tuần này" header tự wrap 2 dòng khi cần (`.lineLimit(2) + .fixedSize(horizontal: false, vertical: true)`).
- Vẫn resize lên rộng tuỳ ý.

### Tab Chính tả trim khoảng trắng

- Bỏ Text mô tả dài 2-3 dòng (mỗi sub-toggle).
- Bỏ HStack `Spacer() + Button + Spacer()` → `Button.frame(maxWidth: .infinity, alignment: .center)`.
- Section "Cấu hình kiểm tra chính tả" gọn hơn ~80px chiều dọc.

### Smart Switch — Merge state button (mới)

Trước (v1.7.1): mỗi row có 4 elements bên phải — state badge text + source icon + "..." button + 🗑 trash.

Sau (v1.7.2): chỉ 2 buttons — state-icon button (merged) + 🗑 trash.

State icon hiển thị:
- Source = `.user` → icon theo state: 🇻🇳 (vn-flag) / 🇺🇸 (us-flag) / 🚫 (nosign red).
- Source = `.autoLearn` → 🤖 (SF Symbol `cpu` purple) — ưu tiên hiển thị nguồn auto-learn.
- Tooltip: "🤖 Vkey tự quyết — đang là: [state]" hoặc "[state] (do bạn đặt)".

Click button → popover 4 lựa chọn:
1. 🇻🇳 Tiếng Việt → source=.user, state=.vietnameseMode
2. 🇺🇸 Tiếng Anh → source=.user, state=.englishMode
3. 🚫 Không sử dụng vkey → source=.user, state=.disabled
4. 🤖 Để vkey tự quyết → **xoá entry** khỏi `configs` → auto-learn ngày kế tiếp re-evaluate.

Checkmark hiển thị bên cạnh option đang selected (match cả state + source).

### Auto-learn phản hồi nhanh hơn

| | Trước (v1.7.0-1.7.1) | Sau (v1.7.2) |
|--|--|--|
| Days dataset | ≥5 ngày | **≥1 ngày** |
| Avg commit/day | ≥5 | ≥5 (giữ) |
| Ratio language | ≥75% | ≥75% (giữ) |
| Check frequency | 1 lần/tuần | **1 lần/ngày** |
| Gate key | `lastSmartSwitchAutoLearnWeek` (deprecated) | `lastSmartSwitchAutoLearnDate` (mới) |

User gõ đủ ratio + commit trong 1 ngày → ngày kế tiếp launch sẽ thấy app được auto-set state.

### Gửi từ điển cá nhân cho tác giả (mới)

[PersonalDictionaryEditorView in SettingView.swift:551+](vkey/View/SettingView.swift):

- Section mới ở cuối editor (trước Đóng button):
  - Title: "Gửi từ điển cho tác giả vkey"
  - Text: "Yêu cầu ≥50 từ trong tổng 3 danh sách (Allow/Keep/Deny). Bạn có X từ."
  - Text: "Khi gửi, vkey mở app mail mặc định. Tác giả rà soát và bổ sung vào từ điển chung nếu phù hợp."
  - Button: "Gửi cho tuanlong.sav@gmail.com" (disabled nếu < 50 từ, show "Cần thêm N từ").
- `sendDictToAuthor()` action:
  - Compose mailto URL với:
    - `to`: `tuanlong.sav@gmail.com`
    - `subject`: `[vkey] Đề xuất bổ sung từ điển cá nhân`
    - `body`: 3 lists Allow/Keep/Deny + version info
  - `NSWorkspace.shared.open(url)` → mở app Mail default.
- Sheet frame: 400×420 → **400×520** để fit content mới.

### Files

- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — SpellCheckView trim + PersonalDictionaryEditorView send button; frame 270×720.
- [vkey/View/SmartSwitchView.swift](vkey/View/SmartSwitchView.swift) — AppConfigRow merge button (state icon); AppConfigPicker 4 options; frame 270×720.
- [vkey/View/MacroView.swift](vkey/View/MacroView.swift), [StatisticsView.swift](vkey/View/StatisticsView.swift) — frame 270×720; Stats header wrap.
- [vkey/App/Setting.swift](vkey/App/Setting.swift) — thêm `lastSmartSwitchAutoLearnDate` key.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — `runSmartSwitchAutoLearnIfDue` đổi daily gate; minSize 270×720.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — `computeSmartSwitchAutoLearn` threshold `days >= 1`.

### Verify

- Mở Settings → window default 270px width, đủ rộng cho content.
- Tab Chính tả → 4 Section gọn, không có khoảng trắng dư thừa.
- Smart Switch → mỗi row có icon state (flag/🚫/🤖) clickable → popover 4 options.
- Click 🤖 trong picker → entry xoá khỏi list (auto-learn sẽ re-evaluate ngày sau).
- Gõ ≥5 commit trong 1 ngày trong 1 app với ratio ≥75% → ngày kế tiếp launch app → auto-learn set state.
- Personal Dict Editor → nếu ≥50 từ → button "Gửi" active; click → mở Mail compose.

## [1.7.1] - 2026-05-20 — "Typing Fix & Polish"

Hotfix CRITICAL bug gõ + 3 cải tiến UI.

### 🚨 CRITICAL: Sửa bug gõ `ý` hiện `ys`, `ô` hiện `oo`, `ở` hiện `owr`

**Triệu chứng**: từ tiếng Việt 1 ký tự (`ý`, `ô`, `ở`, `à`, `á`, `ã`...) bị "khôi phục" về raw English keys (Telex) khi nhấn Space.

**Root cause**: lexicon v7 (8,894 syllables) bị `Tools/audit_lexicon.py` xoá hết **66 single-char Vietnamese diacritics** ở phase v1.6.1 audit. Khi user gõ `ys` (Telex) → Telex transform → `ý` → user nhấn Space → SpellDecisionEngine evaluate:
- `isVietnameseWord("ý")` → false (lexicon thiếu)
- `englishAutoRestoreEnabled = true` → fallback `.restoreRawEnglish`
- vkey gửi backspace + raw "ys" → user thấy "ys" thay vì "ý"

**Fix 2 lớp (defense-in-depth)**:

1. **Data fix — lexicon v7 → v8**: cập nhật [`Tools/audit_lexicon.py`](Tools/audit_lexicon.py) whitelist 66 single-char VN syllables (`à á ả ã ạ ă ắ ằ ẳ ẵ ặ â ấ ầ ẩ ẫ ậ è é ẻ ẽ ẹ ê ế ề ể ễ ệ ì í ỉ ĩ ị ò ó ỏ õ ọ ô ố ồ ổ ỗ ộ ơ ớ ờ ở ỡ ợ ù ú ủ ũ ụ ư ứ ừ ử ữ ự ỳ ý ỷ ỹ ỵ`) — vượt qua rule `len(word) == 1` drop. Cũng inject `idempotent` để đảm bảo present trong output. Re-run audit → `lexicon-update.json` v7 → v8 = **8,960 syllables**. Commit lên GitHub, app fetch tự động trong 24h.

2. **Engine guard — defensive** ([SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift)): thêm `hasVietnameseDiacritic(_:)` helper + check TRƯỚC nhánh restoreRawEnglish — nếu transformed token có chứa ký tự đặc trưng VN (66 dấu thanh + đ), KHÔNG BAO GIỜ restore. User đã chủ động gõ Telex để tạo dấu → ý định rõ ràng là VN. Bảo vệ trường hợp lexicon thiếu single-char lần sau.

### Tab Chính tả tinh gọn hơn (4 Section thay vì 5)

- Gộp "Gợi ý sửa lỗi chính tả" + "Tự động sửa khi tin cậy cao" vào CÙNG Section "Cấu hình kiểm tra chính tả" (trước đây tách riêng).
- Cấu trúc Section "Cấu hình kiểm tra chính tả" hiện tại:
  1. Toggle "Kiểm tra chính tả"
  2. Toggle "Gợi ý sửa lỗi chính tả" + sub-toggle "Tự động sửa khi tin cậy cao" (mới merge)
  3. Toggle "Sử dụng từ điển cá nhân" + button "Quản lý"
  4. Toggle "Tự động compute đề xuất hàng tuần" + button "Xem đề xuất pending"

### Cửa sổ Cài đặt — giảm bề ngang 25%

- `minWidth`: 480 → **360** (-25%). Compact hơn, fit screen nhỏ.
- `minHeight`: 720 (không đổi).
- Content adjustments cho 360px:
  - AppConfigRow trong SmartSwitch: bundle ID monospaced `lineLimit(1)` + `truncationMode(.middle)` — không overflow.
  - Vẫn resize được lên rộng tuỳ ý (drag corner/edge).
- AppDelegate `windowDidBecomeKey` minSize cập nhật 360×720.

### Smart Switch UX cải thiện

**(i) Inline trash button trên mỗi row** (thay nút "Xoá" bottom):
- Mỗi `AppConfigRow` giờ có 🗑 button (red) bên phải, sau "Sửa" button.
- Click trash → xoá ngay khỏi `appSmartSwitchConfigs` (không confirm — có thể re-add nếu lỡ).
- Bỏ button "Xoá" bottom + selection state cũ (không cần nữa).

**(ii) Nút "Chọn từ ứng dụng đang chạy"** (mới, [SmartSwitchRunningAppsSheet.swift](vkey/View/SmartSwitchRunningAppsSheet.swift)):
- Sheet hiển thị list `NSWorkspace.shared.runningApplications` filter `activationPolicy == .regular` (loại helpers/daemons), loại vkey itself.
- Mỗi row: app icon + tên + bundle ID + state badge nếu đã cấu hình (✓ green / + accent).
- Search field filter theo tên hoặc bundle ID.
- Click row → thêm vào configs với state mặc định `.englishMode` + source `.user`.
- Đã cấu hình → row disabled, hiển thị state hiện tại.
- 420×520 sheet, sorted theo tên app.

### Files

- [Tools/audit_lexicon.py](Tools/audit_lexicon.py) — whitelist 66 single-char VN diacritics + Tier C loanwords + inject if missing.
- [lexicon-update.json](lexicon-update.json) — version 7 → 8, 8,894 → 8,960 syllables.
- [vkey/Input/SpellDecisionEngine.swift](vkey/Input/SpellDecisionEngine.swift) — `hasVietnameseDiacritic` helper + guard.
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — merge Section "Gợi ý" vào "Cấu hình kiểm tra"; frame 480→360.
- [vkey/View/SmartSwitchView.swift](vkey/View/SmartSwitchView.swift) — onDelete callback + inline trash; bỏ bottom Xoá; thêm nút "Chọn từ app đang chạy"; frame 480→360.
- [vkey/View/SmartSwitchRunningAppsSheet.swift](vkey/View/SmartSwitchRunningAppsSheet.swift) (mới) — sheet picker từ running apps.
- [vkey/View/MacroView.swift](vkey/View/MacroView.swift), [StatisticsView.swift](vkey/View/StatisticsView.swift) — frame 480→360.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — windowDidBecomeKey minSize 360×720.

### Verify

Test typing single-char syllables (Telex):
- `ys → ý` ✓ (không thành ys)
- `oo → ô` ✓ (không thành oo)
- `owr → ở` ✓ (không thành owr)
- `ax → ã` ✓, `a` → à` ✓, `aa → á` ✓
- Tất cả 66 single-char hợp lệ giờ kept correctly

Smart Switch:
- 🗑 trên row → xoá ngay
- "Chọn từ app đang chạy" → list Slack, Safari, Notes...; click → thêm
- vkey itself không xuất hiện trong list

## [1.7.0] - 2026-05-20 — "Smart Context"

Bản nâng cấp lớn về Smart Switch + nhiều cải tiến UI. 4 thay đổi chính:

### 1. Smart Switch 3-state per-app (major refactor)

**Trước (v1.5.x – v1.6.x)**: `smartSwitchApps: [String]` — list bundle IDs "luôn tắt VN khi mở app". Không phân biệt user set vs default.

**Sau (v1.7.0)**: `appSmartSwitchConfigs: [String: AppSmartSwitchConfig]` — mỗi app có:
- **state**: 3 lựa chọn — `vietnameseMode` 🇻🇳 / `englishMode` 🇺🇸 / `disabled` ⛔
- **source**: `user` 👤 (thủ công) hoặc `autoLearn` 🤖 (vkey tự học)
- **lastModified**: timestamp track auto-learn updates

**Auto-learn**: vkey theo dõi ngôn ngữ user gõ trong từng app qua Stats (per-app VN vs EN counts + dataset days spread). Threshold:
- ≥5 ngày dataset trong tuần
- ≥5 commit/ngày trung bình (~35 commits/tuần)
- ratio language ≥75% (Tiếng Việt) hoặc ≤25% (Tiếng Anh)
- Chạy 1 lần/tuần khi launch (gated qua `Defaults[.lastSmartSwitchAutoLearnWeek]`)

**User override LUÔN thắng**: app có `source=.user` không bị auto-learn override. User reset về auto-learn qua nút "Để vkey tự học" trong popover.

**Auto-migrate**: user upgrade từ 1.6.x — `smartSwitchApps` cũ → `englishMode + source=.user` cho mỗi entry. Chạy 1 lần khi `appSmartSwitchConfigs` đang rỗng. Idempotent.

### 2. UI Smart Switch redesign

- App row mới: icon NSWorkspace + tên hiển thị + bundle ID + badge state (3 colors) + source icon 👤/🤖 + popup picker "Sửa".
- Popup picker: 3 lựa chọn state + (nếu source=user) nút "Để vkey tự học (auto-learn)" reset entry.
- Sheet "Tự học từ Thống kê" (mới): preview gợi ý từ auto-learn engine, áp dụng hàng loạt, skip user-set entries (🔒).
- Legend ở đầu list: giải thích 👤 vs 🤖.

### 3. Tab Chính tả restructure

- Gộp `spellCheckInSentenceEnabled` vào `spellCheckEnabled` (1 toggle thay 2). Defaults key giữ trong codebase (true logic-wise).
- Merge 3 Section vào 1: "Từ điển cá nhân" + "Học hành vi từ Thống kê" + "Cấu hình Kiểm tra" → đổi tên thành **"Cấu hình kiểm tra chính tả"**.
- Còn 5 Section thay vì 7 — giảm cognitive load.

### 4. Cửa sổ Cài đặt — kích thước mới

- `minWidth`: 540 → 480 (bỏ thừa 2 bên cho tab content compact).
- `minHeight`: 640 → 720 (hiển thị hết content nhiều tab không scroll; SpellCheck + Statistics vẫn có scroll khi cần).
- Default 5 tab đồng nhất. Drag góc/cạnh vẫn resize được; kích thước được nhớ qua `setFrameAutosaveName`.

### 5. Tab Thống kê việt hoá header

- "Tuần này — 2026-W21" → **"Tuần 21 năm 2026 (từ 18/05 đến 24/05/2026)"**.
- Tính từ thứ Hai đến Chủ Nhật (ISO 8601 weekday=2 → weekday=1+7d).
- Helper `UsageSummary.vietnameseHeader(for:)` + `UsageSummary.dateRange(for:)`.
- Áp dụng cho cả Section "Tuần này" và "Các tuần đã đóng" (historical).

### Files

- [vkey/App/Setting.swift](vkey/App/Setting.swift) — thêm `AppSmartSwitchState`, `AppSmartSwitchSource`, `AppSmartSwitchConfig` + 2 Defaults keys mới.
- [vkey/App/AppState.swift](vkey/App/AppState.swift) — refactor `activeApplicationDidChange` ưu tiên `appSmartSwitchConfigs`; thêm `migrateSmartSwitchTo3State`, `setAppSmartSwitchState`, `resetAppSmartSwitchToAutoLearn`, `applySmartSwitchAutoLearn`.
- [vkey/App/AppDelegate.swift](vkey/App/AppDelegate.swift) — gọi migration + `runSmartSwitchAutoLearnIfDue` ở launch; bump minSize 480×720.
- [vkey/Stats/UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) — extend `WeekBucket` với `appLanguageVnCounts`, `appLanguageEnCounts`, `appLanguageDays`; recording trong `applyCommit`; thêm `computeSmartSwitchAutoLearn`; helper `UsageSummary.dateRange` + `vietnameseHeader`.
- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift) — bỏ guard `spellCheckInSentenceEnabled` (gộp vào `spellCheckEnabled`).
- [vkey/View/SettingView.swift](vkey/View/SettingView.swift) — SpellCheckView merge 3 section thành "Cấu hình kiểm tra chính tả"; frame 480×720.
- [vkey/View/SmartSwitchView.swift](vkey/View/SmartSwitchView.swift) — full redesign 3-state + source icons + popover picker.
- [vkey/View/SmartSwitchSuggestionSheet.swift](vkey/View/SmartSwitchSuggestionSheet.swift) — replace bằng `SmartSwitchAutoLearnSheet` preview auto-learn suggestions.
- [vkey/View/StatisticsView.swift](vkey/View/StatisticsView.swift) — apply `vietnameseHeader` cho header current + historical weeks.
- Frame `minWidth: 480, minHeight: 720` áp dụng cho 5 tab (SettingView, SmartSwitchView, MacroView, StatisticsView).

### Schema backward-compat

- `WeekBucket` codable: 3 field mới (`appLanguageVnCounts`, `appLanguageEnCounts`, `appLanguageDays`) đều `decodeIfPresent ?? [:]` — file v1.5.x/1.6.x không có sẽ default empty, không break.
- `smartSwitchApps` Defaults key GIỮ trong codebase làm fallback (deprecated). Lần launch v1.7.0 đầu tiên migration đọc list này → ghi sang `appSmartSwitchConfigs` 1 lần.

## [1.6.3] - 2026-05-20 — "Stats Restored"

Hotfix khẩn cấp cho lỗi **tab Thống kê hiển thị toàn 0 sau khi cài bản mới** — root cause THỰC SỰ phát hiện sau khi fix các nhánh khác không hiệu quả.

### Root cause: JSONEncoder/Decoder strategy mismatch

- **Bug đã có từ v1.5.0** khi UsageStatistics được giới thiệu. Tất cả các phiên bản 1.5.x và 1.6.0-1.6.2 đều dính.
- **Encoder** ở [UsageStatistics.swift:811](vkey/Stats/UsageStatistics.swift) dùng `dateEncodingStrategy = .iso8601` → ghi field `weekEnd` thành chuỗi `"2026-05-24T16:59:59Z"`.
- **Decoder** ở các call site (`loadCurrentWeekIfNeeded`, `historicalSummaries`, `diagnosticReport`) dùng `JSONDecoder()` MẶC ĐỊNH → `dateDecodingStrategy = .deferredToDate` → kỳ vọng Double timestamp.
- **Kết quả**: mỗi lần app khởi động đọc `current.json`, decode `weekEnd` throw `typeMismatch: expected Double, found string`. `try?` nuốt lỗi → `loadCurrentWeekIfNeeded` return early → `counters` giữ default empty `WeekBucket()` (wordsTotal=0).
- UI tab Thống kê đọc `counters` → hiển thị 0. **Data đầy đủ vẫn còn trên disk**, chỉ là không decode được.

### Vì sao các fix trước không giải quyết?

- **v1.6.1** sửa logic rotation + persistCurrentWeek không ghi `<currentWeekId>.json` → đúng nhưng không động đến root cause decode.
- **v1.6.2** chuyển endpoint dictionary + manual update button → đúng nhưng không liên quan stats.
- Nguyên nhân chỉ lộ khi test thực tế file decode bằng Swift script standalone → `typeMismatch` exception hiện rõ.

### Fix

- Tạo `JSONDecoder.statsConfigured` singleton với `dateDecodingStrategy = .iso8601` khớp encoder.
- Thay tất cả 4 call site `JSONDecoder().decode` trong [UsageStatistics.swift](vkey/Stats/UsageStatistics.swift) bằng `JSONDecoder.statsConfigured.decode`.

### Tác động

- User nâng từ 1.6.2 trở xuống lên 1.6.3 sẽ thấy lại data thống kê trên UI ngay lập tức (data trên disk được giữ nguyên qua tất cả các phiên bản).
- Diagnostic API trong tab Thống kê giờ in được thông tin chi tiết về cả `current.json` lẫn historical files.

### Bài học

- **Encoder + decoder phải luôn dùng cùng strategy**. Nên dùng helper struct/extension chung để không lệch.
- **`try?` nuốt lỗi** trong file IO là dangerous pattern khi không có fallback explicit. Đáng log warning để phát hiện sớm trong production.
- Test decode thực tế (run-time data) khác xa schema validity check trong unit test.

## [1.6.2] - 2026-05-19 — "Capacity Audit"

Bản vá hạ tầng cập nhật từ điển + audit capacity, kết quả từ rà soát chiều sâu sau khi tích hợp dataset undertheseanlp.

### Đổi endpoint từ Contents API sang raw.githubusercontent.com

- **Trước (v1.6.0–v1.6.1)**: `https://api.github.com/repos/.../contents/lexicon-update.json` với `Accept: application/vnd.github.v3.raw`.
  - Giới hạn 1 MB raw (file lớn hơn → base64 wrapped, decode fail).
  - Rate-limit 60 req/h anonymous → nhiều user behind shared NAT có thể đụng giới hạn.
  - Cache 60s, latency cao hơn (API server).
- **Sau (v1.6.2)**: `https://raw.githubusercontent.com/tuanlongsav/vkey/main/lexicon-update.json`.
  - Không giới hạn kích thước (đến 100 MB).
  - Không rate-limit anonymous.
  - CDN cache 300s, nhanh hơn.
  - Đơn giản: không cần Accept header tùy chỉnh.
- Ý nghĩa: dictionary có thể mở rộng lên ~50,000 entries (~1 MB) hoặc hơn mà không lo lỗi fetch.

### Nút "Cập nhật từ điển ngay" thủ công (mới)

- Tab Chính tả → Section "Từ điển từ GitHub" (mới).
- Hiển thị: phiên bản từ điển hiện tại + số từ tiếng Việt đang dùng.
- Button "Cập nhật ngay" → force-check, bypass throttle 24h.
- Status: "✓ Đã cập nhật. Phiên bản mới: vN — X từ" hoặc "Đã ở phiên bản mới nhất".
- Lý do: auto-update chạy 24h/lần khi launch không đủ — user vừa thấy maintainer publish bản mới có thể không muốn đợi đến ngày mai.

### Capacity audit results

Test trên Apple Silicon Mac (Mac mini M2, macOS 14):

| Entries | File size | Parse | Set construct | Lookup |
|---------|-----------|-------|---------------|--------|
| 8,234 (current v6) | 130 KB | 0.30 ms | 0.16 ms | 0.05 µs |
| 20,000 | 314 KB | 0.58 ms | 0.44 ms | 0.03 µs |
| 50,000 | 786 KB | 1.49 ms | 0.80 ms | 0.06 µs |
| 100,000 | 1,569 KB | 3.34 ms | 2.18 ms | 0.09 µs |
| 200,000 | 3,146 KB | 6.69 ms | 5.11 ms | 0.10 µs |

**Conclusion**:
- Computational headroom: rất lớn — app xử lý 200k entries không lag.
- Real bottleneck: **download time on slow networks**. Recommend safe ceiling **~50,000 entries (~1 MB)** để đảm bảo < 10s trên 3G typical.
- Memory footprint trivial (< 10 MB cho 100k entries).

### Lexicon v6 (đã ship qua auto-update v1.6.1 trong 24h)

- Audit pass loại 1,178 noise entries (75 single-char + 1,103 ASCII no-VN-marker).
- 9,412 → 8,234 syllables (cleaner, +1,050 từ thật so với baseline 7,184).
- Script tái sử dụng: [Tools/audit_lexicon.py](Tools/audit_lexicon.py).

## [1.6.1] - 2026-05-19 — "Polish & Persistence"

Bản vá tập trung sửa các regression của 1.6.0, bổ sung quality-of-life cho cửa sổ Cài đặt và mở rộng dictionary lên ~9,412 syllables.

### Sửa lỗi mất hiển thị Thống kê sau khi cập nhật (Issue 3)

- **Triệu chứng**: user upgrade 1.5.x → 1.6.0 thấy tab Thống kê toàn số 0 dù trước đó đã có data.
- **Nguyên nhân**: `loadCurrentWeekIfNeeded` ở `UsageStatistics` skip load nếu `loaded.weekId != currentWeekId()`. Khi upgrade qua biên tuần ISO (vd quit 1.5.10 ở W20, mở 1.6.0 ở W21), counters cũ trên disk bị bỏ rơi. Lần flush kế tiếp ghi đè `current.json` với empty bucket → data MẤT VĨNH VIỄN.
- **Fix**: luôn load file, để `rotateIfNeeded()` xử lý đúng — nếu weekId stale, ghi historical file `<oldWeekId>.json` rồi mới reset.
- **Phụ**: `persistCurrentWeek` không còn ghi `<currentWeekId>.json` cho tuần ĐANG chạy (file này lẫn vào `historicalSummaries` gây nhiễu).
- `historicalSummaries()` thêm defensive filter exclude `<currentWeekId>.json`.
- Thêm `diagnosticReport()` API + nút "Xuất chẩn đoán Stats" trong tab Thống kê — user gửi lại khi báo lỗi.
- Thêm Section "Các tuần đã đóng" hiển thị data historical (trước 1.6.1 không render).

### Sửa bug Tab key đoán từ (Issue 1a)

- **Triệu chứng**: gõ "dữ" + Space → HUD show "liệu" → bấm Tab → output có "dữ" thừa.
- **Fix**: rewrite `handleTaskKey(.Tab)` ở [InputProcessor.swift](vkey/App/InputProcessor.swift):
  - Defensive — ALWAYS swallow Tab khi `wordPredictionEnabled && activePrediction != nil` (kể cả khi buffer state không đủ điều kiện apply). Tránh OS autocomplete / form-tab can thiệp.
  - Trước khi insert prediction, force-reset buffer bằng `newWord(storePrevious: false)` để guarantee không có residue.

### Đoán từ ưu tiên từ điển + chuyển toggle sang tab Chung (Issue 1b)

- **Vấn đề cũ**: ranking pure-frequency dễ suggest rác (vd "tcb" → "abc" vì user gõ tay nhiều lần).
- **Fix**: `PredictionEngine.topPrediction` blended scoring:
  - **+1000** nếu candidate là từ tiếng Việt (`LexiconManager.isVietnameseWord`)
  - **+500** nếu candidate nằm trong `Defaults[.userKeepWords]`
  - **+ raw frequency** (trigram count × 2 hoặc bigram count hoặc embedded weight)
  - Filter: loại candidate trùng prev1 (vd "dữ" → "dữ"); phải có dict bonus HOẶC freq ≥ 5
- Toggle "Đoán từ tiếp theo" chuyển từ tab Chính tả → **tab Chung** (gần các toggle global khác). Settings key `wordPredictionEnabled` không đổi → user upgrade không mất state.

### Cửa sổ Cài đặt resize + default size đồng nhất (Issue 2)

- Trước: mỗi tab tự set `.frame(width: 440-480, height: 420-560)` → window kích thước nhảy khi switch tab; không resize được.
- Sau: 5 tab dùng cùng `.frame(minWidth: 540, minHeight: 640, maxWidth: .infinity, maxHeight: .infinity)`.
- AppDelegate hook `windowDidBecomeKey` → insert `.resizable` styleMask + `setFrameAutosaveName("VkeySettingsWindow")`. User drag góc/cạnh để mở rộng; kích thước được nhớ giữa các lần mở.

### Đề xuất Macro từ cụm từ tiếng Việt (Issue 4)

- `UsageStatistics.WeekBucket` schema thêm `vnPhraseCounts2`, `vnPhraseCounts3` (optional decode → backward-compat với JSON 1.5.x).
- `recordCommit` track sliding window 3 commit gần nhất khi `.keepVietnamese`. Reset khi xen English/raw/Smart Switch (đổi context).
- API mới: `aggregatedTopVietnamesePhrases(threshold:)`.
- `MacroSuggestionSheet` load gộp single-word + phrase candidates (phrase ưu tiên hiển thị trước — tiết kiệm keystroke hơn). Auto-suggest viết tắt: "công ty → ct", "kính gửi anh → kga".
- **Track từ 1.6.1+** (không backfill từ data cũ).

### Mở rộng dictionary +1,050 từ (Issue 5)

- Tích hợp dataset [undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary) của tác giả Vũ Anh (GPL-3.0) — tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN.
- `lexicon-update.json` schema v5: 7,184 → 9,412 syllables (merge thô).
- **Audit pass (v6)**: loại noise có thể gây sai spell-check:
  - 75 single-char entries (a, b, c, ..., z, à, á, ...) — chữ cái không phải syllable, để lại sẽ break typo correction.
  - 1,103 ASCII-only entries không có dấu / không có cluster phụ âm đầu VN (vd "abscess", "microcomputer", "algorithm") — likely English/Latin noise từ transliteration.
- Kết quả sau audit: **8,234 syllables** (+1,050 từ thực sự VN so với baseline 7,184). Baseline 7,184 từ curated v1.6.0 giữ nguyên 7,136 (48 single-char vowels cũng bị loại).
- Bump `version: 4 → 6` → app fetch tự động qua `LexiconManager.checkAndPromptForDictionaryUpdate` (throttle 24h). Không cần release app mới.
- Build script: [Tools/build_underthesea_package.py](Tools/build_underthesea_package.py).
- Audit script: [Tools/audit_lexicon.py](Tools/audit_lexicon.py).
- Research report: [Tools/research/undertheseanlp-dictionary.md](Tools/research/undertheseanlp-dictionary.md).
- Attribution: cập nhật `_meta.sources` trong package + [LICENSE-DATA.md](LICENSE-DATA.md).
- **Performance verified**: package 95.6 KB, parse 0.31ms, set construction 0.17ms → app load không ảnh hưởng.

### Đã defer ra v1.7.0+

- Phrase corpus integration cho prediction engine (~70k phrase pairs từ undertheseanlp).
- Quality audit cho 9,412 syllables (loại từ archaic / hiếm).
- Performance test cold-start fetch + merge latency.

## [1.6.0] - 2026-05-19 — "Smart Suggestions & Prediction"

Bản nâng cấp lớn về trải nghiệm gợi ý & dự đoán: gợi ý từ điển cá nhân chuyển sang chế độ review, thêm dự đoán từ tiếp theo qua HUD nổi, và 4 cải tiến chất lượng cuộc sống.

### Thông báo cập nhật tự động (throttle 1 lần/ngày)

- `Updater` giờ tự động kiểm tra bản mới khi app launch — nhưng throttle 1 lần/24h qua key `lastUpdateCheckDate` để không spam network/UI.
- Khi có bản mới: hiển thị notification chuẩn macOS thay vì phải user manual bấm "Kiểm tra cập nhật" trong menu bar.
- Manual check (bấm menu) vẫn bypass throttle để user có thể force kiểm tra bất cứ lúc nào.

### Stats lưu bền vững (flushSynchronously + Codable backward-compat)

- `UsageStatistics.flushSynchronously()` mới — gọi từ `applicationWillTerminate` để đảm bảo counters write đến disk trước khi process exit. Trước đây dùng async write, nếu user quit nhanh có thể mất 1-2 phút dữ liệu cuối cùng.
- Codable schema giờ có optional/default cho các field mới (vd `predictionEngineEnabled` history), backward-compat với JSON v1.5.x — user upgrade không mất stats cũ.

### Tab Thống kê — sắp xếp lại Sections

- Thứ tự mới: **Top từ tiếng Việt** → **Top từ tiếng Anh / raw** → **Top app** → **Tổng quan** → **Quản lý dữ liệu**.
- Phù hợp luồng user thực tế: vào tab → xem từ phổ biến → xem app phổ biến → xem tổng → cuối cùng mới đến nút reset/export. Trước đây "Tổng quan" ở đầu khiến user phải scroll xuống để xem chi tiết.

### Gợi ý từ điển cá nhân — chế độ Review (thay auto-promote)

- Trước đây: cụm gõ ≥10 lần (`vnKeepStreak ≥ 10`) tự động vào personal allow-dict — silent, không hỏi user.
- Vấn đề: tích luỹ rác như "tcb", "nb", "asdf"… vì user chỉ gõ thử nghiệm, không phải intent thật.
- **1.6.0**: hiển thị `PersonalDictSuggestionSheet` mỗi tuần (hoặc khi user mở từ tab Thống kê). User check ✓/✗ từng cụm trước khi vào personal dict.
- Streak tracking vẫn chạy, nhưng promote = user-driven, không silent.

### Dự đoán từ tiếp theo (mới — default OFF)

- `PredictionEngine` mới: hybrid bigram + trigram model từ `EmbeddedBigrams` (data nhúng sẵn ~50K từ phổ biến tiếng Việt).
- Khi user gõ space, engine match context 2-gram + 3-gram → trả về top 1–3 ứng viên.
- `PredictionHUDWindow`: NSWindow `.popUpMenu` level, nổi cạnh caret position (qua AX API). Render 1–3 chips với keyboard shortcut (Tab để accept top, ⌥+1/2/3 để chọn).
- **Default OFF** — tính năng beta, một số user thấy nhiễu khi gõ nhanh. Bật ở Cài đặt → tab Chính tả → toggle "Dự đoán từ".
- Không ảnh hưởng performance khi tắt (engine init lazy, HUD không tạo).

### Đổi tên menu — rõ nghĩa hơn

- `"Chuyển đổi 🇻🇳 | 🇺🇸"` → `"Chuyển đổi ngôn ngữ 🇻🇳 | 🇺🇸"`.
- User mới đôi khi không hiểu "Chuyển đổi" nghĩa là gì — thêm chữ "ngôn ngữ" để self-explanatory. Menu width tăng nhẹ nhưng vẫn gọn hơn 1.5.8 trở về trước.

## [1.5.10] - 2026-05-19 — "Updater Fixed"

Hotfix khẩn cấp 2 lỗi update flow phát hiện sau 1.5.9.

### Sửa appcast.xml invalid

- Title item 1.5.9 trong appcast.xml ghi `"Privacy & Tidy"` với ký tự `&` BARE — không escape XML hợp lệ.
- XMLParser của `AppcastParser` fail parsing, trả về nil shortVersion.
- Updater dùng fallback `"1.5.0"` cho server version + `0` cho versionCode → so sánh `localVersionCode (15080) < 0` = false → vào nhánh "đã là mới nhất".
- User bấm "Kiểm tra cập nhật" thấy `"Bạn đang sử dụng phiên bản mới nhất! (Phiên bản server: v1.5.0)"` thay vì đề nghị nâng lên 1.5.9.
- 1.5.10: sửa thành `"Privacy &amp; Tidy"` — XML hợp lệ.

### Harden Updater fallback

- `Updater.checkForUpdates(manual: true)`: khi `AppcastParser.parseTopItem()` trả nil HOẶC thiếu `sparkle:version`, fallback ngay sang `SPUStandardUpdaterController.checkForUpdates(nil)` thay vì show alert "đã mới nhất".
- Native Sparkle có XML parser robust hơn (handle entities, encoding issues) và sẽ correctly show update flow nếu phát hiện version mới.
- Trước đây nếu parser fail, Updater im lặng nuốt lỗi và báo nhầm — vừa gây confusion vừa khiến user bỏ lỡ update.

## [1.5.9] - 2026-05-19 — "Privacy & Tidy"

3 hiệu chỉnh nhỏ: menu bar layout, không lưu password vào stats, xoá từng cụm trong thống kê.

### Menu bar gọn hơn

- Rút title menu: `"Chuyển đổi bộ gõ 🇻🇳 | 🇺🇸"` → `"Chuyển đổi 🇻🇳 | 🇺🇸"`.
- Menu width hẹp lại đáng kể; padding trái-phải đối xứng hơn (xa rời cạnh phải bằng xa rời cạnh trái).

### Bảo vệ riêng tư khi gõ mật khẩu

- `UsageStatistics.recordCommit()` thêm guard `IsSecureEventInputEnabled()`. Khi macOS ở secure-input mode (ô password, `sudo`, 1Password reveal, ...), stats tự bỏ qua.
- EventHook đã bypass processing trong secure input từ trước (line 215-217), nhưng có thể có race window khi vừa thoát secure-input mà InputProcessor buffer còn commit lưng chừng. Guard mới là defense-in-depth — đảm bảo password KHÔNG bao giờ rò vào top-words list.
- Áp dụng cả cho `recordSmartSwitchFire` nếu cần (chưa cần — Smart Switch fire không record nội dung).

### Xoá từng cụm trong Top từ / Top app

- `StatisticsView`: thêm trash icon mỗi row trong "Top từ tiếng Việt", "Top từ tiếng Anh / raw", "Top app dùng nhiều".
- Click trash → `UsageStatistics.removeFromCurrentWeek(word:category:)` xoá entry khỏi `vnWordCounts` / `enWordCounts` / `appCounts` của current week.
- Streak tracking (`vnKeepStreak`, `enRestoreStreak`) cũng reset để tránh personal-dict auto-promotion từ đó (đề phòng user explicit từ chối từ).
- Historical (closed) weeks không đụng — đó là snapshot lịch sử.
- Tổng counters (`wordsTotal`, `wordsKeptVietnamese`, ...) giữ nguyên.
- API mới: `enum StatCategory { case vietnamese, english, app }`.

## [1.5.8] - 2026-05-19 — "Right-Sized"

Hotfix sau 1.5.7 sửa kích thước icon Theme Emoji + tinh chỉnh menu bar.

### Sửa Emoji icon quá to ở Smart Switch / Macro tabs

- **Triệu chứng**: ở theme Emoji, icon 🔁 trong header Smart Switch và icon 📝 / ✏️ / 🗑️ / 📤 / 📥 trong tab Macro phình ra quá to, đẩy text dạt sang, mất nội dung hiển thị. Tab Chung và Chính tả thì OK.
- **Nguyên nhân**: 1.5.7 render emoji NSImage ở `pointSize=32` với modifier `.resizable().scaledToFit()`. Trong các HStack header / List rows không có frame constraint, `.scaledToFit()` cho phép Image stretch đầy chiều cao available → icon bị phình.
- **Fix**: 
  - Giảm `pointSize` default từ 32 → 18 (match xấp xỉ SF Symbol body baseline).
  - **Bỏ `.resizable().scaledToFit()`** → Image render ở natural size 18pt cố định trong mọi context. Không stretch theo parent. Predictable layout.
  - Trade-off: Smart Switch tab header (dùng `.font(.system(size: 32))` cho SF Symbol) sẽ thấy emoji 18pt thay vì 32pt — chấp nhận để giữ layout ổn định cho mọi context khác.

### Tinh chỉnh menu bar dropdown

- Bỏ double-space trong title menu items: `"Smart Switch  ✓"` → `"Smart Switch ✓"`, `"Chuyển đổi bộ gõ  🇻🇳 | 🇺🇸"` → `"Chuyển đổi bộ gõ 🇻🇳 | 🇺🇸"`, etc.
- Text giờ sát icon hơn, menu width gọn hơn ~10pt.

## [1.5.7] - 2026-05-19 — "Fine Tuning"

Hotfix sau 1.5.6 sửa 3 vấn đề UX user phản hồi.

### Sửa lỗi Theme Emoji mất text

- **Triệu chứng**: ở theme "Emoji vui tươi", menu bar dropdown chỉ hiện icon emoji (⚙️, 🔁, 📝, ✅, …) KHÔNG hiện text labels ("Cài đặt", "Smart Switch", …). Settings windows thì OK.
- **Nguyên nhân**: 1.5.6 render emoji qua SwiftUI `Text(glyph)` trong Label's icon slot. MenuBarExtra (`.menu` style) khi convert Label → NSMenuItem hiểu nhầm Text icon thành NSMenuItem.title → ghi đè title gốc → text label biến mất, chỉ thấy emoji.
- **Fix**: render emoji glyph thành `NSImage` qua `NSImage(size:flipped:drawingHandler:)` + `NSAttributedString.draw(at:)`. NSImage được cache qua `NSCache` để tránh redraw mỗi tick. `Image(nsImage:)` map clean vào NSMenuItem.image, title gốc giữ nguyên. Áp dụng cho mọi context (menu, settings, onboarding) với `.resizable().scaledToFit()` để inherit Label icon slot.

### Migration macro dedupe theo cả `viết dài`

- `AppDelegate.seedDefaultMacrosIfNeeded()` step 3 trước đây chỉ dedupe theo `from`. Nếu user có `vietnam → Việt Nam` (custom), default `vn → Việt Nam` vẫn được thêm → duplicate `to`.
- 1.5.7: thêm `existingTos` check. Skip default macro nếu user đã có cùng `to`, kể cả `from` khác.

### Hỏi Gộp / Ghi đè khi nhập macro từ file

- `MacroView.importMacros()` trước đây merge âm thầm bằng skip-duplicate-`from`.
- 1.5.7: hiện NSAlert 3-button:
  - **"Gộp (giữ macro hiện tại)"**: skip imported macro nếu trùng `from` HOẶC `to` với macro hiện có.
  - **"Ghi đè (thay macro trùng)"**: với mỗi imported macro, xóa các macro hiện có trùng `from` HOẶC `to`, rồi thêm imported. Macro user có mà file không có → giữ nguyên.
  - **"Huỷ"**: không nhập gì.
- Helper text status hiển thị số macro thêm + thay thế + bỏ qua sau khi import.

## [1.5.6] - 2026-05-19 — "Pick a Look"

Hotfix sau 1.5.5: thêm theme thứ 3 (Emoji) + sửa nút duplicate trong tab Chính tả.

### Theme picker mở lại

- Submenu **"Giao diện ứng dụng"** trong menu bar (đã ẩn ở 1.5.4) giờ mở lại với **3 lựa chọn**:
  - **Mặc định**: SF Symbol gốc, không hiệu ứng (đơn giản, gọn).
  - **3D bóng bẩy**: SF Symbol + 4-stop gradient + double shadow + `.hierarchical` — vẫn là default.
  - **Emoji vui tươi** (mới): thay từng SF Symbol bằng Unicode emoji tương ứng. Mapping ~60 symbol: `gearshape` → ⚙️, `lightbulb` → 💡, `arrow.left.arrow.right.circle` → 🔁, `text.cursor` → 📝, `sparkles` → ✨, `chart.bar.doc.horizontal` → 📊, …. Cảm hứng từ emoji headers trong CHANGELOG.
- Code: thêm enum case `AppTheme.emoji` + `ThemedSymbol.emojiFor(_:)` static map. Fallback về `Image(systemName:)` nếu symbol chưa có mapping.
- Default theme vẫn là `.threeD`. User chuyển sang `.emoji` từ menu bar bất cứ lúc nào.

### Sửa lỗi UI

- **Tab Chính tả: gộp 2 button mở Editor**. 1.5.5 lỡ tạo 2 button cùng mở `PersonalDictionaryEditorView`:
  - "Quản lý từ điển cá nhân" trong Section "Từ điển cá nhân" (gated trên `personalDictionaryEnabled`).
  - "Mở từ điển cá nhân để chỉnh sửa" trong Section "Học hành vi từ Thống kê".
- 1.5.6: giữ button **"Quản lý từ điển cá nhân"** + bỏ gate `personalDictionaryEnabled` để **luôn hiển thị**. Bỏ button duplicate ở Section "Học hành vi". Helper text Section "Học hành vi" giờ trỏ user lên Section trên.

## [1.5.5] - 2026-05-19 — "Learn From Me"

vkey giờ học hành vi user và đề xuất tự động dựa trên Thống kê.

### 🧰 Macro

- **Bộ default v2** (1.5.5+): 14 macro office VN + 8 emoji + 12 ký hiệu khoa học = **34 macro** (file `vkey/App/DefaultMacros.swift`).
  - Office (14): `vn`, `hn`, `sg`, `tphcm`, `bcao`, `cvan`, `qdinh`, `tbao`, `sdt`, `dchi`, `ttin`, `cty`, `gdoc`, `nvien`.
  - Emoji (8): `okok` → 👌, `vuiv` → 😀, `yeuu` → ❤️, `likee` → 👍, `dlike` → 👎, `hihi` → 😂, `party` → 🎉, `prayy` → 🙏.
  - Ký hiệu (12): `gte` → ≥, `lte` → ≤, `neq` → ≠, `deg` → °, `pm` → ±, `inff` → ∞, `pii` → π, `xx2` → x², `xx3` → x³, `arr` → →, `ckok` → ✓, `crs` → ✗.
- **Migration an toàn** cho user 1.5.3/1.5.4 đã seed 19 macro cũ — gated bởi `Defaults[.defaultMacrosVersion]` (mới):
  - Dọn 5 entries cũ (`tv`, `dn`, `kg`, `kn`, `xc`) **chỉ khi user chưa sửa**.
  - Đổi `gd → gdoc`, `nv → nvien` **chỉ khi tuple gốc nguyên bản**.
  - Add 20 entries mới mà user chưa có (`from` dedupe).
- **Gợi ý Macro từ Thống kê** (mới): dòng "lightbulb" trong tab Macro hiển thị số từ tiếng Việt user gõ **≥10 lần all-time** mà chưa có macro. Bấm "Xem & thêm" → sheet bảng với:
  - Auto-suggest `from` heuristic (lấy ký tự đầu mỗi từ + strip diacritic, vd "Báo cáo công việc" → `bccv`).
  - User edit + bấm "Thêm" → entry vào `Defaults[.macros]`.
  - "Thêm tất cả" để add hàng loạt.

### 🔁 Smart Switch

- **Toggle bật/tắt trong tab** (cuối cùng!) — đặt cạnh header. Trước đây chỉ có ở menu bar.
- **Gợi ý app từ Thống kê** (mới): dòng "lightbulb" highlight app user dùng **≥10 lần all-time** mà chưa nằm trong `smartSwitchApps`. Sheet bảng hiển thị:
  - Display name (best-effort qua `NSWorkspace.urlForApplication`).
  - Bundle ID.
  - Số lần xuất hiện.
  - Button "Thêm" per row + "Thêm tất cả".

### 📝 Tab Chính tả

- **Bỏ Section "Từ điển GitHub"** cũ (nút manual "Cập nhật ngay" + status text). Auto-fetch GitHub mỗi 24h vẫn chạy ngầm trong `LexiconManager.checkAndPromptForDictionaryUpdate()`.
- **Thay bằng Section "Học hành vi từ Thống kê"**:
  - Toggle "Tự động cập nhật từ điển cá nhân" (mặc định bật, gate `performWeeklyFeedback`).
  - Helper text giải thích cơ chế.
  - Button "Mở từ điển cá nhân để chỉnh sửa" → mở `PersonalDictionaryEditorView`.
- Manual button "Chạy đồng bộ Personal Dictionary ngay" trong tab Thống kê **vẫn chạy được** bất kể toggle.

### 🎨 Icon bóng bẩy hơn

- `ThemedSymbol` enhanced 3D fallback:
  - **4-stop LinearGradient** (top bright → mid dim → bottom bump) thay 2-stop — mô phỏng ball lighting.
  - **Double shadow**: outer accent halo (radius 4) + inner black drop (radius 1) — icon nổi 3D hơn.
  - `.symbolRenderingMode(.hierarchical)` thay `.multicolor` — gradient áp nhất quán lên multi-layer symbols.

### 🛠 API & Migration

- `UsageStatistics`: thêm `aggregatedTopVietnameseWords(threshold:)` và `aggregatedTopApps(threshold:)` cộng dồn `topVietnameseWords`/`topApps` qua tất cả tuần (current + historical).
- `Setting.swift`: thêm 2 keys mới — `defaultMacrosVersion` (Int, default 0) và `autoPersonalDictFeedback` (Bool, default true).
- `UserDataMigration`: export/import 2 fields mới. Backup 1.5.4 import vào 1.5.5 không crash.
- `AppDelegate.seedDefaultMacrosIfNeeded()`: helper mới handle full migration logic.

## [1.5.4] - 2026-05-19 — "Glossy Default"

Hotfix sau 1.5.3 hiệu chỉnh 2 quyết định UX:

### Khôi phục Menu Bar footer

- Phần 5 ở 1.5.3 thay 3 nút "Ủng hộ / Thông tin / Cập nhật" thành 1 hàng icon-only — sau khi xem thực tế thấy thiếu chữ làm khó đọc, đặc biệt cho user mới.
- 1.5.4 đổi lại: 3 nút **chữ kèm icon** như 1.5.2 (full text label + SF Symbol). Không xoá file `MenuBarFooterRow.swift` (giữ cho tham khảo / dùng lại).

### Theme 3D = default mới

- Phần 6 ở 1.5.3 thêm submenu "Giao diện ứng dụng" cho user chọn Mặc định / 3D.
- 1.5.4 quyết định: **theme `.threeD` là default mới** (gradient + shadow + multicolor + `.fill` trên SF Symbol). Submenu picker ẩn đi tạm thời (code vẫn giữ trong `vkeyApp.swift` để mở lại sau khi có bộ icon bitmap).
- `Defaults[.appTheme]` default đổi từ `.default` → `.threeD`.

### Icon templates cho designer

- Thư mục mới `Tools/icon-set-templates/` chứa **57 SF Symbol vkey đang dùng**, mỗi cái export ra 3 PNG size (32, 64, 96 pt @ 2x retina). Tổng 171 file PNG.
- Script `Tools/export_sf_symbols.swift` re-generate template khi UI thêm icon mới.
- Thêm `Tools/icon-set-templates/README.md` hướng dẫn designer workflow drop artwork vào `Assets.xcassets/Icons3D/`.

## [1.5.3] - 2026-05-19 — "Office Friendly"

Milestone gom nhiều thay đổi UX hướng tới người dùng phổ thông và dân văn phòng VN.

### 🪶 Tinh gọn tab Chính tả

- **Bỏ Picker "Nguồn từ điển"** (`dictionaryUpdateChannel` enum) — app luôn dùng từ điển nhúng + cập nhật (tương đương `.hybrid` cũ).
- **Bỏ Toggle "Tự động tải từ GitHub"** (`dictionaryGitHubUpdateEnabled`) — app luôn tự tải bản mới khi GitHub có.
- **Auto-apply update im lặng**: thay alert "Có bản mới, cài không?" bằng download + apply tự động khi launch (throttle 24h). Nút **"Cập nhật từ điển ngay"** vẫn hoạt động cho user muốn force ngay.
- **Đưa Section "Gợi ý & Sửa lỗi chính tả" lên cạnh "Kiểm tra chính tả"** cho liền mạch — order mới: Master → Kiểm tra → Gợi ý → Space Restore → Từ điển cá nhân → Từ điển GitHub.
- Master toggle "Kích hoạt nhanh tất cả tính năng mới" đơn giản hơn — bỏ nhánh conditional dictionary.

### 🧰 Macro

- **Toggle Macro on/off** ngay trên Menu Bar (cạnh "Smart Switch" / "Sửa lỗi chính tả") VÀ trong tab Macro của Cài đặt — tạm dừng macro mà vẫn giữ danh sách.
- **Seed 19 macro mặc định cho dân văn phòng VN** lần đầu launch (idempotent — chỉ chạy nếu list rỗng và chưa từng seed):
  - Địa danh: `vn`, `tv`, `hn`, `sg`, `dn`, `tphcm`
  - Văn bản: `kg` (Kính gửi), `kn`, `bcao`, `cvan`, `qdinh`, `tbao`
  - Thông tin: `sdt`, `dchi`, `ttin`, `cty`, `gd`, `nv`, `xc`

### 🎨 Giao diện

- **Bố cục Menu Bar gọn hơn**: 3 nút "Ủng hộ tác giả / Thông tin dự án / Kiểm tra cập nhật" gom thành 1 hàng icon-only (`MenuBarFooterRow.swift`).
- **Theme picker mới** "Giao diện ứng dụng" (submenu trong Menu Bar):
  - **Mặc định**: SF Symbol gốc (như trước).
  - **3D**: SF Symbol + gradient + shadow + multicolor + fill cho cảm giác bóng bẩy.
  - Designer có thể drop bitmap PDF vào `Assets.xcassets/Icons3D/<name>.imageset` để override hoàn toàn.
  - Giữ nguyên menu bar state flag (VN/US) và AppIcon — không đụng tới.
- ~62 nơi dùng `Image(systemName:)` / `Label(_, systemImage:)` được wrap qua `ThemedSymbol` / `Label(_, themedSymbol:)` để đổi theo theme.

### 📚 Tài liệu

- **`DICTIONARY_UPDATE.md`** (mới, root repo) — workflow cho maintainer publish bản từ điển trên GitHub: edit JSON tay hoặc rebuild qua `Tools/build_lexicon.py`, bump version Int, commit + push. User auto nhận trong 24h.

### 🧹 Dọn dẹp

- Dọn 2 UserDefaults orphan keys (`dictionary-update-channel`, `dictionary-github-update-enabled`) trong `handleVersionChange()` — idempotent, an toàn.
- `LexiconManager.reload(channel:)` → `LexiconManager.reload()` (đơn giản hoá signature).
- `UserDataMigration`: bỏ 2 fields cũ trong `UserDataExport`, thêm 3 fields mới (`macroEnabled`, `macrosSeeded`, `appTheme`). Backup 1.5.2 import vào 1.5.3 không crash — 2 field cũ ignored.

## [1.5.2] - 2026-05-19 — "Settings Restored"

Bản vá khẩn cấp tiếp theo: 1.5.1 mới chỉ nâng deployment target, vẫn chưa fix được root cause của lỗi không mở được "Cài đặt". Bản 1.5.2 khôi phục pattern hoạt động của 1.4.6.

### 🐛 Sửa lỗi (regression từ 1.5.0)

- **Menu "Cài đặt" hoàn toàn không có phản ứng** — refactor ở 1.5.0 đã thay thế nhầm cách mở Settings:
  - 1.4.6 dùng `@Environment(\.openSettings)` + `try? openSettings()` (SwiftUI `OpenSettingsAction`, hoạt động đúng).
  - 1.5.0 đổi thành `NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)` chạy ngay khi NSMenu vừa dismiss và `setActivationPolicy(.regular)` chưa kịp đẩy app lên foreground — responder chain thường chưa kịp đăng ký handler của Settings scene nên action bị nuốt im lặng.
  - 1.5.2 khôi phục pattern 1.4.6 + giữ `NSApp.activate(ignoringOtherApps: true)` sau khi gọi action để chắc chắn window lên trước.

### 🧹 Dọn dẹp

- Bỏ method `AppDelegate.openSettings()` không còn dùng đến.

## [1.5.1] - 2026-05-19 — "Sonoma Baseline"

Bản vá nhanh sau 1.5.0: sửa lỗi không mở được cửa sổ "Cài đặt" trên macOS Ventura và chuẩn hoá yêu cầu hệ điều hành.

### 🐛 Sửa lỗi

- **Menu "Cài đặt" không mở được trên macOS 13 (Ventura)**: `AppDelegate.openSettings()` dùng selector `showSettingsWindow:` vốn chỉ có từ macOS 14 (Sonoma). Trong khi đó `MACOSX_DEPLOYMENT_TARGET` lại đặt 13.0 → click vào "Cài đặt" trong MenuBarExtra không có phản ứng trên Ventura.

### 🛠️ Thay đổi nền tảng

- **Nâng deployment target tối thiểu lên macOS 14 Sonoma** ở mọi target (`vkey`, `vkeyTests`, `vkeyUITests`). Lý do: 1.5.0 đã dùng nhiều API SwiftUI/SwiftData hiện đại; Sonoma cũng đã phổ cập đủ rộng. Người dùng còn Ventura cần cập nhật macOS để dùng các bản mới.
- Cập nhật README, AGENTS.md, RELEASE.md để phản ánh yêu cầu hệ điều hành mới.

## [1.5.0] - 2026-05-19 — "Bilingual Reborn"

Phiên bản đại tu lớn nhất kể từ 1.3.x: tái cấu trúc kiến trúc, hoàn thiện engine bộ gõ và mở đường cho tính năng song ngữ Anh-Việt.

### 🔧 Sửa lỗi Engine tiếng Việt (Phase 1)

- **Recompute `chuaNguyenAmUO` sau typo correction**: trước đây 4 nhánh sửa lỗi gõ nhầm (`ei→ie`, `ou→uo`, `aoi→oai`, `ao→oa+cuối`) gán cứng cờ `chuaNguyenAmUO` (true/false). Khi mở rộng bảng `NguyenAmUO` về sau, hardcode này sai. Giờ luôn tính lại từ bảng — tiến tới `được`, `được`, `tươi`, `tướng` đều hoạt động đồng nhất.
- **Purify `TiengVietParser`**: parser không còn đọc `Defaults` bên trong — cờ `autoTypoCorrection` truyền qua tham số. Unit test bật/tắt không cần stub UserDefaults.
- **Hoàn thiện quy tắc đặt dấu kiểu cũ/mới**: bổ sung parametric test cho `oa/oe/uy/oai/uây/uyê` với và không có phụ âm cuối, cả 2 cờ. Đảm bảo `hoà ↔ hòa`, `khoẻ ↔ khỏe`, `thuý ↔ thúy` đúng ở từng kiểu.
- **Trie case-insensitive**: thêm `Trie(caseInsensitive: true)` cho lexicon (giữ semantics cũ cho âm tiết). Lookup không phân biệt hoa thường khi cần.
- **Tách "Late D toggle" thành extension chung**: 10 dòng code lặp giữa Telex và VNI giờ tập trung ở `TiengVietState.tryLateDToggle(char:triggerChars:)`. Không thay đổi hành vi, chỉ sạch hơn.
- **Defensive double-horn validation**: dấu móc kép trên `uo → ươ` giờ kiểm tra explicit nguyên âm là u+o trước khi áp dụng, phòng khi parser flag sai.

### 🛡️ Sửa lỗi Platform & App layer (Phase 2)

- **Sửa rò `CFRunLoopSource` ở `EventHook`**: trước đây tạo source mới mỗi lần `unregister`, source gốc không bao giờ được remove. Giờ lưu trong ivar và dùng lại.
- **Bỏ force-unwrap UTF-8 ở `FileMonitor`**: dữ liệu không phải UTF-8 từ `/tmp/vkey_switch` không còn crash app.
- **Đồng bộ chiến lược gửi events**: tất cả 3 strategy (`.batch`/`.stepByStep`/`.hybrid`) trong `EventSimulator` giờ async qua `simulationQueue`. Event tap callback không bị block, tránh `tapDisabledByTimeout` khi máy bận.
- **`ToggleHUDWindow` `@MainActor`**: singleton HUD giờ thread-safe; mọi truy cập từ event tap phải qua main queue.
- **Trust check timer có max retry**: timer kiểm tra Accessibility permission dừng sau 30 lần (≈60s), hiển thị NSAlert hướng dẫn user mở System Settings thay vì polling vô hạn.
- **Log lỗi `FileMonitor` ở `AppState`**: thay `try?` nuốt lỗi bằng do/catch với `os_log`. Smart Switch via `/tmp` không còn fail im lặng.
- **URL guards + URLSession cancel**: bỏ `URL(string: "...")!` force-unwrap trong `LexiconManager`. Lưu in-flight task, cancel trong `applicationWillTerminate`.
- **`Updater` chuyển từ regex sang `XMLParser`**: parser appcast mới của Foundation, ổn định với multi-line XML và attribute quoting.
- **`EventSimulator` keycode hardcode → named constants** (Backspace 0x33, Left Arrow 0x7B).

### 🏗️ Tái cấu trúc kiến trúc (Phase 3)

`App/InputProcessor.swift` từ **8552 dòng** rút xuống còn **814 dòng**. Code lexicon được tách thành module riêng:

- `Lexicon/Lexicon.swift` — Protocol + `InMemoryLexicon` + `SpellDecision` + String extensions.
- `Lexicon/EmbeddedLexiconData.swift` — 7184 syllable VN + EN baseline + keep + legacy restore pairs.
- `Lexicon/LexiconUpdatePackage.swift` — Codable schema v5 (xem dưới).
- `Lexicon/LexiconManager.swift` — Load / reload / download.
- `Lexicon/SuggestionService.swift` — Levenshtein + heuristic spell suggestions.
- `Lexicon/EnVnReference.swift` — **MỚI** — Bilingual lookup Anh ↔ Việt.
- `Input/SpellDecisionEngine.swift` — Tách khỏi InputProcessor.

### 📚 Từ điển song ngữ Anh-Việt — Schema v5 (Phase 4)

- **`lexicon-update.json` schema v5** thêm 3 trường optional (backward-compatible — app cũ vẫn đọc được):
  - `_meta` — block metadata + attribution + license.
  - `en_vn_mapping` — bản đồ Anh → [Việt candidates]. v1.5.0 ship sẵn 110 cặp core (programming, business, đời sống).
  - `vn_en_mapping` — bản đồ Việt → [Anh candidates] (dành cho Dictionary Browser sau).
  - `macros_recommended` — gợi ý macro để onboarding import.
- **`EnVnReference` integration**: `SpellDecisionEngine` consult bản đồ này khi quyết định "giữ tiếng Việt hay khôi phục tiếng Anh". Bật/tắt qua `Cài đặt → Chính tả & Từ điển → Dùng từ điển tham chiếu Anh-Việt` (mặc định bật).
- **Tools/build_lexicon.py**: script Python để build `lexicon-update.json` từ Kaikki/Wiktextract + wordfreq. Bao gồm `SEED_EN_VN_MAPPING` curate sẵn.
- **`LICENSE-DATA.md`**: clarify dual-license — code GPL-3.0, data CC BY-SA 4.0.

### ✨ Tính năng người dùng (Phase 5/6)

- **Macro Import/Export**: nút "Xuất" và "Nhập" trong `Cài đặt → Macro`. JSON format, idempotent merge (bỏ qua trùng `from`).
- **Defaults mới cho roadmap 1.5.x**: `translationHUDEnabled`, `programmingMode`, `perAppOverride`. UI cho Translation HUD / Programming Mode / Per-app override / CLI `vkeyctl` được lên kế hoạch trong 1.5.x patch series.

### 📊 Thống kê sử dụng & vòng lặp học hành vi (Phase 9)

- **`Stats/UsageStatistics`** — bộ đếm local-only, lưu tại `~/Library/Application Support/vkey/stats/`. Mỗi ISO-week một file JSON, rotate giữ 4 tuần gần nhất.
- **Đo lường**: tổng số từ commit, số từ giữ tiếng Việt / khôi phục tiếng Anh / giữ raw / được gợi ý, số lần Smart Switch kích hoạt, top 20 từ tiếng Việt + tiếng Anh, top app dùng nhiều nhất.
- **Vòng lặp học hành vi**: mỗi tuần (chạy 1 lần khi mở app trong tuần mới), `performWeeklyFeedback()` quét streak từ bucket hiện tại, **promote** các từ đáp ứng ngưỡng vào từ điển cá nhân:
  - Từ tiếng Anh xuất hiện ≥ 5 lần và luôn được restore → vào `userAllowWords` (bộ gõ nhận diện là tiếng Anh nhanh hơn lần sau).
  - Từ tiếng Việt xuất hiện ≥ 5 lần và luôn được giữ → vào `userKeepWords` (không bao giờ bị auto-restore nhầm sang tiếng Anh).
  - Tôn trọng `userDenyWords` (không promote nếu user đã chặn).
  - Cap 10 từ/tuần để tránh phình từ điển cá nhân.
- **UI**: tab "Thống kê & Sao lưu" trong Settings — xem snapshot tuần này, top từ, top app, nút "Chạy đồng bộ Personal Dictionary ngay", "Xóa toàn bộ dữ liệu".
- **Cam kết riêng tư**: không có request mạng, không có telemetry. Có thể tắt qua `Defaults[.statisticsEnabled]` hoặc xóa toàn bộ qua nút Settings.

### 💾 Sao lưu & Khôi phục dữ liệu cá nhân (Phase 10)

- **`UserDataMigration.currentExport()`** — Codable struct ghi lại mọi state người dùng: Defaults toàn bộ (typing method, kiểu đặt dấu, smart switch, spell check, restore policy, …), macros, allow/keep/deny lists, smart switch apps, per-app override, optional snapshot thống kê.
- **Xuất JSON**: nút "Xuất dữ liệu cá nhân" trong tab "Thống kê & Sao lưu". File mặc định tên `vkey-backup-<version>-<timestamp>.json`, lưu ở `~/Library/Application Support/vkey/backups/`.
- **Nhập JSON**: nút "Nhập từ tệp sao lưu". 2 chế độ:
  - **Gộp** (mặc định, an toàn): giữ dữ liệu hiện tại + thêm cái mới (không trùng).
  - **Ghi đè**: thay toàn bộ list bằng dữ liệu trong file.
- **Tự động hỏi sao lưu khi upgrade**: app phát hiện `CFBundleShortVersionString` thay đổi → hiển thị NSAlert "Bạn vừa nâng từ vX lên vY. Sao lưu ngay?". Có nút "Không hiện lại". Stamp version sau khi user xử lý xong dialog.
- **Schema-versioned**: `UserDataExport.schemaVersion` để app tương lai vẫn đọc được backup cũ; optional field cho forward-compat.

### 🛡️ Test isolation cải thiện

- Test plan tắt parallelization (tránh race trên Defaults global mà nhiều test mới đụng đến).
- Promotion logic tách thành `UsageStatistics.computePromotion(...)` pure function — test deterministic không phụ thuộc state singleton.

### 🧪 Test coverage

- 12 test mới cho engine (kiểu cũ/mới parametric, typo recovery flag, Trie case-insensitive, late-D toggle, pop() contract).
- 3 test cho `AppcastParser`.
- 5 test cho lexicon schema v5 + `EnVnReference`.
- 7 test cho `UsageStatistics` + `computePromotion` (pure, deterministic).
- 4 test cho `UserDataMigration` (encode/decode/merge/replace).
- Tổng test pass: **195+** (từ 147 ở 1.4.6).

### 📄 Tài liệu

- `LICENSE-DATA.md` — license riêng cho file dữ liệu.
- `README.md` — bổ sung mục "Nguồn dữ liệu từ điển" và credits cho Wiktionary/Kaikki/wordfreq.
- `app-arch.md` — cập nhật sơ đồ module phản ánh tách Lexicon/Input.

## [1.4.6] - 2026-05-19

- **Sửa lỗi bộ gõ tiếng Việt khi gặp từ tiếng Anh xen kẽ**:
  - Khắc phục lỗi các từ tiếng Việt bị khoá raw khi tiền tố trùng từ tiếng Anh (ví dụ: `tees` → `tế`, `heest` → `hết`, `theem` → `thêm`). Nguyên nhân gốc là cơ chế English word restoration làm hỏng trạng thái engine, giờ đã sửa bằng cơ chế **replay toàn bộ keys từ đầu** qua engine Telex/VNI khi phát hiện English restoration bị sai.
  - Thêm cờ `stoppedByEnglishWord` để phân biệt chính xác nguyên nhân khoá bộ gõ (English restoration vs spelling validation).
- **Sửa lỗi dấu móc (ươ) trên cặp nguyên âm `uo`**:
  - Khắc phục lỗi `dduwowcj` → `đuọc` thay vì `được`. Nguyên nhân: dấu móc chỉ được áp dụng cho nguyên âm thứ 2 (`o → ơ`) mà bỏ qua nguyên âm đầu (`u → ư`) khi chưa có phụ âm cuối. Giờ LUÔN áp dụng dấu móc cho cả hai nguyên âm trong pattern `uo`.
- **Sửa lỗi phím `w` thứ 2 xoá dấu móc trên pattern uo**:
  - Khắc phục lỗi `dduwow` → `đuo` (mất dấu móc). Phím `w` thứ 2 trên pattern `uo` giờ giữ nguyên dấu móc (no-op) thay vì toggle tắt, cho phép cả `dduowcj` và `dduwowcj` đều cho ra `được` đúng.
- **Kiểm thử mở rộng**: Bổ sung 18 test cases hồi quy cho các lỗi đã sửa, tổng cộng 147 tests đều pass.

## [1.4.5] - 2026-05-19

- **Tự động Cập nhật Từ điển từ GitHub**:
  - Hỗ trợ cơ chế tự động kiểm tra định kỳ hàng ngày (daily) hoặc khi khởi chạy ứng dụng mới để đồng bộ gói từ điển Việt/Anh nâng cấp từ GitHub.
  - Khi phát hiện gói từ điển mới, ứng dụng sẽ hiển thị hộp thoại thông báo và hỏi người dùng có muốn cập nhật hay không.
  - Cho phép người dùng bật/tắt tính năng tự động cập nhật hoặc bấm "Kiểm tra ngay" trực tiếp từ tab cài đặt Chính tả.
- **Nâng cấp Giao diện Quản lý Từ điển Cá nhân**:
  - Bổ sung bảng chỉnh sửa danh sách Từ điển Cá nhân (Từ cho phép, Từ giữ nguyên, Từ chặn) vô cùng trực quan dạng danh sách tương tác với các nút Thêm/Xoá dòng trực tiếp trong tab cài đặt Chính tả.
- **Tối ưu hóa Lõi Bộ gõ song ngữ**:
  - Hỗ trợ toàn diện phụ âm cuối `k` cho các địa danh và tên riêng dân tộc thiểu số (ví dụ: `đắk`, `lắk`) cả trên Telex và VNI.
  - Giải quyết lỗi không nhận diện được hoặc làm mất ký tự khi gõ các từ tiếng Anh kết thúc bằng chữ cái đúp như `class`, `pass` do lỗi trùng dấu Telex trong các từ này.

## [1.4.4] - 2026-05-19

- **Đưa nút tắt mở nhanh Sửa lỗi chính tả ra Menu Bar**:
  - Bổ sung tuỳ chọn **"Sửa lỗi chính tả"** dạng checkable trực tiếp trên thanh menu bar, được xếp chung nhóm vô cùng gọn gàng cùng với mục *Cài đặt* và *Smart Switch*.
- **Hoàn thiện bảo toàn từ gõ đúp âm Telex (English Double-letter Escape)**:
  - Khắc phục lỗi gõ các từ tiếng Anh có kết thúc bằng hai phím dấu Telex trùng nhau (như gõ `barr` thay vì bị autocorrect sai, giờ đây bộ gõ sẽ tôn trọng phím đúp dấu Telex này để bảo toàn từ tiếng Anh chuẩn `barr` không cần chuyển đổi bàn phím).

## [1.4.3] - 2026-05-19

- **Sửa lỗi chính tả & Auto-correct hoàn hảo**:
  - Khắc phục triệt để lỗi tự động sửa nhầm các từ đúng chuẩn cấu trúc tiếng Việt (như `tắt`, `kiểm`, `điển`, `thị`, `cá`...) bằng cách chỉ áp dụng cơ chế tự sửa/gợi ý của `SpellDecisionEngine` đối với các âm tiết không hợp lệ thực sự cần phục hồi (`needsRecovery == true`).
- **Nâng cao Trải nghiệm Cấu hình**:
  - Bổ sung nút chuyển đổi master **"Kích hoạt nhanh tất cả tính năng mới"** tại đầu trang cài đặt Chính tả để tắt/mở nhanh toàn bộ tổ hợp tính năng nâng cao (spell check, kiểm tra trong câu, khôi phục tiếng Anh, gợi ý thông minh, từ điển cá nhân và cập nhật tự động từ GitHub) chỉ bằng một click chuột.

## [1.4.2] - 2026-05-19

- **Nâng cấp lõi song ngữ Việt/Anh (Việt-first)**:
  - Bổ sung `LexiconManager` với cơ chế từ điển hybrid (embedded + gói cập nhật cục bộ).
  - Thêm `SpellDecisionEngine` để thống nhất quyết định giữ tiếng Việt, restore tiếng Anh, hoặc gợi ý sửa.
  - Giữ tương thích ngược Space Restore cũ (`ò` -> `of`, `ì` -> `if`, `sê` -> `see`, `tê` -> `tee`) thông qua rule engine mới.
- **Bổ sung gợi ý sửa chính tả (v1 core)**:
  - Thêm `SuggestionService.suggest(...)` (xếp hạng ứng viên theo khoảng cách chỉnh sửa + tín hiệu âm vị cơ bản).
  - Cho phép auto-apply khi độ tin cậy cao qua cờ cấu hình.
- **Hardening Input/Event pipeline**:
  - Hoàn thiện `TransformationTracker.detectFailure(...)` bằng telemetry gửi sự kiện thực tế.
  - Bổ sung `EventSendTelemetry` từ `EventSimulator` để tự động chuyển strategy chính xác hơn theo từng app.
- **Mở rộng cấu hình người dùng**:
  - Thêm các key: `spellCheckEnabled`, `englishAutoRestoreEnabled`, `restorePolicy`, `dictionaryUpdateChannel`, `suggestionEnabled`, `autoApplyHighConfidenceSuggestion`.
  - Thêm các key từ điển người dùng: `userAllowWords`, `userKeepWords`, `userDenyWords`.
- **Cải thiện chất lượng validator**:
  - Loại bỏ logic kiểm tra phụ âm cuối bị lặp trong `TiengVietValidator`, giảm false recovery ở trạng thái trung gian.
- **Bổ sung hạ tầng release Sparkle**:
  - Cập nhật tài liệu phát hành tại `RELEASE.md` với checklist anti-fail.
  - Thêm script `Tools/sparkle_sign_update.sh` để xuất `sparkle:edSignature` + `length` chuẩn trước khi cập nhật `appcast.xml`.

## [1.4.1] - 2026-05-19

- **Tích hợp các Cải tiến từ GoNhanh.org**:
  - **Ma trận Kiểm tra Chính tả 6 bước**: Triệt để ngăn chặn gõ dấu sai cấu trúc âm tiết tiếng Việt.
  - **Bộ lọc Vowel Inclusion Pairs**: Bổ sung bộ lọc whitelisting các cặp nguyên âm có thể đi cùng nhau để loại bỏ triệt để hiện tượng tự động sửa nhầm trên các từ tiếng Anh (như `claus`, `metric`, `house`, `beyond`).
  - **Hỗ trợ Tên riêng & Địa danh đặc biệt**: Cho phép gõ phụ âm đầu ghép `kr` (như trong *Krông Ana*) và phụ âm cuối `k` (như trong *Đắk Lắk*).
- **Bảo toàn Phím đúp (Doubled Tone Mark Preservation)**: Giữ nguyên phím đúp liên tiếp (`ss`, `ff`, `rr`, `xx`, `jj`) thay vì tự động xoá/toggle, bảo vệ hoàn toàn các từ tiếng Anh thông dụng như `staff`, `off`, `class`, `pass`, `staff`.
- **Tự động Khôi phục từ Tiếng Anh (Space Restore)**: Tự động phát hiện và khôi phục các ký tự tiếng Anh bị gõ nhầm khi nhấn phím Space (như `ò` -> `of`, `ì` -> `if`, `sê` -> `see`, `tê` -> `tee`).
- **Phục hồi Nhanh phím ESC (Escape Reversion)**: Nhấn ESC để hoàn tác ngay lập tức từ đang gõ dở dang về dạng phím thô ban đầu và đặt lại bộ đệm.
- **Dynamic AX Overlay/Search Box Probing**: Tự động phát hiện các ô nhập liệu đặc biệt như thanh tìm kiếm (`AXSearchField`) và các ô chọn dropdown (`AXComboBox`) của toàn hệ thống để kích hoạt chế độ Overwrite chọn-thay-thế, giải quyết triệt để lỗi dính chữ/nhân đôi chữ.

## [1.4.0] - 2026-05-19

- **Tối ưu hóa Smart Switch với AX Overlay Probing (Ý tưởng & giải pháp học tập từ XKey)**: Tích hợp cơ chế AX Probing siêu nhẹ (<0.1ms) kết nối trực tiếp với hệ điều hành macOS qua APIs Accessibility:
  - Tự động quét và phát hiện các bảng nhập liệu dạng Overlay/Launcher (Spotlight, Raycast, Alfred, LaunchBar) khi người dùng kích hoạt chúng.
  - Tự động chuyển bộ gõ về Tiếng Anh (English) ngay lập tức để tránh gõ nhầm di sắc dấu thanh tiếng Việt khi tìm kiếm hoặc nhập lệnh.
  - Khôi phục hoàn hảo trạng thái bộ gõ của ứng dụng nền trước đó khi đóng bảng nhập liệu overlay lại mà không gây bất cứ hiện tượng nhấp nháy màn hình hay xê dịch con trỏ.
- **Bộ lọc Impossible Consonant Clusters (Phonetic Bypass - Ý tưởng học tập từ XKey)**: Bổ sung bộ lọc phụ âm đầu không hợp lệ trong Tiếng Việt tại tầng xử lý phím đầu tiên:
  - Nếu phát hiện từ bắt đầu bằng các tổ hợp không có trong Tiếng Việt (`str`, `pl`, `cl`, `fl`, `gl`, `bl`, `br`, `cr`, `dr`, `fr`, `gr`, `pr`, `wr`, `st`, `sm`, `sn`, `sp`, `sc`, `sk`, `sw`, `tw`, `dw`, `sh`, `ps`, `pn`, `ts`, `kn`, `kr`) hoặc chứa các ký tự đặc biệt (`f`, `j`, `z` khi tuỳ chọn ZWJF tắt), bộ gõ sẽ lập tức bỏ qua xử lý và trả về ký tự gốc ngay lập tức mà không cần đợi người dùng gõ hết từ.
  - Hỗ trợ cơ chế phục hồi và tự động re-arm (tái kích hoạt) bộ gõ tiếng Việt khi người dùng nhấn Backspace xoá qua ký tự bị sai.

## [1.3.9] - 2026-05-19

- **Hiển thị thông báo trực quan (Translucent Toggle HUD - Thiết kế lấy cảm hứng từ XKey)**: Tích hợp cửa sổ thông báo HUD mờ kính (Glassmorphic HUD) siêu đẹp ở chính giữa màn hình mỗi khi người dùng nhấn phím tắt hoặc chuyển đổi thủ công chế độ gõ (VI/EN).
  - Tự động bỏ qua hiển thị HUD khi khởi động hệ thống và khi thay đổi ứng dụng tự động (Smart Switch) để tránh làm gián đoạn trải nghiệm của người dùng.
  - Hỗ trợ tuỳ chọn bật/tắt hiển thị HUD trực quan trong phần Cài đặt Chung (General Settings) của Cửa sổ Cài đặt.
  - Sử dụng hiệu ứng biểu tượng chuyển đổi mượt mà và nền kính `.ultraThinMaterial` sang trọng, mang lại trải nghiệm vô cùng cao cấp đồng bộ với macOS native.

## [1.3.8] - 2026-05-18

- **Cải tiến Cửa sổ Cài đặt (Settings View)**: Loại bỏ giới hạn chiều cao cố định của cửa sổ cài đặt, thiết lập tự động co giãn chiều cao động và hỗ trợ cuộn Form mượt mà để hiển thị đầy đủ, trực quan toàn bộ các tùy chọn tính năng mà không lo bị che khuất ở cạnh dưới.
- **Tối ưu hóa Menu Bar Dropdown**: Tái phân bổ và tổ chức lại các mục menu thành các section rõ ràng ngăn cách bởi các đường kẻ mờ:
  - **Section 1**: Chuyển nhanh bộ gõ Vi/En và chọn Kiểu gõ (Telex / VNI).
  - **Section 2**: Nút Cài đặt (Settings) và Toggle bật/tắt nhanh tính năng **Smart Switch** trực tiếp ngay trên menu bar với checkmark trạng thái trực quan (loại bỏ hoàn toàn toggle cấu hình lặp thừa trong các tab cài đặt chi tiết).
  - **Section 3**: Ủng hộ tác giả (Donate), Xem thông tin dự án, và Kiểm tra cập nhật qua Sparkle.
  - **Section 4**: Thoát ứng dụng.

## [1.3.7] - 2026-05-18

- **Giải pháp Cập nhật Trực tiếp (Sparkle Integration)**: Tích hợp framework Sparkle giúp tự động kiểm tra, tải về và cài đặt trực tiếp phiên bản mới mà không cần mở trình duyệt tải thủ công.
- **Bảo toàn Quyền Hệ thống (Accessibility)**: Thêm giao diện thông tin & hướng dẫn người dùng chi tiết cách xóa quyền cũ và cấp lại quyền mới cho vkey trong System Settings > Privacy & Security > Accessibility để đảm bảo bộ gõ hoạt động ổn định nhất sau khi nâng cấp.
- **Tự động sửa lỗi gõ nhầm (Auto Typo Correction)**: Bổ sung tính năng tự sửa các lỗi gõ nhầm dấu thanh sớm hoặc sai vị trí (ví dụ: `thfi` -> `thì`, `thfis` -> `thí`, `th2i` -> `thì`, `th1i` -> `thí`) và sửa gạch chữ đ cuối từ (ví dụ: `dinhjd` -> `định`, `dinh59` -> `định`, `dinh95` -> `định`), sửa hoán đổi nguyên âm (`veeitj` -> `việt`), hoán đổi phụ âm cuối (`phuowgn` -> `phương`) và cho phép phụ âm trung gian `g`.
- **Giao diện Cài đặt Chuyên nghiệp**: Thiết kế thêm các biểu tượng SF Symbols tinh tế (bàn phím, kính lúp, command, sparkles,...) trước tất cả các mục Cài đặt (Settings), mang lại trải nghiệm trực quan và đồng bộ như tuỳ chọn macOS gốc.
- **Tối ưu hóa Recovery**: Tinh chỉnh bộ lọc kiểm tra tiếng Việt (TiengVietValidator) giúp loại bỏ các trường hợp nhận diện nhầm từ tiếng Anh thông dụng (ví dụ: gõ `fair`, `same`, `force` giữ nguyên tiếng Anh bình thường).
- **Sửa lỗi khởi động (Hardened Runtime Fix)**: Khắc phục triệt để lỗi crash dyld/SIGABRT khi mở app do cơ chế bảo mật thư viện của Hardened Runtime chặn nạp Sparkle ad-hoc, giải quyết bằng entitlement `com.apple.security.cs.disable-library-validation` và viết build-phase script tự động ký đồng bộ Sparkle.

## [1.3.6] - 2024-05-18

- Đặt kích thước ảnh cờ VN và cờ US cố định `22x14` trên menu bar, khắc phục lỗi xê dịch các icon trên menu bar khi chuyển trạng thái tiếng Việt/Anh.
- Thêm Setting tuỳ chọn cách bỏ dấu: Kiểu cũ (hoà, thuỷ, khoẻ) hoặc Kiểu mới (hòa, thủy, khỏe).
- Tích hợp thêm tính năng Kiểm tra bản cập nhật mới (Update Checker) từ màn hình Setting.

## [1.3.5] - 2024-05-18

- Fixed the orientation of the star in the Vietnamese flag menu bar icon to point straight up.
- Fixed diacritic tone placement to use the "kiểu cũ" style (e.g. `hoà`, `thuỷ`, `khoẻ`) instead of "kiểu mới".

## 1.3.4 - 2026-05-18

- Fixed the menu bar state after onboarding so it switches from the setup guide menu to the main input menu immediately.
- Routed onboarding completion through `AppDelegate` so trusted session setup and menu state stay in sync.
- Made menu bar content observe app state changes after replacing Swift Observation macros with `ObservableObject`.

## 1.3.3 - 2026-05-18

- Fixed onboarding completion so the app finishes setup in the current session instead of relaunching and exiting.
- Ensured the event tap setup is idempotent to avoid duplicate hooks after completing onboarding.

## 1.3.2 - 2026-05-18

- Fixed CGEvent tap event forwarding to avoid retaining pass-through keyboard and mouse events.
- Fixed Telex `dd` handling so `đ` only toggles when `d` is typed immediately after an initial `d`.
- Fixed VNI `d9` handling so `đ` only toggles when `9` is typed immediately after an initial `d`.
- Disabled repeated-character based strategy auto-switching because it did not verify actual output failures.
- Made focused Accessibility text helpers use safe casts and the correct attribute types.
- Pinned KeyboardShortcuts to 1.9.4 to avoid SwiftUI preview macro failures in CLI builds.
