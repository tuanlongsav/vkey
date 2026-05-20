# vkey Changelog

> **Lưu ý về Bản quyền và Đóng góp (Credits & Attribution)**: Kể từ phiên bản v1.3.9 đến v1.5.0, vkey đã học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc từ các dự án mã nguồn mở **[Caffee](https://github.com/khanhicetea/Caffee)** của tác giả KhanhIceTea, **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen (@xmannv), **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** của tác giả Khaphan, và tích hợp bộ cơ sở dữ liệu từ điển 7.184 âm tiết tiếng Việt chuẩn từ dự án mã nguồn mở **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của tác giả Luông Hiếu Thi (@hieuthi). Từ **v1.5.0** ("Bilingual Reborn") còn tích hợp thêm nguồn dữ liệu Anh ↔ Việt từ **[English Wiktionary](https://en.wiktionary.org/)** qua [Wiktextract / Kaikki.org](https://kaikki.org) (CC BY-SA 4.0) và **[wordfreq](https://github.com/rspeer/wordfreq)** của Robyn Speer. Từ **v1.6.1** bổ sung **[undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary)** của tác giả Vũ Anh (GPL-3.0) — tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN. Xem [`LICENSE-DATA.md`](LICENSE-DATA.md) để biết chi tiết license dữ liệu.

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
