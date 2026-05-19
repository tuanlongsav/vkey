# vkey Changelog

> **Lưu ý về Bản quyền và Đóng góp (Credits & Attribution)**: Kể từ phiên bản v1.3.9 đến v1.5.0, vkey đã học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc từ các dự án mã nguồn mở **[Caffee](https://github.com/khanhicetea/Caffee)** của tác giả KhanhIceTea, **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen (@xmannv), **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** của tác giả Khaphan, và tích hợp bộ cơ sở dữ liệu từ điển 7.184 âm tiết tiếng Việt chuẩn từ dự án mã nguồn mở **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của tác giả Luông Hiếu Thi (@hieuthi). Từ **v1.5.0** ("Bilingual Reborn") còn tích hợp thêm nguồn dữ liệu Anh ↔ Việt từ **[English Wiktionary](https://en.wiktionary.org/)** qua [Wiktextract / Kaikki.org](https://kaikki.org) (CC BY-SA 4.0) và **[wordfreq](https://github.com/rspeer/wordfreq)** của Robyn Speer. Xem [`LICENSE-DATA.md`](LICENSE-DATA.md) để biết chi tiết license dữ liệu.

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
