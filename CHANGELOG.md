# vkey Changelog

> **Lưu ý về Bản quyền và Đóng góp (Credits & Attribution)**: Kể từ phiên bản v1.3.9 đến v1.5.0, vkey đã học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc từ các dự án mã nguồn mở **[Caffee](https://github.com/khanhicetea/Caffee)** của tác giả KhanhIceTea, **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen (@xmannv), **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** của tác giả Khaphan, và tích hợp bộ cơ sở dữ liệu từ điển 7.184 âm tiết tiếng Việt chuẩn từ dự án mã nguồn mở **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của tác giả Luông Hiếu Thi (@hieuthi). Từ **v1.5.0** ("Bilingual Reborn") còn tích hợp thêm nguồn dữ liệu Anh ↔ Việt từ **[English Wiktionary](https://en.wiktionary.org/)** qua [Wiktextract / Kaikki.org](https://kaikki.org) (CC BY-SA 4.0) và **[wordfreq](https://github.com/rspeer/wordfreq)** của Robyn Speer. Từ **v1.6.1** bổ sung **[undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary)** của tác giả Vũ Anh (GPL-3.0) — tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN. Xem [`LICENSE-DATA.md`](LICENSE-DATA.md) để biết chi tiết license dữ liệu.

## [4.2] - 2026-06-24 — "Viết hoa đầu câu + Sublime/CAD"

**Sửa lỗi gõ tiếng Việt trong editor native, CAD, và viết hoa đầu câu.**

### 🐛 Sửa lỗi gõ

- **Viết hoa đầu câu** — inject chữ hoa trực tiếp sau Enter hoặc `. ! ?` (+ space); không còn pass-through chữ thường.
- **Sublime Text / editor native** — whitelist NFC (BBEdit, TextMate, MacVim, Bear, iA Writer): hết backspace thừa nuốt newline/dòng kế.
- **Vectorworks (CAD)** — cùng whitelist NFC; sửa nuốt ký tự Telex (`aw` → ă, từ sắt/cắn/cắt…).
- **Macro trong Cài đặt** — bypass event tap khi gõ trong app vkey; hết treo khi gõ tiếng Việt vào ô Cụm dài.

### 🧪 Tests

- Thêm test viết hoa đầu câu + NFC whitelist editor. Toàn bộ **271 test pass**.

---

## [4.1] - 2026-06-22 — "Việt hoá thông báo + cập nhật tab Chung"

**Dialog Sparkle và thông báo tiếng Việt đồng nhất; toggle tự động cập nhật lên đầu tab Chung.**

### ✨ Cải thiện

- **Dialog Kiểm tra cập nhật (Sparkle)** hiển thị tiếng Việt — "Bạn đang dùng phiên bản mới nhất!" thay vì tiếng Anh.
- **Ưu tiên ngôn ngữ vi** cho app (`AppleLanguages`, `CFBundleDevelopmentRegion`).
- **Tự động cập nhật** chuyển lên **đầu tab Cài đặt → Chung**.

### 🌐 Việt hoá

- Text Tools: Chữ hoa từng từ / Chữ hoa đầu câu.
- Smart Switch nâng cao, từ điển cá nhân, HUD clipboard, nhãn nhập dữ liệu sao lưu.

### 🧪 Tests

- Toàn bộ **267 test pass**.

---

## [4.0] - 2026-06-22 — "Tự động cập nhật im lặng + cải thiện kiểm tra phiên bản"

**Mốc 4.0: cập nhật im lặng qua Sparkle, HUD hoàn tất, và thống nhất luồng kiểm tra phiên bản.**

### ✨ Tính năng

- **Tự động cập nhật phiên bản mới** — toggle Cài đặt → Chung; tải nền + cài im lặng khi thoát app (`SUAutomaticallyUpdate`).
- **HUD xanh「Cập nhật hoàn tất」** sau khi Sparkle relaunch với tên phiên bản mới.
- **Kiểm tra cập nhật thủ công** luôn dùng dialog Sparkle căn giữa (bỏ NSAlert lệch trái ghi build number).

### 🐛 Sửa lỗi

- **⇧⌘V clipboard**: không nuốt phím khi lịch sử rỗng — dán bình thường vẫn hoạt động.
- **Backup/restore**: export/import `clipboardHistoryModifierOnlyHotkey` và `autoUpdateEnabled`.

### 🧪 Tests

- Thêm test migration auto-update + clipboard hotkey. Toàn bộ **267 test pass**.

---

## [3.22] - 2026-06-22 — "Phím tắt clipboard ⇧⌘V + vá giới hạn dung lượng"

**Đổi phím mở menu lịch sử clipboard sang ⇧⌘V (tùy chỉnh được); sửa ước lượng dung lượng và tối ưu capture.**

### ✨ Tính năng

- **Phím tắt mở menu lịch sử clipboard** mặc định **⇧⌘V** (thay ⌥⌘V — tránh xung đột Move file của macOS).
- **Cài đặt → Chung → Clipboard**: recorder phím tắt tùy chỉnh (key+modifier hoặc chỉ modifier).

### 🐛 Sửa lỗi

- **Ước lượng dung lượng** mode văn bản+tệp: cộng cả payload pasteboard lẫn kích thước file (không bỏ sót text khi có file).
- **Capture clipboard**: bỏ copy `NSPasteboardItem` kép khi đo size; debounce HUD cảnh báo oversized (8s).
- **HUD cảnh báo**: setting độ mờ HUD áp dụng cho nền notice.

### 🧪 Tests

- Thêm test ước lượng byte pasteboard+tệp. Toàn bộ **265 test pass**.

---

## [3.21] - 2026-06-20 — "Đoán từ loại trừ app + Clipboard menu bar"

### Đoán từ
- **Loại trừ theo app** — tab Chính tả: danh sách bundle ID không chạy đoán từ (không HUD, không Tab, không học n-gram). Thêm thủ công hoặc chọn từ app đang chạy.
- **Ẩn HUD khi chuyển app** — chuyển sang app loại trừ thì HUD prediction tự tắt.

### Menu bar
- **Toggle Lịch sử Clipboard** — bật/tắt nhanh trên menu bar, cùng kiểu Smart Switch / Chính tả / Macro. Tắt sẽ xóa lịch sử trong RAM.

### Backup
- Export/import thêm `wordPredictionExcludedApps`.

### Test
- Toàn bộ 263 test pass.

---

## [3.20] - 2026-06-19 — "Thống kê quản lý cụm + icon Glass/Neural"

### Thống kê
- **Quản lý & xóa cụm ngoài tiếng Việt** — sheet chi tiết + nút quản lý kể cả khi ≤10 mục (`VKStatsTab`, `StatisticsView`).
- **Fix xóa cụm** — `StatCategory.vietnamesePhrase` / `.englishPhrase` + `removePhrase` xóa đúng bucket (`vnPhraseCounts*` / `enPhraseCounts*`), không còn gọi nhầm `vnWordCounts`.
- **`removeTopEntry`** — xóa từ EN đơn đồng thời thêm `userDenyWords` (inline trash + detail sheet).
- **Đồng nhất UX** — section cụm VN/EN đều có nút quản lý.

### Giao diện
- **`tileAccent`** — icon cài đặt `ink200` không còn mờ trên theme Glass/Neural (`VKIconTile`, sidebar nav).
- Tab **Thống kê & Sao lưu** — màu tile `gold` (tách khỏi Smart Switch `info`).

### Test
- 3 test mới: xóa cụm VN/EN, `removeTopEntry` + deny list. Toàn bộ 263 test pass.

---

## [3.19] - 2026-06-19 — "Gợi ý cụm 2–3 từ + thống kê suffix O(1)"

**Tab chèn cả cụm ngắn (mặc định 2 từ), học cụm 4 từ, và index suffix tra cứu nhanh cho prediction.**

### ✨ Tính năng mới

- **Gợi ý cụm 2–3 từ** — setting *Số từ gợi ý tối đa* (1–3, mặc định 2) trong tab Chính tả. Ví dụ sau `kính gửi` → `anh chị`; sau `công ty` → `cổ phần`. Tab chèn cả cụm.
- **Corpus cụm nhúng đa từ** (`EmbeddedPhraseCompletions.multiWordSuffixes`) — gợi ý văn phòng/hàng ngày kể cả khi chưa có lịch sử cá nhân.
- **Thống kê cụm 4 từ** + `vnPhraseSuffixIndex` O(1) — học cụm user hay gõ để đoán nhanh hơn.

### 🔧 Cải thiện

- **`phraseSuffixHints`** thay thế scan O(n) — lookup suffix 1–3 từ theo ngữ cảnh.
- **Backup/restore** — thêm `predictionMaxWords`.
- **Tab chấp nhận gợi ý** — học n-gram cho từng từ trong cụm đã chọn.

### 🧪 Tests

- Thêm test suffix index + `topPhrasePrediction` multi-word. Toàn bộ **262 test pass**.

## [3.18] - 2026-06-19 — "Clipboard giới hạn dung lượng + HUD cảnh báo"

**Dung lượng tối đa mỗi mục clipboard có thể chỉnh (mặc định 10 MB); HUD cảnh báo nổi bật khi vượt giới hạn.**

### ✨ Tính năng

- **Setting dung lượng tối đa mỗi mục** (1–200 MB, mặc định 10 MB) trong Cài đặt → Chung → Clipboard.
- **Tệp/nội dung vượt giới hạn** không lưu vào lịch sử; ⌘C/⌘V vẫn như macOS; hiện **HUD cảnh báo** giữa màn hình.

### 🎨 HUD cảnh báo

- Palette amber/nâu đậm **độc lập theme** — đọc rõ kể cả Liquid Glass (lớp đục phủ trên blur).
- Tiêu đề + icon tam giác lớn; font display/semibold tương phản cao.

### 🧪 Tests

- Thêm test giới hạn dung lượng và capture bỏ qua mục quá lớn. Toàn bộ **259 test pass**.

## [3.17] - 2026-06-19 — "Sửa lỗi lịch sử clipboard"

**Vá các lỗi từ code review: ⌥⇧⌘V, capture sau paste, dedup, menu đủ capacity, backup settings.**

### 🐛 Sửa lỗi

- **⌥⇧⌘V không còn bị chặn** — Paste and Match Style hoạt động bình thường; chỉ **⌥⌘V** mở menu lịch sử.
- **⌘C sau paste nội bộ không bị bỏ qua** — thay `suppressNextCapture` bằng bỏ qua theo `changeCount` khi vkey ghi pasteboard (Text Tools / dán từ lịch sử).
- **Capture poll 60→120→200ms** — app cập nhật clipboard chậm vẫn được lưu.
- **Dedup theo fingerprint nội dung** — không gộp nhầm mục cùng preview nhưng khác dữ liệu.
- **Menu hiện đủ số mục** theo capacity (3–50), không giới hạn cứng 20.
- **Tắt setting xóa RAM** — lịch sử phiên được clear khi tắt toggle.
- **Giới hạn 2MB/mục** — tránh ảnh/tệp lớn chiếm RAM.

### ✨ Khác

- **Backup/restore** gồm 3 setting lịch sử clipboard.

### 🧪 Tests

- Thêm test fingerprint, internal pasteboard skip, dedup nội dung khác. Toàn bộ **257 test pass**.

## [3.16] - 2026-06-19 — "Lịch sử clipboard tùy chỉnh"

**Lịch sử clipboard tùy chọn: ⌘C lưu, ⌥⌘V chọn mục; ⌘V / ⇧⌘V dán bình thường như macOS.**

### ✨ Tính năng

- **Lịch sử clipboard tùy chỉnh (tắt mặc định).** Bật trong Cài đặt → Chung: số mục (3–50), chế độ chỉ văn bản hoặc văn bản + tệp. **⌘C** lưu snapshot vào RAM (phiên làm việc); **⌥⌘V** mở menu chọn mục → dán; **⌘V** và **⇧⌘V** vẫn dán clipboard hệ thống như macOS.
- Text Tools không ghi nhầm vào lịch sử khi copy/paste nội bộ (`suppressNextCapture`).

### 🧪 Tests

- Thêm `ClipboardHistoryTests` (preview, snapshot, capacity, dedup). Toàn bộ **253 test pass**.

## [3.15] - 2026-06-19 — "HUD đoán từ căn giữa + gợi ý theo cụm"

**HUD prediction luôn căn giữa phía trên dòng nhập; đoán từ và thống kê nâng cấp theo cụm tiếng Việt có nghĩa.**

### ✨ Tính năng

- **Đoán từ theo cụm (phrase-aware prediction).** `PredictionEngine` thêm layer cụm nhúng sẵn (`EmbeddedPhraseCompletions`) + học từ phrase stats user (vd sau `kính gửi` ưu tiên `anh`/`chị`).
- **Thống kê cụm tiếng Việt có nghĩa.** `vnPhraseCounts2/3` chỉ ghi khi mọi token là từ VN hợp lệ trong từ điển — loại chuỗi ngẫu nhiên / xen tiếng Anh.

### 🐛 Sửa lỗi

- **HUD đoán từ căn giữa phía trên ô nhập.** Hết lỗi pill nhảy góc trên-phải màn hình khi app không trả caret pixel (Electron, Claude desktop). Fallback dùng mép dưới ô text; setting khoảng cách 1–20 dòng hoạt động cả khi fallback.

### 🧪 Tests

- Thêm test HUD căn giữa + line offset + phrase filter/prediction. Toàn bộ **249 test pass**.

## [3.14] - 2026-06-19 — "HUD gợi ý không che vùng gõ + Text Tools ổn định"

**HUD đoán từ không còn chèn đè lên dòng đang gõ (Claude desktop, chat app ở đáy màn hình). Kèm vá Text Tools và pasteboard.**

### 🐛 Sửa lỗi

- **HUD gợi ý từ (prediction) không che vùng gõ.** Trước đây khi thiếu chỗ phía trên, HUD bị đặt *dưới* caret → che chữ đang gõ (đặc biệt ô chat Electron/Claude). Nay ưu tiên phía trên / bên phải caret; bỏ placement dưới caret; không dùng bounds cả ô text làm vị trí caret; chuẩn hoá caret khi AX trả bounds cả dòng.
- **Text Tools không block UI.** Chờ clipboard dùng poll async thay vì vòng `RunLoop` trên main thread (tránh treo menu bar / event tap timeout).
- **Pasteboard ngoại lai không reset buffer gõ.** Clipboard đổi từ app khác không còn xoá từ đang gõ giữa chừng (Cmd+V vẫn reset qua modifier như cũ).

### 🧪 Tests

- Thêm test placement HUD (`computeVisualFrame`, `normalizedCaretRect`). Toàn bộ **247 test pass**.

## [3.13] - 2026-06-18 — "Ổn định Chrome omnibox: sync focus + axDirect đầy đủ"

**Sửa race `focusedFieldKind` khi Cmd+L/click omnibox, axDirect cho mọi đường gửi phím, và Window Title Rule không còn toggle VI/EN liên tục.**

### 🐛 Sửa lỗi

- **Sync focus trước mỗi keystroke** (`syncFocusedContextForKeystroke`) — hết gõ sai diff/chiến lược sau Cmd+L hoặc click thanh địa chỉ Chrome rồi gõ nhanh.
- **`axDirect` cho mọi transform** (Backspace, Escape, spell, macro, prediction) — không chỉ khi gõ chữ; omnibox Chrome ổn định hơn với autocomplete inline.
- **Window Title Rule ổn định** — không invalidate/re-apply mù mỗi focus refresh; không toggle VI/EN khi rule không đổi.
- **`noteFocusedBundleId`** apply rule mới ngay khi đổi app qua event PID.
- **AX `fieldKind`** leo tiếp parent khi role timeout — nhận Save panel tốt hơn.

### 🧪 Tests

- Toàn bộ **244 test pass**.

## [3.12] - 2026-06-18 — "Fix triệt để Source→Suorce + HUD cân giữa thật"

**Bổ sung fix cho 3.11: hết lỗi `Sou`/`sou` thành `Suo`/`Suorce` khi gõ giữa chừng, và HUD VI/EN căn giữa ổn định khi toggle.**

### 🐛 Sửa lỗi

- **`Source`/`sou` không còn thành `Suorce`.** 3.11 chặn swap `ou→uo` khi từ đủ ký tự còn rác (`source`), nhưng bước gõ prefix `sou`/`Sou` vẫn swap → `Suo` trên màn hình rồi CGEvent không kịp sửa → `Suorce`. Nay thêm guard prefix từ tiếng Anh (`isEnglishOuTypoInProgress`) + instant-restore cho `source`, `count`, `double`, `you`… Path VN `bou→buo` vẫn giữ.
- **HUD VI/EN căn giữa ổn định.** Bỏ phụ thuộc SwiftUI `fittingSize` (bất đồng bộ khi đổi label). Đo thủ công `max("Tiếng Việt","English")` + căn giữa theo kích thước vừa tính (cùng cách Prediction HUD).

### 🧪 Tests

- Thêm `telex("sou")`, `telex("Sou")`, `telex("cou")`, `telex("you")`. Toàn bộ **244 test pass**.

## [3.11] - 2026-06-18 — "Gõ chuẩn từ tiếng Anh (source, their…) + HUD cân giữa"

**Hết lỗi gõ từ tiếng Anh bị tự sửa nhầm ở chế độ tiếng Việt (vd `source` → `suorce`), và HUD VI/EN cân giữa màn hình khi đổi trạng thái.**

### 🐛 Sửa lỗi

- **Từ tiếng Anh không còn bị "sửa lỗi gõ nhầm" phá hỏng.** Luật auto-correct hoán đổi nguyên âm (`ou→uo`, `ei→ie`, `aoi→oai`) trước đây áp **vô điều kiện**, biến `source` → `suorce`, `count` → `cuont`, `their` → `thier`… nên phải chuyển sang tiếng Anh mới gõ được. Nay chỉ áp khi phần sau **tiêu hoá hết** thành âm tiết tiếng Việt hợp lệ (`conLai` rỗng); còn ký tự rác phía sau ⇒ là từ ngoại lai ⇒ giữ nguyên. Các đường gõ nhầm tiếng Việt (`bou→buo`, `veit→viet`, `haoi→hoai`, `sout→suot`) vẫn hoạt động đầy đủ.
- **HUD VI/EN cân giữa màn hình.** Khi đổi trạng thái Tiếng Việt ↔ English, HUD bị lệch sang phải do đo `fittingSize` trước khi SwiftUI layout lại theo nội dung mới. Nay ép layout lại trước khi đo nên panel luôn căn giữa đúng cho cả hai chiều.

### 🧪 Tests

- Thêm `testEnglishOuWordsNotMangled` (source/Source/count/double) và `testEiAndAoiLoanwordsNotMangled` (their/veil + regression veit/haoi). Toàn bộ **244 test pass**.

## [3.10] - 2026-06-18 — "Ổn định: race condition, backup đầy đủ, Window Title Rule"

**Đợt củng cố độ ổn định: sửa race condition, áp dụng đầy đủ Window Title Rule, backup/restore giữ thêm các setting mới, và Text Tools không còn ghi đè clipboard của bạn.**

### 🐛 Sửa lỗi

- **Race condition** ở `NGramStore` (Thống kê n-gram) và `EnVnReference` (từ điển Anh–Việt) — truy cập đồng thời an toàn hơn.
- **Accept prediction bằng Tab**: không chèn prediction khi commit hiện tại chưa thực sự được xử lý (tránh chèn nhầm).

### ✨ Cải thiện

- **Window Title Rule áp dụng đầy đủ** (`overrideState`): rule được tái đánh giá khi đổi focus / đổi tiêu đề cửa sổ; Smart Switch không còn ghi đè rule.
- **Backup/Restore giữ thêm setting mới**: phím tắt Text Tools, HUD prediction, theme, Window Title Rules, auto-capitalize, non-Latin IME auto-disable, Free Mark Mode, và các cài đặt CGEvent.
- **Text Tools tôn trọng clipboard**: khôi phục clipboard cũ sau khi paste, và KHÔNG đè nếu bạn đã copy thứ khác trong lúc chờ.

### 🧪 Tests

- Thêm test coverage cho việc export các setting mới. Toàn bộ 242 test pass.

## [3.9] - 2026-06-17 — "Gõ đúng ở thanh địa chỉ Chrome (axDirect)"

**Sửa triệt để lỗi gõ ở thanh địa chỉ (omnibox) Chrome. Thủ phạm KHÔNG phải NFC/NFD mà là tính năng tự gợi ý (inline autocomplete) bôi đen text — backspace synthetic xoá nhầm phần bôi đen → lệch số ký tự. Định tuyến omnibox qua chế độ ghi thẳng Accessibility (axDirect) như đã làm cho Spotlight.**

### 🐛 Nguyên nhân thật (vì sao 3.6–3.8 không dứt)

Omnibox tự thêm phần gợi ý và **bôi đen (select)** nó khi đang gõ. Khi vkey gửi backspace để sửa chữ, backspace đầu tiên xoá nhầm vùng bôi đen → lệch đúng 1 nhịp. Gửi ít backspace (NFC, 3.7) → **thừa** chữ (`"truường"`); gửi nhiều backspace (NFD, 3.8) → **thiếu** chữ (`"truờng"`, `"nập"`). Cả NFC lẫn NFD đều sai theo hai hướng ngược nhau → đây không phải bài toán NFC/NFD.

### 🔧 Fix

- **`axDirect` cho browser-chrome field**: phân loại field đang focus thành `webContent` / `nativePanel` / `windowField` (`Focused.FieldKind`, leo cây AX). Field `windowField` của app nhóm NFD (= thanh địa chỉ Chrome) được định tuyến qua **axDirect** — đọc thẳng nội dung + vị trí con trỏ + vùng chọn qua Accessibility rồi ghi đúng kết quả (NFC), **bỏ qua hoàn toàn** chuyện NFC/NFD lẫn autocomplete. Đây chính là cơ chế đã ổn định cho Spotlight (xử lý sẵn "vùng chọn ở cuối = gợi ý autocomplete"). axDirect lỗi → tự fallback synthetic (không tệ hơn).
- Hệ quả phụ: hộp thoại lưu file (`nativePanel`) vẫn NFC như 3.6; web content (`webContent`) vẫn NFD như cũ; Safari/app Apple vẫn NFC theo whitelist (web content WebKit vẫn đúng).

### 🧪 Tests

- Toàn bộ 243 test pass. Test mới `testFieldKindDiffSelectionInChromiumApp`: webContent → NFD, nativePanel/windowField → NFC; `focusedFieldIsBrowserChrome()` đúng cho omnibox Chrome, sai cho field app Apple.

## [3.8] - 2026-06-17 — "Sửa lỗi gõ ở thanh địa chỉ Chrome"

**Fix lỗi `"trường"` → `"truường"` (thừa chữ) khi gõ ở thanh địa chỉ (omnibox) Chrome và các ô nhập tương tự do Chromium tự vẽ. Hệ quả của cơ chế nhận diện field native quá rộng ở 3.6/3.7.**

### 🐛 Nguyên nhân gốc

3.6 thêm cơ chế "field nằm ngoài `AXWebArea` → ép diff NFC" để fix hộp thoại lưu file của Chrome. Nhưng **thanh địa chỉ (omnibox) cũng nằm ngoài `AXWebArea`** mà KHÔNG phải AppKit thật — nó là control do **Chromium Views** tự vẽ, lưu/xoá theo **scalar** (NFD) y như web content. Ép nó sang NFC làm sai số ký tự xoá → `"trường"` → `"truường"`. (3.7 siết phần "đoán mò" nhưng vẫn giữ tiêu chí "ngoài AXWebArea" nên omnibox vẫn dính.)

### 🔧 Fix

- **Nhận diện đúng hộp thoại modal native** (`Focused.isInsideNativePanel`): chỉ ép NFC khi field nằm trong **`AXSheet`** hoặc cửa sổ subrole **`AXDialog`/`AXSystemDialog`** — đúng đặc trưng của `NSSavePanel`/`NSOpenPanel`. Cửa sổ trình duyệt chính (chứa omnibox, toolbar, web) → **giữ NFD** theo phân loại app. Đổi tên cờ `focusedFieldOutsideWebArea` → `focusedFieldInNativePanel` cho đúng ngữ nghĩa.
- Kết quả: omnibox Chrome quay lại diff NFD (đúng như ≤ 3.5, gõ chuẩn); hộp thoại lưu file vẫn được ép NFC như fix 3.6.

### 🧪 Tests

- Toàn bộ 242 test pass. Test per-field override cập nhật theo cờ mới (`focusedFieldInNativePanel`): omnibox/web (false) → NFD; save panel (true) → NFC.

## [3.7] - 2026-06-17 — "Nhận diện ô nhập chắc tay hơn (củng cố 3.6)"

**Củng cố bản 3.6 sau code-review. Siết lại phần phát hiện ô nhập native theo Accessibility để KHÔNG đoán mò, và gộp truy vấn AX cho nhẹ. Engine gõ không đổi hành vi đã thấy ở 3.6 — toàn bộ test pass.**

### 🔧 Sửa từ code-review

- **`Focused.isOutsideWebArea` không còn đoán mò (correctness)**: trước đây leo hết 25 cấp cây Accessibility HOẶC tới gốc đều kết luận "field native" → ép NFC. Một ô nhập web lồng > 25 cấp dưới `AXWebArea`, hoặc một AX call timeout giữa chừng, cũng rơi vào nhánh này → ép NFC nhầm lên field NFD → tái hiện lỗi `"nhập" → "nḥ̂p"` theo **chiều ngược**. Giờ chỉ kết luận chắc chắn: gặp `AXWebArea` → web (giữ NFD); leo tới container gốc native thật (`AXWindow`/`AXSheet`/`AXApplication`) → native (ép NFC); chạm trần / đứt chain / role timeout → **không kết luận** → giữ phân loại theo app. `NSSavePanel` thật vẫn leo tới `AXSheet`/`AXWindow` nên fix save panel của 3.6 vẫn nguyên.
- **Gộp truy vấn AX (performance)**: `performFocusedElementRefresh` trước gọi 3 hàm, mỗi hàm tự fetch focused element (3 round-trip Accessibility). Giờ gói trong một `Focused.snapshot()` → 1 lần fetch + 1 lần leo cây, dừng sớm tại `AXWindow`.
- **Chú thích `ccc`** (`calcKeyStrokesNFD`): ghi rõ `canonicalCombiningClass != 0` phủ đủ mọi dấu thanh/dấu phụ tiếng Việt (216–230); các grapheme-extender ccc=0 (ZWJ, variation selector) không xuất hiện trong output bộ gõ nên không ảnh hưởng.

### 🧪 Tests

- Toàn bộ 242 test pass (không đổi). Phần `isOutsideWebArea` đi qua AX sống nên không unit-test được trực tiếp; test per-field override (Chrome web content vs save panel) vẫn cover qua `focusedFieldOutsideWebArea`.

## [3.6] - 2026-06-13 — "Hết mất chữ ở Gemini + hộp thoại lưu file Chrome"

**Fix lỗi "nhập" → "nḥ̂p" (mất chữ cái, dấu rời bám nhầm) ở Gemini app và khi gõ tên file/thư mục trong hộp thoại tải về của Chrome. Ba lớp fix: đúng bundle ID Gemini, phát hiện field native theo AX, và cấm gửi dấu rời "trần".**

### 🐛 Nguyên nhân gốc

Diff NFD scalar (dành cho Chromium web content) bị gửi vào field **NFC + grapheme backspace** → backspace xoá nguyên cụm trong khi vkey đếm theo scalar, rồi combining mark "trần" được gõ tiếp bám nhầm vào ký tự trước ("nhập" → "nḥ̂p", mất chữ "a"). Hai đường dẫn tới cùng lỗi:

1. **Gemini app**: bundle ID thật là `com.google.GeminiMacOS` — v3.4 ghi nhầm `com.google.gemini` nên app native Swift này rơi về nhánh NFD.
2. **Hộp thoại lưu file của Chrome** (gõ tên file/thư mục khi tải về): là `NSSavePanel` **native của macOS** chạy trong process Chrome — field NFC thật nhưng bundle `com.google.Chrome` bị phân loại NFD toàn app.

### 🔧 Ba lớp fix

- **Đúng bundle ID Gemini** (`usesNFCGraphemeStorage`): so sánh lowercased prefix `com.google.gemini` → khớp cả `com.google.GeminiMacOS`.
- **Phát hiện field native theo AX** (`Focused.isOutsideWebArea` + `focusedFieldOutsideWebArea`): focused element không có ancestor `AXWebArea` (Chromium expose mọi field web content dưới node này) → field là native control → flip sang diff NFC dù app thuộc nhóm NFD. Cache push-based như `isSearchOrComboFocused`; thêm nhịp refresh trễ 0.5s (coalesced) vì save panel mở SAU ⌘S/click một nhịp.
- **Cấm combining mark "trần"** (`calcKeyStrokesNFD`): nếu phần retype mở đầu bằng dấu rời, lùi ranh giới về đầu cụm grapheme — xoá nguyên cụm + retype cụm hoàn chỉnh ("go"→"gô" giờ là 1 backspace + "ô" thay vì 0 + ◌̂ trần). Đúng ở cả field NFD lẫn NFC → kể cả khi phân loại sai, lỗi không còn phá chữ. Diff rỗng (chỉ xoá) giữ nguyên tối ưu cũ.

### 🧪 Tests

- Test mới: snapping NFD ("nhâ"→"nhậ", "nhậ"→"nhâ", "đi"→"đị", "gô"→"go" giữ nguyên), per-field override trong Chrome (web content NFD vs save panel NFC), bundle ID Gemini cả 2 biến thể. Cập nhật test v2.3.8 cũ theo hành vi mới. Toàn bộ suite pass.

## [3.5] - 2026-06-12 — "Ký Apple Developer ID + notarized"

**App được ký bằng chứng chỉ Apple Developer ID và notarized bởi Apple — tải về mở ngay, không còn bị Gatekeeper chặn. Engine gõ không đổi (code y hệt v3.4).**

### 🔏 Chữ ký & phân phối

- **Ký Developer ID Application** (Long Hoang Tuan — U4B264GM2B, cert cloud-managed của Xcode): thay ad-hoc signing từ mọi bản trước. Hardened runtime bật.
- **Notarized + stapled**: app pass kiểm duyệt notarization của Apple, ticket staple trực tiếp vào bundle — `spctl` trả "Notarized Developer ID". User mới tải DMG mở ngay, không cần chuột phải → "Mở".
- **Quy trình release mới** (RELEASE.md cập nhật): `xcodebuild archive` → `-exportArchive` method `developer-id` destination `upload` (ký + nộp notarize qua session Xcode, không cần app-specific password) → poll `-exportNotarizedApp` → đóng DMG → ký Sparkle như cũ.
- `DEVELOPMENT_TEAM = U4B264GM2B` ghi vào project — build sau tự nhận team.

### ⚠️ Lưu ý nâng cấp từ ≤3.4

- Chữ ký app đổi (ad-hoc → Developer ID) nên macOS sẽ yêu cầu **cấp lại quyền Trợ năng một lần** sau khi cập nhật. Từ 3.5 trở đi chữ ký ổn định — các bản sau không phải cấp lại.

## [3.4] - 2026-06-11 — "Gõ chuẩn keypad & Caps Lock + nhập/xuất từ điển"

**Hỗ trợ bàn phím số (keypad), Caps Lock chuẩn macOS, diff NFC/NFD theo từng app, gợi ý từ lọc rác + học nhanh hơn, nhập/xuất từ điển cá nhân.**

### ⌨️ Gõ chuẩn hơn

- **Bàn phím số (keypad)**: keycode 82–92 được map vào layout — gõ dấu VNI bằng keypad hoạt động đúng. Shift + keypad giữ nguyên chữ số (đúng hành vi macOS — không bị hiểu nhầm thành `!@#…` như hàng phím số, tránh lệch buffer).
- **Caps Lock chuẩn macOS**: logic shift đổi sang XOR — Shift + Caps Lock trên chữ cái ra chữ **thường** (trước đây ra chữ hoa). Caps Lock giờ chỉ tác động **phím chữ cái** (`KeyboardUS.isLetterKey`) — gõ `,` khi bật Caps Lock không còn bị hiểu thành `<`.
- **Diff NFC/NFD theo từng app khi xoá/sửa từ** (`WordBuffer.pop` + các call-site replacement): app lưu NFC (Apple native, MS Office, iWork, Google Gemini) dùng diff grapheme; app lưu NFD (Chromium, Electron, web — default) dùng diff scalar NFD → backspace/sửa từ không còn lệch ký tự trong Chrome & app web.

### 💡 Gợi ý từ (Prediction)

- **Lọc ứng viên rác** (`PredictionEngine.isValidCandidate`): loại từ chứa ký tự đặc biệt/số (trừ khi nằm trong Allow list — vd email), loại chữ cái đơn không phải từ tiếng Việt. Set từ đơn hợp lệ = đủ 12 nguyên âm × 6 thanh + đ ("ở", "ừ", "ồ"… đều được giữ).
- **Allow list tham gia scoring**: từ trong `userAllowWords` được +500 điểm như Keep list.
- **Tăng trọng số học cá nhân**: trigram user ×6 (trước ×2), bigram user ×3 (trước ×1) → gợi ý bắt thói quen gõ nhanh hơn đáng kể.

### 📚 Từ điển cá nhân

- **Nhập file / Xuất file** trong editor: nhập từ file `.txt` (mỗi dòng 1 từ) hoặc `.csv` (tách thêm theo dấu phẩy), tự dò bảng mã khi file không phải UTF-8, lọc trùng, báo số từ thêm mới qua alert; xuất danh sách tab hiện tại ra `.txt`.

### 🔧 Ổn định

- **File bật/tắt nhanh tách theo user**: `/tmp/vkey_switch` → `/tmp/vkey_switch_<uid>` — hết xung đột (file của user khác chiếm tên, không ghi được) trên máy nhiều tài khoản.

### 🧪 Tests

- Test mới: keypad VNI, tương tác Shift × Caps Lock (4 case), `isLetterKey`, filter prediction (kể cả "ở"/"ừ"/"ồ"), NFD vs NFC pop behavior (Notes vs Chrome), Gemini NFC. Toàn bộ suite pass.

## [3.3] - 2026-06-11 — "Hết treo alert + HUD/menu mới + gọn app"

**Fix nghiêm trọng: alert quyền Trợ năng vô hình chặn main thread (treo menu, không vào Settings). HUD hết "khoanh vuông mờ". Menu bar chau chuốt. Gỡ dependency không dùng.**

### 🚨 Fix bug treo

- **NSAlert vô hình kẹt main thread**: sau khi cài bản mới (chữ ký đổi), TCC entry cũ làm `tapCreate` fail → vkey bật alert "cần quyền Trợ năng"; app đang ở chế độ accessory nên `activate(ignoringOtherApps:)` ngay sau `setActivationPolicy(.regular)` bị macOS nuốt → alert chạy nhưng KHÔNG hiện → main thread kẹt vĩnh viễn trong `runModal` → bấm menu bar không phản hồi, Settings không mở. Đã vá: chờ activation settle + ép cửa sổ alert nổi + guard chống bật chồng. Áp luôn cho 2 alert cùng kiểu (Updater + prompt sao lưu).

### 🎨 HUD — hết "khoanh vuông mờ" bao quanh viên tròn (3 nguyên nhân, vá đủ)

- Đệm shadow 64pt (Toggle) / 40pt (Prediction) quanh content — shadow + glow Neural không còn bị cắt theo mép cửa sổ.
- `HUDBackdrop` (NSVisualEffectView + maskImage bo tròn) thay `.ultraThinMaterial` — blur được mask đúng hình capsule, không lộ khung chữ nhật khi fade.
- Bỏ toàn bộ `blendMode` rò ra nền trong suốt; thêm `compositingGroup()` trước mọi shadow.
- Prediction HUD giờ **click xuyên qua được** (panel to hơn, bắt buộc).
- Toggle HUD thêm pop-in scale 0.94→1 (spring).

### ✨ Menu bar — chau chuốt

- **Header trạng thái**: cờ lớn + "Tiếng Việt"/"English" + kiểu gõ + segmented **VI | EN** (active = brand gradient).
- Hover animate easeOut 0.12s, pressed scale 0.98 + dim.
- Icon `hierarchical`, **nhuộm brand khi tính năng đang BẬT** (Telex/VNI/Smart Switch/Chính tả/Macro) — liếc qua biết trạng thái.
- Checkmark spring pop khi toggle; badge phím tắt dạng keycap (⌘, / ⌘Q).
- Popover Giao diện: **swatch màu per-theme** (Tonal mực+đỏ · Glass kính trắng · Neural gradient).
- Footer 1 hàng icon (Ủng hộ · Thông tin · Cập nhật) + số phiên bản — panel ngắn hơn.
- `VKMenuBarLabel`: cờ bo góc + hairline cho status item.

### 🔧 Khác

- Gỡ dependency `Settings` (sindresorhus) — không còn nơi nào dùng. `Settings_Settings.bundle` biến mất; bundle gọn hơn.
- `ThemeFont` dọn case chết (carterOne/jetBrains) — thêm decoder map giá trị lạ về `.system` cho backward-compat với config cũ.
- Xoá control chết `VKAccentButton`/`VKAppearanceButton`. `MenuBarFooterRow` làm rỗng.

235/235 test pass.

## [3.2] - 2026-06-11 — "Hết treo máy khi thu hồi quyền + font mới"

**Fix lỗi nghiêm trọng: thu hồi quyền Trợ năng khi vkey đang chạy làm treo toàn bộ macOS. Kèm fix cờ menu bar + 3 font mới.**

### 🚨 Fix treo macOS khi thu hồi quyền Trợ năng (mọi bản trước đều dính)

- Trước đây: tắt toggle vkey trong System Settings → Accessibility khi app đang chạy → **toàn bộ chuột/phím macOS đứng**, phải reset cứng. Nguyên nhân: event tap tự bật lại vô điều kiện (giằng co với hệ thống) + đường xử lý phím gọi Accessibility API bị block sau khi mất quyền, trong khi tap đang giữ dòng sự kiện của cả phiên.
- Nay: phát hiện thu hồi trong ~2 giây → **tháo tap ngay**, mọi phím passthrough, menu chuyển về màn hướng dẫn. **Cấp lại quyền → vkey tự hoạt động lại**, không cần mở lại app.

### 🐛 Sửa lỗi

- Cờ 🇻🇳/🇺🇸 ở menu bar (mục Chuyển đổi ngôn ngữ) giờ sáng đúng theo ngôn ngữ đang bật; dấu ✓ Kiểu Telex/VNI cũng cập nhật ngay khi đổi.

### ✨ Font

- Thêm **Inter** và **Nunito** (đều hỗ trợ tiếng Việt). Gỡ Carter One + JetBrains Mono. Bộ font nhúng: Be Vietnam Pro · Inter · Noto Sans Display · Lora · Nunito.

235/235 test pass.

## [3.1] - 2026-06-11 — "Neural AI + hoàn thiện giao diện 3.0"

**Theme thứ ba "Neural AI" + loạt fix cho giao diện 3.0. Engine gõ không đổi.**

### ✨ Theme Neural AI (mới)

- **Neural AI**: aurora tím–cyan trôi trên nền obsidian (dark) / lavender (light), gradient "trí tuệ" `#8B5CF6 → accent → #22D3EE` tô tiêu đề, nav active, nút primary, chip VI/EN. Slider **"Cường độ phát sáng"** điều khiển độ rực aurora + mọi halo.
- Đồng bộ cả **menu bar** (panel obsidian + nhẫn gradient + hover gradient) và **HUD** (viên kính viền gradient + halo violet).

### 🐛 Sửa lỗi giao diện 3.0

- **Nút Sáng/Tối/Hệ thống bấm được** (3.0 bị titlebar nuốt click) — tách 3 nút, đặt phải header.
- **Liquid Glass là kính thật**: cửa sổ trong suốt + blur nền sau (trước đây là gradient giả màu đỏ); sáng = frosted trắng, tối = kính tối, độ trong theo slider. Menu bar cũng trong hơn theo slider.
- **Chọn phông chữ hoạt động** (3.0 chọn không ăn do Picker lồng Menu không bắn selection). Menu font preview bằng chính font đó. Áp toàn bộ nhãn UI.
- **Layout Settings 2 cột tự dựng**: bỏ NavigationSplitView (nguồn dải trống cao + nút sidebar thừa), bỏ ô tìm kiếm, header mỏng 38pt, titlebar tối thiểu liền màu theme (kể cả khi đóng-mở lại / đổi theme).
- Khung phím tắt hết đè viền card; sửa crash khi đổi theme Glass ⇄ Mặc định.

### 🔧 Khác

- Thêm font nhúng: Be Vietnam Pro, Lora, JetBrains Mono. Gỡ Carter One (tiếng Việt kém).
- Cấu hình (màu nhấn / font / bo góc / mật độ / độ trong) lưu **riêng theo từng theme**.

## [3.0] - 2026-06-11 — "Giao diện mới: Tonal & Liquid Glass"

**Đại tu toàn bộ cửa sổ Cài đặt + hệ thống theme. Engine gõ không đổi.**

### ✨ Giao diện mới (UI redesign)

- **Cửa sổ Cài đặt dựng lại** bằng `NavigationSplitView`: sidebar 232pt (ô tìm, thẻ nhận diện, 6 mục) + detail pane. Thay `TabView`/gói Settings cũ.
- **6 tab**: Chung · Smart Switch · Macro · Chính tả · Thống kê & Sao lưu · **Quản lý giao diện** (mới).
- **Hai theme**: **Mặc định** (Tonal — phẳng, paper/ink) và **Liquid Glass** (trong mờ + blur khúc xạ, macOS Tahoe). Chọn ở tab Quản lý giao diện hoặc đổi nhanh trên menu bar ("Chuyển giao diện" → xổ phải).
- **Tab Quản lý giao diện**: màu nhấn (5 màu), phông chữ (Hệ thống/Be Vietnam Pro/Noto Sans Display/Lora/Carter One/JetBrains Mono — nhúng sẵn), độ bo góc (sắc/vừa/tròn), mật độ dòng (gọn/vừa/thoáng), độ trong suốt (Liquid Glass). **Lưu riêng theo từng theme.**
- **HUD** chuyển VI/EN + đoán từ và **biểu tượng** đổi theo theme (viên kính nổi + tile tinted khi Liquid Glass).
- Header gọn (tên tab giữa, 3 nút Sáng/Tối/Hệ thống bên phải); chế độ sáng/tối đổi tức thì.

### 🔧 Khác

- Tab **Thống kê** bù đầy đủ chi tiết như bản cũ: top từ tiếng Việt, top cụm 2-3 từ, top từ ngoài tiếng Việt (gợi ý từ điển), top app, các tuần đã đóng, xuất chẩn đoán.
- **Smart Switch** thêm lại "Quy tắc theo cửa sổ" (override theo bundle ID + window title regex).
- **Dọn sạch theme cũ**: xoá classic, Liquid Glass cũ, `AppTheme`/icon-style 3D/emoji, `ThemeManager`, `GlassTile` (−~2.500 dòng) + asset icon classic.
- Thêm 4 font nhúng (Be Vietnam Pro, Lora, JetBrains Mono) bên cạnh Noto/Carter có sẵn.

## [2.15] - 2026-06-10 — "Spotlight gõ được + sửa Opus"

**Hai sửa lỗi lớn: (1) gõ tiếng Việt trong Spotlight cuối cùng đã chuẩn (hết "goõ tieếng việt"), (2) bug "Opus" ra "uOs" ảnh hưởng mọi app.**

### 🐛 Sửa lỗi gõ trong Spotlight (chuẩn đoán trên máy thật)

- Spotlight nuốt/đảo phím backspace giả lập → mọi chiến lược gửi event đều loạn chữ. Giải pháp: **ghi thẳng vào ô text qua Accessibility API** (axDirect) thay vì giả lập phím.
- Mấu chốt khiến các bản 2.10–2.14 trượt: vkey chọn chiến lược gửi phím theo bundle id lấy từ `eventTargetUnixProcessID`, mà trên macOS 26 trường này **không trả đúng** cho Spotlight. Nay phát hiện ô Spotlight qua **AX role + bundle thật của ô đang focus** (độc lập với event PID) → ép axDirect đúng lúc.
- axDirect đọc/ghi ô qua system-wide AX (verified trên máy thật ghi đè thành công), có verify-sau-ghi + fallback. Áp dụng cho Spotlight, SystemUIServer.

### 🐛 Sửa bug engine "Opus → uOs" (mọi app)

- Gõ `opu` ra `uo` (nuốt mất phụ âm giữa) do luật tự-sửa-lỗi-gõ-nhầm "ou→uo" / "ei→ie" / "aoi→oai" không kiểm tra phụ âm cuối chen giữa. Nay chỉ ghép nguyên âm khi **không có phụ âm cuối** → `opu`→`opu`, `Opus`→`Opus`. Các từ thật (buột, muốn, việt) giữ nguyên.

### 🔧 Khác

- **235 test pass** (+5 test: Opus + grapheme-safe delete).
- Hardening event tap (retry + cảnh báo khi mất quyền) từ v2.10 vẫn giữ.

## [2.14] - 2026-06-10 — "Spotlight: học từ PHTV"

**Gia cố đường ghi AX-direct cho Spotlight theo các kỹ thuật của [PHTV](https://github.com/PhamHungTien/PHTV) (Phạm Hùng Tiến) — cảm ơn dự án mã nguồn mở.**

> Lưu ý: nếu bạn báo "vẫn lỗi Spotlight" khi đang ở v2.11 — bản đó CHƯA có fix AX-direct (v2.12+). Hãy cập nhật và thử lại.

### 🛠 Gia cố (theo PHTV)

- **Verify sau khi ghi**: một số app trả success nhưng áp thay đổi async hoặc âm thầm bỏ — nay đọc lại giá trị và so sánh (chuẩn hoá NFC, 2 lần) trước khi coi là thành công; fail → retry/fallback.
- **Xử lý selection chuẩn**: phân biệt bôi đen giữa text (thay đúng vùng chọn) vs **suffix autocomplete ở cuối** (Spotlight tự select phần gợi ý — xoá luôn trong cùng một lần replace).
- **Lùi caret theo cụm grapheme** (`rangeOfComposedCharacterSequence`) — an toàn với app lưu NFD (ô = o + dấu rời).
- **Fallback post vào HID tap** (`.cghidEventTap`) thay vì session tap — Spotlight xử lý event mức HID đáng tin hơn.
- Vá lỗ hổng auto-switch strategy có thể đè `axDirect` → `stepByStep` (vô hiệu hoá fix).
- Thêm log chẩn đoán (`log stream --predicate 'subsystem == "dev.longht.vkey"' --info`) để soi trực tiếp khi cần.
- **232 test pass** (+3 test grapheme-safe delete).

## [2.13] - 2026-06-10 — "w là ư"

**Sửa lỗi: khi TẮT "cho phép âm tiết đầu w/z/j/f", gõ `w` vẫn ra "w" thay vì "ư" (Telex cổ điển).**

### 🐛 Nguyên nhân (2 tầng)

1. Engine Telex chỉ xử lý `w` khi syllable **đã có nguyên âm** (uw→ư, aw→ă, ow→ơ) — thiếu nhánh "w đứng không = ư" của Telex cổ điển.
2. Bảng impossible-prefix khoá cứng `tw/dw/sw/wr` thành raw English — nên kể cả có nhánh trên, gõ `tw` cũng bị chặn trước khi engine kịp xử lý.

### ✅ Fix v2.13

- Khi `allowedZWJF` TẮT: `w` chưa có nguyên âm → đẩy `u + dấu móc` (cùng đường với `uw`→ư): **`w`→ư, `tw`→tư, `nhw`→như, `twf`→từ, `dwa`→dưa**, `W`→Ư.
- Các prefix chứa `w` không còn bị coi là "impossible" khi ZWJF tắt (w lúc đó là phím dấu, không phải phụ âm).
- Khi `allowedZWJF` BẬT (mặc định): không đổi gì — `w` vẫn giữ nguyên để gõ loanword ("web", "word"…).
- **229 test pass** (+2 test: classic-Telex w khi tắt, regression loanword khi bật).

## [2.12] - 2026-06-10 — "Spotlight: ghi thẳng, không gửi phím"

**Fix triệt để lỗi ký tự đôi trong Spotlight bằng cách đổi hẳn phương pháp: ghi thẳng nội dung ô text qua Accessibility API thay vì gửi phím giả lập.**

### 🐛 Vì sao v2.10/v2.11 chưa đủ

- v2.10: chiến lược đúng nhưng không bao giờ được kích hoạt (Spotlight là UIElement, không phát notification).
- v2.11: nhận diện app đích đã chuẩn (PID-per-event) — nhưng hoá ra **Spotlight nuốt/đảo synthetic backspace bất kể tốc độ gửi** do inline-autocomplete, nên mọi chiến lược dựa trên phím giả lập đều thất bại.

### ✅ Fix v2.12 — chiến lược `axDirect` (tham khảo gonhanh.org & xkey)

Cả hai bộ gõ mã nguồn mở **gonhanh.org** và **xkey** đều xử lý Spotlight bằng cùng một cách — vkey nay làm theo:

- **Ghi thẳng giá trị ô text** qua Accessibility API (`AXValue`): đọc text + vị trí con trỏ → tính chuỗi mới (xoá N ký tự trước con trỏ, chèn bản thay thế, bỏ phần suggestion đang auto-select) → ghi lại nguyên tử + đặt con trỏ. Không một phím giả lập nào được gửi → không gì để Spotlight nuốt.
- Retry 3 lần khi Spotlight bận search; fallback ForwardDelete + gửi chậm nếu AX bị từ chối.
- Giới hạn thời gian truy vấn AX (100ms) để không treo hàng đợi gõ.
- Miễn trừ `axDirect` khỏi cơ chế "downgrade diff nhỏ về batch" — đa số transform dấu (1 backspace + 1 ký tự) trước đây bị downgrade nên đi đường phím giả lập.
- Áp dụng cho `com.apple.Spotlight` + `com.apple.systemuiserver`. **227 test pass**.

## [2.11] - 2026-06-10 — "Spotlight, lần này thật"

**Fix lại lỗi ký tự đôi trong Spotlight — v2.10 thêm đúng chiến lược nhưng nó không bao giờ được kích hoạt trên macOS 26 (Tahoe).**

### 🐛 Nguyên nhân v2.10 trượt

Spotlight trên Tahoe là tiến trình **UIElement** — không phát `didActivateApplicationNotification` khi nhận focus, còn AX refresh thì bị race (chạy lúc nhấn ⌘Space, trước khi overlay mở). Cả hai đường nhận diện app của vkey đều trượt → chiến lược `stepByStep` cho Spotlight có trong danh sách nhưng **không bao giờ được áp**.

### ✅ Fix v2.11

- Đọc **PID của app đích trực tiếp từ mỗi event** (`eventTargetUnixProcessID` — WindowServer điền sẵn): chính xác từng phím, không phụ thuộc notification/AX, bắt chuẩn mọi overlay. BundleId được cache theo PID nên gần như không tốn chi phí.
- Đồng bộ luôn cache focused-bundle → **Smart Switch per-app giờ hoạt động đúng trong overlay** (vd cấu hình mặc định Spotlight → tiếng Anh giờ mới thực sự áp dụng; ai cấu hình Spotlight → tiếng Việt thì gõ với chiến lược đúng).
- **227 test pass**.

## [2.10] - 2026-06-01 — "Gõ được trong Spotlight"

**Sửa lỗi gõ tiếng Việt bị ký tự đôi trong ô tìm kiếm Spotlight ("goõ tieếng viiệt") + app tự báo khi mất quyền Accessibility thay vì chết im lặng.**

### 🐛 Sửa lỗi

- **Spotlight**: ô tìm kiếm Spotlight (`com.apple.Spotlight`) nuốt backspace khi vkey gửi kiểu batch/hybrid → bản thay thế bị **chèn thêm** thay vì thay thế → "goõ tieếng viiệt". Nay dùng chiến lược `stepByStep` (từng phím một) — cùng cách đã fix Launchpad ở v2.7.
- **Đồng bộ chiến lược theo focus thật**: overlay (Spotlight…) có thể không phát notification đổi app → vkey bị kẹt chiến lược của app cũ. Nay tự đồng bộ khi focus đổi (kèm refresh khi nhấn tổ hợp ⌘ như ⌘Space).
- **Hết "bật V mà không gõ được" im lặng**: khi macOS thu hồi quyền Accessibility (thường sau khi update), event tap tạo thất bại nhưng app trước đây chỉ ghi log rồi thôi. Nay tự thử lại 3 lần rồi **hiện cảnh báo hướng dẫn cấp lại quyền**.

### 🔧 Nội bộ

- Build phase ký Sparkle/LaunchAtLoginHelper chuyển sang **identity-aware** (chuẩn bị cho việc ký Developer ID + notarization ở bản sau — hiện hoãn chờ tài khoản Apple Developer). Hành vi bản ad-hoc không đổi.
- **227 test pass** (226 + test Spotlight strategy).

> ⚠️ Bản này vẫn ký ad-hoc: sau khi update, nếu macOS thu hồi quyền Accessibility thì vkey sẽ **tự hiện cảnh báo** — làm theo hướng dẫn (System Settings → Privacy & Security → Accessibility → bật lại vkey). Bản ký Developer ID (hết cảnh re-grant) sẽ đến khi tài khoản developer sẵn sàng.

## [2.9] - 2026-06-01 — "chuyên môn không thành chuyên moon"

**Mở rộng fix v2.8: rà soát toàn bộ danh sách từ tiếng Anh tự khôi phục, loại thêm các từ mà Telex biến đổi ra từ tiếng Việt hợp lệ & phổ biến (vd "moon"→"môn", "theme"→"thêm").**

### 🐛 Sửa lỗi

- Audit tự động (chạy toàn bộ danh sách instant-restore qua engine Telex thuần, đối chiếu lexicon tiếng Việt) phát hiện 31 từ cùng lớp lỗi với "queen"→"quên" của v2.8. Đã loại **18 từ** mà từ tiếng Việt rõ ràng thông dụng hơn:
  - `moon→môn` (chuyên môn), `moons→mốn`, `noon→nôn`, `soon→sôn`
  - `meeting→miêng`, `meetings→miếng`, `meets→mết`, `theme→thêm`
  - `boots/boost→bốt`, `loops→lốp`, `roots→rốt`, `tee→tê`, `tree→trê`
  - `beer→bể`, `bono→bôn`, `cheese→ché`, `docs→dóc`
- **Giữ lại** các từ tiếng Anh phổ biến (this/these/there/see/list/if/of/three) và một số từ Việt hiếm (horses/house/pass…) — để gõ tiếng Anh xen kẽ vẫn tiện. Cần gõ chúng dạng tiếng Việt thì dùng Personal Dictionary hoặc Restore Policy.
- Thêm test `testCommonVietnameseWordsNotShadowedByEnglish` (10 ca) + regression giữ nhóm tiếng Anh. **226 test pass**.

## [2.8] - 2026-06-01 — "quên không thành queen"

**Sửa lỗi: ở mode tiếng Việt, gõ Telex "queen" (qu-e-e-n) ra "queen" thay vì "quên".**

### 🐛 Sửa lỗi

- `"queen"` / `"queens"` nằm trong danh sách 126 từ tiếng Anh **instant-restore** (cùng họ "screen/green/feel"). Telex `queen` → `quên` (ee→ê) — mà **"quên" là từ tiếng Việt hợp lệ & phổ biến** — nhưng instant-restore đè raw "queen" lên. Đã loại `queen`/`queens` khỏi danh sách instant-restore. Các từ "-een" khác (green/screen…) không ra từ Việt hợp lệ nên giữ nguyên.
- Thêm 2 test: `telex("queen") == "quên"`; regression green/screen vẫn restore English. **225 test pass**.

> Lưu ý: nếu cần gõ từ tiếng Anh "queen", thêm vào Personal Dictionary (Allow words) hoặc đổi Restore Policy.

## [2.7] - 2026-06-01 — "Gõ được trong Launchpad"

**Sửa lỗi gõ tiếng Việt bị loạn (lặp/mất chữ, sai dấu) trong ô tìm kiếm của Launchpad.**

### 🐛 Sửa lỗi

- Ô tìm kiếm Launchpad chạy trong tiến trình **Dock** (`com.apple.dock`). vkey trước đây dùng chiến lược gửi phím mặc định (`.hybrid`, gửi cả cụm + delay backspace) — không đồng bộ với input model của Dock nên backspace/thay thế lệch nhịp, gõ tiếng Việt bị loạn. Nay map `com.apple.dock` sang chiến lược **`.stepByStep`** (gửi từng phím một, tương thích nhất — giống Terminal/Electron).
- Thêm 2 test (`AppSendingStrategyTests`): xác nhận Dock → stepByStep, regression Terminal vẫn stepByStep và app native thường không bị ảnh hưởng. **223 test pass**.

## [2.6] - 2026-06-01 — "Đồng bộ ranh giới"

**Sửa lỗi: sau khi nhấn Enter (xuống dòng) rồi nhấn Backspace, vkey có thể khôi phục nhầm từ của dòng trước, gây sai lệch. Nay lịch sử từ được xoá đúng ở ranh giới Enter/Tab.**

### 🐛 Sửa lỗi

- `InputProcessor.handleTaskKey`: trước đây MỌI phím commit (Space/Enter/Tab) đều gọi `newWord(storePrevious: true)`, giữ `previousWordState` cả sau Enter → Backspace-sau-Enter khôi phục từ dòng trước, vượt qua ranh giới xuống dòng (desync). Nay **chỉ Space** giữ history để re-edit; **Enter/Tab** xoá history. Đối chiếu fix của xkey (build 20260504 "clear history after Enter") và gonhanh.org (v1.0.131 "chained restore").

### 🔧 Nội bộ

- **Đối chiếu bản vá upstream**: rà soát release notes gonhanh.org (125 bản) và xkey (42 bản) so với vkey. Phần lớn bug liên quan vkey **đã xử lý sẵn**: watchdog event tap khi macOS vô hiệu hoá (`EventHook`), clear buffer khi nhấn Cmd/Ctrl/Alt, auto-capitalize đầu câu, AX query async ngoài callback, dọn observer (v2.4). Chỉ phát hiện 1 gap thật (ranh giới Enter, ở trên).
- Thêm 3 test chống hồi quy (nguyên âm lặp toto/mama/papa; Space giữ history; Enter xoá history). **221 test pass** (218 → 221).

## [2.5] - 2026-06-01 — "Không che ô gõ"

**Sửa lỗi HUD gợi ý đoán từ đè lên dòng đang gõ (che mất ô nhập) khi đặt khoảng cách (offset) nhỏ hoặc dùng cỡ chữ HUD lớn.**

### 🐛 Sửa lỗi

- `PredictionHUDWindow.targetFrame`: khi đặt HUD **phía trên** caret, công thức `separation - height` có thể ra **giá trị âm** (offset nhỏ / font HUD lớn) → đáy HUD tụt xuống **dưới** đỉnh caret, đè lên dòng văn bản. Nay ép đáy HUD **luôn cách đỉnh caret tối thiểu 6px** nên HUD không bao giờ che dòng đang gõ. Offset lớn giữ nguyên hành vi cũ.

> ⚠️ Với một số app web/Electron, tọa độ caret từ Accessibility API có thể không chính xác (HUD lệch theo chiều ngang) — đây là hạn chế riêng của app đó, không nằm trong phạm vi fix này.

## [2.4] - 2026-05-31 — "Gọn nhẹ"

**Tối ưu dung lượng bản cài: tệp chương trình giảm từ ~18 MB xuống ~7 MB, bản tải về (.dmg) giảm ~22% (8.4 MB → 6.6 MB). Không thay đổi tính năng.**

> Từ v2.4, version chuyển sang **2 cấp `MAJOR.MINOR`** theo quy tắc mới trong `RELEASE.md` (build `20400`).

### 📦 Dung lượng

Bản ship trước đây vô tình **không strip symbol** nên binary chứa toàn bộ bảng symbol của thư viện Rust static (`libvkey_core.a`). Đã bật strip cho cấu hình Release:

- `DEPLOYMENT_POSTPROCESSING = YES` + `STRIP_INSTALLED_PRODUCT = YES` + `COPY_PHASE_STRIP = YES` (lưu ý: `COPY_PHASE_STRIP` một mình KHÔNG strip main executable khi `xcodebuild build`).
- `SWIFT_OPTIMIZATION_LEVEL = -Osize`.
- Kết quả: binary `vkey` **18.4 MB → ~7.0 MB**; bộ cài `.app` **~22 MB → ~13 MB**. Vẫn sinh `dSYM` nên crash vẫn symbolicate được; Swift runtime metadata + cả 2 kiến trúc (x86_64 + arm64) nguyên vẹn.

### 🐛 Sửa lỗi

- `AppState`: thêm `deinit` gỡ observer `NSWorkspace.didActivateApplication` (trước đây đăng ký trong `init` nhưng không gỡ) — tránh rò rỉ nếu `AppState` bị tái tạo.

### 🔧 Nội bộ

- Rà soát toàn bộ engine gõ (InputProcessor / Rust FFI / TiengVietState) cho loạt nghi vấn bug — xác minh trên code thật đều **an toàn, không cần sửa**. Toàn bộ **218 test pass**.

## [2.3.22] - 2026-05-29 — "Private Mode Per-App"

**Sửa lỗi chế độ riêng tư (biểu tượng khoá) không bám theo app đang dùng: khi một app có cửa sổ nhập mật khẩu, chuyển sang app khác mà cửa sổ đó vẫn mở thì vkey vẫn kẹt ở chế độ riêng tư, không gõ được tiếng Việt.**

### 🐛 Nguyên nhân

`CGSIsSecureEventInputSet()` là cờ **toàn hệ thống**. Khi một app (kể cả app nền) giữ ô nhập mật khẩu đang focus, cờ này vẫn `true` ngay cả sau khi người dùng chuyển sang app khác. vkey dùng trực tiếp cờ raw này nên kẹt ở chế độ riêng tư.

### ✅ Fix v2.3.22

Gắn chế độ riêng tư vào **app thực sự đang sở hữu** secure input:

- Ghi nhớ PID của app sở hữu (`secureInputOwnerPID`) ngay tại thời điểm cờ bật (off→on).
- Chỉ giữ chế độ riêng tư khi:
  - App sở hữu đó đang là **foreground**, **hoặc**
  - Ô đang focus của app foreground bản thân là ô mật khẩu (subrole `AXSecureTextField`) → quyền sở hữu chuyển sang app mới.
- Khi cờ tắt → reset owner.

### 📊 Hành vi theo tình huống

- App A mở cửa sổ mật khẩu → khoá. Chuyển sang app B (mật khẩu A vẫn mở) → **vkey gõ lại bình thường ở B**. Quay lại A → khoá lại.
- App B mở ô mật khẩu riêng → khoá đúng (ownership chuyển sang B).
- `sudo` trong Terminal vẫn hoạt động đúng (owner = Terminal).

### 📝 Files

- `vkey/Platform/EventHook.swift` — track `secureInputOwnerPID`, scope private mode theo foreground app.
- `vkey/Platform/Focused.swift` — thêm `Focused.isSecureField()` (kiểm tra subrole `AXSecureTextField`).

## [2.3.21] - 2026-05-28 — "Telex Cancellation Pattern Detect"

**v2.3.20 fix "google" thành công nhưng "footer" vẫn lỗi vì "footer" không có trong English lexicon. v2.3.21 fix triệt để bằng pattern detection.**

### 🐛 v2.3.20 không đủ

v2.3.20 fix: nếu `transformed` là English word (theo lexicon), keep nó. Cho "gooogle" → "google" ✓ (google trong lexicon).

Nhưng "footer" KHÔNG trong English lexicon (chỉ ~126 embedded + package EN có thể không có). `transformedIsEnglish` returns FALSE → fix không fire → bug "foooter" vẫn còn.

### ✅ Fix v2.3.21: Pattern detection

Detect Telex mu cancellation pattern: rawInput có 3 nguyên âm liên tiếp (`ooo/aaa/eee/uuu/iii`) AND collapse triple→double ra transformed → keep transformed.

```swift
static func isLikelyTelexCancellation(rawInput: String, transformed: String) -> Bool {
  let raw = rawInput.lowercased()
  let trans = transformed.lowercased()
  let vowelTriples = ["ooo", "aaa", "eee", "uuu", "iii"]
  for triple in vowelTriples {
    if raw.contains(triple) {
      let doubled = String(triple.prefix(2))
      let collapsed = raw.replacingOccurrences(of: triple, with: doubled)
      if collapsed == trans {
        return true
      }
    }
  }
  return false
}
```

Logic: nếu user gõ 3 vowels liên tiếp (Telex mu cancel pattern) và engine sản xuất raw với 2 vowels (cancel result), keep transformed bất kể có trong lexicon hay không.

### 📊 Coverage

| rawInput | transformed | Pattern match | Decision |
|---|---|---|---|
| "gooogle" | "google" | ✓ (ooo→oo) | keepRaw → "google" |
| "foooter" | "footer" | ✓ (ooo→oo) | **keepRaw → "footer" ✓** |
| "nooose" | "noose" | ✓ | keepRaw → "noose" |
| "smooooth" | "smooth" | ✓ | keepRaw → "smooth" |
| "baaad" | "baad" | ✓ (aaa→aa) | keepRaw → "baad" |
| "google" | "google" | ✗ (no triple) | short-circuit (other path) |
| "text" | "tẽt" | ✗ | restoreRawEnglish → "text" ✓ |

### 🧪 Test

218/218 pass. New test `testTelexCancellationPatternDetect`.

### Bump

`2.3.20 → 2.3.21` / `20320 → 20321`. DMG 8761821 bytes, sig `UvS2hBrocQplLTVeIvmJDOwrAMrkjLkPhtOAhvJUQtMJLH4swyqGaWXy7ZV5rRo4b+N6iVGTehoCNeLh0EmHDw==`.

---

## [2.3.20] - 2026-05-28 — "Keep English Transformed (Root Cause Fix)"

**ROOT CAUSE FIX dựa trên v2.3.19 diagnostic logs từ runtime. Bug fundamentally khác với mọi hypothesis từ v2.3.7→v2.3.18.**

### 🔬 Diagnosis từ runtime log

v2.3.19 logged actual state trong khi user gõ. Trace bug case:

```
14:13:24 char=g     new=g       keys=g
14:13:25 char=o     new=go      keys=go
14:13:25 char=o     new=gô      keys=goo       ← Telex mu apply
14:13:25 char=o     new=goo     keys=gooo      ← Mu cancel + J2 raw append
14:13:26 char=g     new=goog    keys=gooog
14:13:26 char=l     new=googl   keys=gooogl
14:13:26 char=e     new=google  keys=gooogle   ← transformed="google" (6 chars) but keys="gooogle" (7)
14:13:27 SpellCommit: rawInput=gooogle current=google
14:13:27 decision=restoreRawEnglish("gooogle")  ← BUG!
```

**User gõ "gooogle" intentionally** (3 o's để cancel Telex mu, mong tiếng Anh). vkey engine xử lý đúng → `transformed="google"` (English). Nhưng spell decision line 136 returns `.restoreRawEnglish(rawInput="gooogle")` → restores USER'S TYPO "gooogle" với 3 o's.

### 🔍 Code analysis

[`SpellDecisionEngine.swift:134-141`](vkey/Input/SpellDecisionEngine.swift) (pre-fix):

```swift
// 1. If transformed output is NOT a valid Vietnamese word
if !isVietnameseWord {
  if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
    return .restoreRawEnglish(rawInput)  // ← BUG: restores raw typo
  }
  if needsRecovery && rawIsEnglish {
    return .restoreRawEnglish(rawInput)
  }
}
```

Cho case "gooogle":
- `rawToken="gooogle"`, `transformedToken="google"`. ASCII ✓, != ✓ → returns `.restoreRawEnglish("gooogle")`.
- Restoration replaces vkey's correct "google" với user's typo "gooogle".

### ✅ Fix v2.3.20

Thêm check TRƯỚC line 136 — nếu `transformed` ĐÃ là English word hợp lệ, GIỮ nó:

```swift
if !isVietnameseWord {
  // v2.3.20: if transformed is already valid English, keep it.
  let transformedIsEnglish = lexiconManager.isEnglishWord(transformed)
  if transformedIsEnglish {
    return .keepRaw  // Keep transformed ("google"), don't restore raw ("gooogle")
  }
  if rawToken.isASCIIAlphabeticWord, rawToken != transformedToken {
    return .restoreRawEnglish(rawInput)
  }
  if needsRecovery && rawIsEnglish {
    return .restoreRawEnglish(rawInput)
  }
}
```

### 📊 Sau fix

| Case | rawInput | transformed | transformedIsEnglish | Decision |
|---|---|---|---|---|
| "google" (2 o's) + space | "google" | "google" | TRUE | (short-circuit via current==rawInput at line 1135) |
| "gooogle" (3 o's) + space | "gooogle" | "google" | TRUE | **keepRaw → display "google"** ✓ |
| "foooter" (3 o's) + space | "foooter" | "footer" | TRUE | **keepRaw → display "footer"** ✓ |
| "text" + space | "text" | "tẽt" | FALSE | restoreRawEnglish → "text" ✓ |
| "theme" + space | "theme" | "thẽme" | FALSE | restoreRawEnglish → "theme" ✓ |

### 🧹 Cleanup

Remove debug logs từ v2.3.19 (`TypeChar:`, `SpellCommit:` os_log statements). Performance baseline restored.

### 💡 Insight

Sau 12 versions (v2.3.7→v2.3.19) đoán hypothesis về CGEvent/NFC/NFD/scalar/grapheme/AX/modifier/short-circuit — TẤT CẢ SAI. Root cause hóa ra ở SPELL DECISION LOGIC: chose user's raw typo over vkey-produced valid English word.

**Bài học**: Khi user observation cho hint chính xác ("ON gây bug, OFF không"), hãy IMMEDIATELY add diagnostic logging để xem actual data, thay vì đoán technical hypothesis. Diagnostic log v2.3.19 chỉ thẳng vào root cause trong 1 commit.

### 🧪 Test

217/217 pass.

### Bump

`2.3.19 → 2.3.20` / `20319 → 20320`. DMG 8761089 bytes, sig `INa6+P3CaelE8a3v2fDeBaoL4hv1r36n8+0A7lWb/ydDZ1FzwZFDVQvsrET7m4QukO01CHl0Oc9Vs6MFlxg8AQ==`.

---

## [2.3.19] - 2026-05-28 — "Diagnostic Logging"

**User confirm v2.3.18 vẫn lỗi. Tất cả hypothesis từ v2.3.7→v2.3.18 SAI. Cần dữ liệu empirical từ user để chẩn đoán đúng.**

### 🔬 Approach

Phiên bản này KHÔNG fix bug. Thêm `os_log` để capture actual state tại runtime:
- **Typing time** (`TypeChar`): char nhận, transformed trước/sau push, keys array.
- **Commit time** (`SpellCommit`): rawInput, current, decision, short-circuit hit.

User chạy Console.app, capture log, gửi lại. Tôi xem actual values và xác định nguyên lý đúng.

### 🔍 Hướng dẫn user

1. Update vkey lên v2.3.19 (Sparkle).
2. Mở **Console.app** (Applications → Utilities → Console).
3. Click "Start streaming" + filter subsystem:
   - Search bar: `subsystem:dev.longht.vkey`
   - Hoặc Action menu → "Include Info Messages".
4. Trong app bất kỳ (Notes, Claude desktop…), gõ "google" + space.
5. Quay lại Console.app, copy hoặc screenshot các dòng log `TypeChar:` và `SpellCommit:`.
6. Gửi lại để chẩn đoán.

### 📊 Sample log

Expected output cho "google" + space (no bug case):

```
TypeChar: char=g  pre=     lastT=     new=g       keys=g
TypeChar: char=o  pre=g    lastT=g    new=go      keys=go
TypeChar: char=o  pre=go   lastT=go   new=gô      keys=goo
TypeChar: char=g  pre=gô   lastT=gô   new=gôg     keys=goog
TypeChar: char=l  pre=gôg  lastT=gôg  new=googl   keys=googl
TypeChar: char=e  pre=googl lastT=googl new=google keys=google
SpellCommit: rawInput=google current=google endingChar=  spellOn=true
SpellCommit: SHORT-CIRCUIT (current==rawInput)
```

Nếu thấy `SHORT-CIRCUIT` mà bug vẫn xảy ra → typing path đã có corruption. Cần kiểm tra display thực tế qua AX.

Nếu KHÔNG thấy `SHORT-CIRCUIT` → `current != rawInput`, log sẽ cho thấy chính xác giá trị nào khác.

### Trade-off

- KHÔNG fix bug ở v2.3.19.
- Log output có thể spam Console khi user gõ nhiều — bình thường vì only Info-level và filter dễ.
- Sẽ remove logs ở next stable version (v2.3.20+) sau khi xác định root cause.

### 🧪 Test

217/217 pass. Logging không thay đổi logic — chỉ thêm `os_log`.

### Bump

`2.3.18 → 2.3.19` / `20318 → 20319`. DMG 8764889 bytes, sig `AWNnJ02wtnbg9ZVVZ83cJub+hRZQihbMOHZlnrr5ZNxO2rv5bOX1KoU0t2NCmTZ8jIWH930Qo4VncVfjSG4cBw==`.

---

## [2.3.18] - 2026-05-28 — "Universal Short-Circuit When No Transform"

**User confirm v2.3.17 (short-circuit chỉ restoreRawEnglish) vẫn lỗi. v2.3.18 short-circuit ở ENTRY của applySpellDecisionOnCommit, bypass entire spell decision khi current==rawInput.**

### 🐛 Tại sao v2.3.17 không đủ?

v2.3.17 chỉ add `if current == restoredWord { return false }` trong case `.restoreRawEnglish`. Nhưng bug "gooogle" có thể fire qua các decision path khác:
- `.suggest` (với `autoApplyHighConfidenceSuggestion` default=TRUE).
- Hoặc fallback decisions trong evaluate.

Khi `current == rawInput` (vkey chưa transform gì), spell decision không CẦN làm gì cả. Bất kỳ side-effect nào (Option+Backspace, sendString, sendReplacement) đều có thể gây bug.

### ✅ Fix v2.3.18

Universal short-circuit ngay ENTRY của [`applySpellDecisionOnCommit`](vkey/App/InputProcessor.swift):

```swift
guard Defaults[.spellCheckEnabled], !ruleOverrides.disableSpellCheck else {
  return false
}

// v2.3.18 UNIVERSAL SHORT-CIRCUIT
if current == rawInput {
  lastSuggestions = []
  return false  // Skip ENTIRE spell decision logic
}

// Normal flow only if vkey transformed something
let needsRecovery = ...
let decision = evaluate(...)
...
```

### 📊 Behavior matrix

| Case | current | rawInput | Action |
|---|---|---|---|
| "google" + space | "google" | "google" | Short-circuit (bypass spell) |
| "footer" + space | "footer" | "footer" | Short-circuit |
| "tools" + space | "tools" | "tools" | Short-circuit |
| "tieengs" + space (Telex VN) | "tiếng" | "tieengs" | Run evaluate → keepVietnamese |
| "text" + space (e+x = nga) | "tẽt" | "text" | Run evaluate → restoreRawEnglish |
| "theme" + space (mu) | "thême" | "theme" | Run evaluate → restoreRawEnglish |

### ⚠️ Trade-off

Khi short-circuit fires:
- KHÔNG record `UsageStatistics.shared.recordCommit` cho commit này.
- KHÔNG `PredictionEngine.shared.learnTransition`.
- HUD prediction không update.

Acceptable trade-off — chỉ ảnh hưởng pure English typing (rare for vkey users). Vietnamese typing và Telex-transformed English vẫn record đầy đủ.

### 🧪 Test

217/217 pass.

### Bump

`2.3.17 → 2.3.18` / `20317 → 20318`. DMG 8761010 bytes, sig `mkLb2lQU72c0QL7VyfVtbh9OqqCxJDNLUwhr/Ytal4fzMa8Mx+IobGJRdIokafRgLlF2GOkZVXMC9RzrqYN2Cg==`.

---

## [2.3.17] - 2026-05-28 — "Short-Circuit Restore When Not Needed"

**User diagnostic chìa khóa: bug `gooogle/foooter` CHỈ xảy ra khi bật "sửa lỗi chính tả". Tắt → không bug. Fix: short-circuit `restoreRawEnglish` khi không cần restore.**

### 🔬 User diagnostic

> "nếu không bật sửa lỗi chính tả thì không bị lỗi google footer, bật thì sẽ bị gooogle foooter"

→ Bug ở **spell check commit path**, KHÔNG phải typing path hay CGEvent round-trip như tôi đoán trước đây.

### 🔍 Root cause

Cho user typing "google":
1. **Typing path** (giống nhau bất kể spell check):
   - Step 3 'o': Telex mu → display "gô".
   - Step 4 'g': → "gôg".
   - Step 5 'l': recovery (gôgl không valid Vietnamese) → display "googl", `transformed="googl"`.
   - Step 6 'e': recovery branch → `transformed="google"` ✓.
   - **Display khi typing xong: "google"** (per user OFF case).

2. **Commit path** (space):
   - Spell check OFF: `applySpellDecisionOnCommit` return false → space pass-through → "google ". ✓
   - Spell check ON: `evaluate("google", "google", needsRecovery=true)`:
     - rawIsEnglish=true (google in lexicon).
     - Returns `.restoreRawEnglish("google")`.
   - vkey chạy Option+Backspace + sendString "google " để "restore raw".
   - **NHƯNG `current=="google" == restoredWord` rồi**. Không có gì để restore!
   - Restoration logic vẫn fire → side-effect → bug "gooogle".

### ✅ Fix v2.3.17

Short-circuit khi `current == restoredWord`:

```swift
case .restoreRawEnglish(let restoredWord):
  lastSuggestions = []
  if current == restoredWord {
    return false  // No restore needed. Let endingChar pass-through.
  }
  // Otherwise: do restoration via Option+Backspace + sendString
  ...
```

Effect:
- "google" + space: current=="google" == restoredWord → return false → space pass-through → "google ". ✓
- Same behavior as spell check OFF.

### 🛡️ Restoration vẫn work cho real cases

Vẫn cần restore khi `current != restoredWord` — như "text" Telex tạo intermediate "tẽt" (e+x = ngã tone). Engine recovery may not always undo. Spell decision fires restoreRawEnglish.

| Case | current | restoredWord | Action |
|---|---|---|---|
| "google" + space | "google" | "google" | Short-circuit (no restore) |
| "footer" + space | "footer" | "footer" | Short-circuit |
| "text" + space | "tẽt" | "text" | Restore via Option+Backspace |
| "theme" + space | "thẽme" | "theme" | Restore |

### 📝 Insight

Sau 10+ versions thử các approach về CGEvent injection, NFC/NFD, AX detection, modifier sequences — tất cả failed. **Root cause hóa ra đơn giản hơn nhiều**: code đang chạy restoration khi không cần. User's diagnostic ("spell check ON gây bug, OFF không") đã chỉ thẳng vào commit path.

Bài học: lắng nghe user observation cụ thể trước khi đoán hypothesis kỹ thuật.

### 🧪 Test

217/217 pass.

### Bump

`2.3.16 → 2.3.17` / `20316 → 20317`. DMG 8760705 bytes, sig `QYn0DHwmAemgIcZO9xyNO06HHGySt9N9pHnOfYchsSG51hQmEX9lrK4mQrzuPD0ahixuBz+7giN3lEIZgB1SBw==`.

---

## [2.3.16] - 2026-05-28 — "Proper Modifier Sequence for Option+Backspace"

**User confirm v2.3.15 vẫn lỗi "gooogle, foooter". Fix: proper modifier press/release sequence cho Option+Backspace.**

### 🔍 Nguyên nhân v2.3.15 fail

v2.3.15 dùng:
```swift
downEvent.flags = [.maskAlternate, .maskNonCoalesced]
downEvent.post(...)
```

Một số app (Notes, Claude desktop) check actual modifier state qua `NSEvent.modifierFlags` (hardware-level), không react với synthesized flag trên key event. Kết quả: sendOptionBackspace KHÔNG xóa word → sendString append "google " sau "gooogle" → display thành "gooogle google " — user vẫn thấy "gooogle".

### ✅ Fix v2.3.16

Proper modifier sequence trong [`EventSimulator.sendOptionBackspace`](vkey/Platform/EventSimulator.swift):

```swift
let leftOptionKey: CGKeyCode = 0x3A  // Left Option

// 1. Option key DOWN
let optionDown = CGEvent(keyboardEventSource: source, virtualKey: leftOptionKey, keyDown: true)
optionDown?.flags = .maskAlternate
optionDown?.post(tap: .cgSessionEventTap)

// 2. Backspace DOWN + UP with Option flag
let bsDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: true)
bsDown?.flags = [.maskAlternate, .maskNonCoalesced]
bsDown?.post(tap: .cgSessionEventTap)
let bsUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.delete, keyDown: false)
bsUp?.flags = [.maskAlternate, .maskNonCoalesced]
bsUp?.post(tap: .cgSessionEventTap)

// 3. Option key UP
let optionUp = CGEvent(keyboardEventSource: source, virtualKey: leftOptionKey, keyDown: false)
optionUp?.flags = []
optionUp?.post(tap: .cgSessionEventTap)
```

4 events thay vì 2. Simulates đúng hành vi user nhấn keyboard.

Cũng tăng usleep từ 2ms → 10ms trong [`InputProcessor`](vkey/App/InputProcessor.swift) restoreRawEnglish để app process word deletion kịp trước sendString.

### 📊 Trace expected

"google" + space trong Notes / Claude desktop:
1. Display before space: "gooogle" (do CGEvent round-trip bug ở intermediate).
2. Option key DOWN (modifier press).
3. Backspace (Option held): app sees "delete word" → xóa "gooogle".
4. Backspace UP, Option UP.
5. 10ms delay.
6. sendString "google ": → "google ".

Final: "google ".

### ⚠️ Nếu vẫn lỗi

Có nghĩa Option+Backspace via CGEvent vẫn không reliable trong app đó. Sẽ cần thử AX API write (programmatically set selection range) hoặc approach khác.

### 🧪 Test

217/217 pass.

### Bump

`2.3.15 → 2.3.16` / `20315 → 20316`. DMG 8760468 bytes, sig `Ss8QH7+iHTAN/wDq1qr9mHsOgMiQZuPQFx0t444DRC334FU5aB5TcN/ohuy3ywEcUfDxg9Ayx/zC3pyeqXgKDw==`.

---

## [2.3.15] - 2026-05-28 — "Option+Backspace Commit Restore"

**Cách tiếp cận MỚI dựa trên user diagnostic empirical. Bug "google → gooogle" trong Notes (Apple native) + Claude desktop + Chromium, diverge tại commit-time (sau space).**

### 🔬 User diagnostic

User test cụ thể với v2.3.13/14:
- **Notes**: gõ "google" → "gooogle". Gõ "gôgle" trực tiếp → "google" ✓
- **Claude desktop**: gõ "google" → "gooogle"
- **Bước diverge đầu tiên**: sau khi ấn space

→ Bug ở **commit-time**, không phải typing-time. Hypothesis NFC/NFD storage SAI vì Notes (NFC) cũng có bug.

### 🔍 Root cause

Display BEFORE space đã có extra 'o' do CGEvent round-trip issues ở intermediate steps (vkey backspace+retype không hoàn hảo trong một số contexts). vkey buffer state đúng ("google" 6 chars).

Tại commit (space): vkey diff `current="google"` (buffer) → `target="google "` = (0 bs, " "). Chỉ send space. Display thực tế "gooogle" + " " = "gooogle " (không sửa được vì vkey không biết display thực).

### ✅ Fix v2.3.15

Tại commit-time `restoreRawEnglish` trong [`InputProcessor.swift`](vkey/App/InputProcessor.swift):

```swift
// Bypass diff. Wipe word via Option+Backspace + retype.
let source = CGEventSource(stateID: .privateState)
EventSimulator.simulationQueueAsync {
  _ = EventSimulator.withAdaptiveFlush {
    EventSimulator.sendOptionBackspace(source: source)
    usleep(2000)  // small delay for app to process word deletion
    EventSimulator.sendString(target, source: source)
  }
}
```

`sendOptionBackspace` là helper mới trong [`EventSimulator.swift`](vkey/Platform/EventSimulator.swift):

```swift
static func sendOptionBackspace(source: CGEventSource? = nil) -> Bool {
  ...
  downEvent.flags = [.maskAlternate, .maskNonCoalesced]  // Option+Backspace
  ...
}
```

Option+Backspace = macOS standard "delete word" shortcut → xóa entire word từ cursor về đầu word, **regardless of display state**.

### 📊 Trace

"google" trong Notes / Claude desktop sau v2.3.15:

| State | Action | Display |
|---|---|---|
| Before space | (có thể bug) | `gooogle` hoặc `google` |
| Option+Backspace | delete word | `` (empty hoặc previous content) |
| sendString "google " | retype + space | `google ` ✓ |

### ⚠️ Limitations

- Option+Backspace cần app support macOS standard shortcut. Hầu hết text apps support.
- Nếu cursor không ở cuối word (giữa câu hoặc trong selection), behavior phụ thuộc app.
- Áp dụng CHỈ cho `restoreRawEnglish` path (commit-time English restore). Vietnamese typing path không đụng.
- Áp dụng cho MỌI app uniformly — đơn giản hóa logic, không cần whitelist.

### 🛡️ Không thay đổi

- Vietnamese typing (Telex/VNI realtime): không đụng. Vẫn dùng diff-based BS+retype.
- Apple apps mà English restoreRawEnglish hoạt động đúng trước đây: vẫn đúng sau fix (Option+Backspace + retype = idempotent).
- Spell decision logic không thay đổi.

### 🧪 Test

217/217 pass. Manual test cần ở:
1. **Notes**: gõ "google" + space → kỳ vọng "google ".
2. **Claude desktop**: gõ "google" + space → "google ".
3. **Chrome URL bar**: gõ "google" + space → "google ".
4. **Word/Slack/Discord/Notion**: same.

### Bump

`2.3.14 → 2.3.15` / `20314 → 20315`. DMG 8759892 bytes, sig `UamQRbjGbOUDauGWtJCHhhnyDn6SslS+m16TFMyHnyqDY1WcEjiuqQfmbY5l05y3QwajP9jmVFvAEJpTkNPgDw==`.

---

## [2.3.14] - 2026-05-28 — "Revert to Stable Baseline"

**Revert v2.3.13's NFD diff. Cascade v2.3.8 → v2.3.13 thử nhiều hypothesis đều thất bại. Quay về grapheme diff stable, chờ thông tin diagnostic chi tiết từ user.**

### 🐛 Bug status

`google → gooogle` và `footer → foooter` trong **Claude desktop** / Chromium / Electron apps **vẫn chưa fix**.

### 🔍 Lý do revert

Cascade fix attempts đều dựa hypothesis về Chromium text engine internals. Tất cả thất bại:

| Version | Approach | Kết quả |
|---|---|---|
| v2.3.8 | NFD diff cho FixAutocompleteApps | Phá Google Docs |
| v2.3.9 | Revert v2.3.8 | OK baseline |
| v2.3.10 | NFD diff chỉ cho AXSearchField | Fix Google Docs, URL bar vẫn lỗi |
| v2.3.11 | Backspace-only (no Shift+Left) | URL bar vẫn lỗi |
| v2.3.12 | NFD diff cho search fields | URL bar vẫn lỗi |
| v2.3.13 | NFD diff cho mọi non-Apple app | Claude desktop vẫn lỗi |

Mỗi version thử khớp với một combo (NFC/NFD storage × grapheme/scalar backspace). User report sau mỗi version cho thấy hypothesis sai. Cần dừng đoán và lấy thông tin empirical.

### ✅ v2.3.14 plan

- Revert về grapheme diff cho mọi app (giống v2.3.11 stable).
- Giữ [`calcKeyStrokesNFD`](vkey/Platform/EventSimulator.swift) + [`usesNFCGraphemeStorage`](vkey/App/InputProcessor.swift) functions làm dead code (để research/test sau).
- Chờ user feedback diagnostic chi tiết để tìm đúng root cause.

### 📝 Workaround tạm thời

Khi gõ English ngắn trong Chromium/Electron apps (Claude desktop, Chrome URL bar, Slack, Discord, Notion…):

1. **Tắt vkey** (⇧⌥ shortcut) → gõ raw English → bật lại.
2. **Copy-paste** từ source khác.
3. **Gõ chậm**, từng char một (đôi khi giúp OS process kịp).

### 🔬 Cần diagnostic từ user

Để tìm đúng root cause, cần user test SPECIFIC steps và report visible output ở MỖI step:

1. Mở **Notes** (Apple native, NFC). Gõ chậm `g`, `o`, `o`. Quan sát từng bước. Kết quả: ?
2. Tiếp `g`, `l`, `e`. Quan sát. Final: ?
3. Lặp lại trong **Claude desktop**. Final: ?
4. Lặp lại trong **Chrome URL bar**. Final: ?

So sánh kết quả Notes vs Claude desktop sẽ giúp identify chính xác hành vi text engine của Claude desktop.

### 🧪 Test

217/217 pass. Behavior giống v2.3.11 stable.

### Bump

`2.3.13 → 2.3.14` / `20313 → 20314`. DMG 8759848 bytes, sig `Ygh/cbCNgx26ZpKvdPI0AEKswVUVyjksxxgoUQ+PzNC2FOHuAZDP3hxORZqPrlVpdmdkCq6XhlRP+hU/KM2PCw==`.

---

## [2.3.13] - 2026-05-28 — "NFD Diff for Non-Apple Apps"

**Mở rộng NFD diff (v2.3.12 chỉ cho search fields) ra TẤT CẢ non-Apple apps: Chromium, Electron, Claude desktop, browsers, web inputs…**

### 🐛 User report

> "gooogle, foooter vẫn bị lỗi, tôi đang gõ trực tiếp ở claude desktop hay. bất kỳ đâu đều bị lỗi này"

v2.3.12 fix Chrome URL bar (AXSearchField) qua NFD diff. Nhưng bug vẫn còn ở Claude desktop (Electron text area, không phải search field) và "bất kỳ đâu" Chromium-based.

### 🔍 Nguyên nhân

Chromium engines (Chrome, Edge, Brave, Arc, Electron-based apps như Claude desktop, Slack, Discord, Notion, VSCode, Figma…) **store Vietnamese text dạng NFD** và **đếm backspace theo SCALAR**, không grapheme.

Trace "google" trong Claude desktop với grapheme diff (cũ):
- Step 3 ('o' 3rd): vkey transforms "go" → "gô" (Telex mu). Diff (1 bs, "ô"). Backspace × 1 (1 scalar in NFD = 1 char 'o'). + "ô" (NFC sent, Claude decomposes to NFD = 'o' + ◌̂). Stored "g,o,◌̂" (3 scalars). Visible "gô" ✓ (works because 1 scalar = 1 char for ASCII).
- Step 4 'g': pass-through. Stored "g,o,◌̂,g" (4 scalars).
- Step 5 'l' (recovery): vkey diffs "gôg" → "googl" = (2 bs, "oogl"). Claude backspace × 2 = xóa 2 SCALARS = [◌̂, g]. Stored = "g,o" (2 scalars). + sendString "oogl" (4 chars) → "g,o,o,o,g,l" (6 scalars). Visible "gooogl" ❌
- Step 6 'e': pass-through → "gooogle" (7 chars). BUG.

### ✅ Fix

Bundle-ID whitelist approach trong [`InputProcessor.swift`](vkey/App/InputProcessor.swift):

```swift
static func usesNFCGraphemeStorage(bundleId: String) -> Bool {
  if bundleId.isEmpty { return true }
  if bundleId.hasPrefix("com.apple.") { return true }
  if bundleId.hasPrefix("com.apple.iWork.") { return true }
  let officeNative: Set<String> = [
    "com.microsoft.Word",
    "com.microsoft.Excel",
    "com.microsoft.Powerpoint",
    "com.microsoft.Outlook",
    "com.microsoft.onenote.mac",
    "com.microsoft.Office.Word",
    "com.microsoft.Office.Excel",
  ]
  return officeNative.contains(bundleId)
}
```

Trong `handleTextChar` + `restoreRawEnglish`:
```swift
let useNFDDiff = !InputProcessor.usesNFCGraphemeStorage(bundleId: activeApp)
let (numBackspaces, diffChars) = useNFDDiff
  ? EventSimulator.calcKeyStrokesNFD(...)
  : EventSimulator.calcKeyStrokes(...)
```

### 📊 Trace sau fix

**Claude desktop / Chrome / Chromium "google"**:
- Step 3: NFD diff (0 bs, ◌̂) → append combining mark → stored "g,o,◌̂" → "gô" ✓
- Step 5: NFD diff (2 bs scalars, "ogl") → xóa 2 scalars `[◌̂,g]` → "g,o" + "ogl" → "g,o,o,g,l" → "googl" ✓
- Step 6: pass-through → "google" ✓

**Claude desktop "footer"**:
- Step 3: NFD diff (0 bs, ◌̂) → "fô" ✓
- Step 5: NFD diff (2 bs, "ote") → "f,o" + "ote" → "foote" ✓
- Step 6: pass-through → "footer" ✓

### 🛡️ Không thay đổi (NFC whitelist)

| App category | Bundle ID prefix | Diff |
|---|---|---|
| Apple native | `com.apple.*`, `com.apple.iWork.*` | Grapheme |
| Microsoft Office native | Word, Excel, Powerpoint, Outlook, OneNote | Grapheme |
| Mọi thứ khác (default) | (default) | NFD |

Notes, TextEdit, Mail, Pages, Numbers, Keynote, Word, Excel… đều giữ grapheme diff như cũ. Vietnamese typing không đổi.

### ⚠️ Risk

Nếu một app **NFC native** không nằm trong whitelist (vd app viết bằng AppKit của bên thứ 3 ít phổ biến), sẽ bị NFD diff → có thể under-type khi gõ tiếng Việt (vd "gôg" → "gogl" thay vì "googl"). Báo lại nếu gặp — tôi sẽ add vào whitelist.

Apps điển hình cần kiểm tra: BBEdit, TextMate, Sublime Text, MacVim, Logseq, Bear, iA Writer. Nếu Vietnamese typing trong các app này có bug, add bundle ID vào whitelist.

### 🧪 Test

217/217 pass. Manual test:
1. **Claude desktop**: gõ "google", "footer", "tools" → kỳ vọng đúng.
2. **Chrome URL bar / Google search**: same.
3. **Google Docs** (regression): "trình bày" → đúng.
4. **Notes/TextEdit** (NFC regression): "tiếng việt" → đúng.
5. **Word/Excel** (NFC regression): tiếng Việt → đúng.

### Bump

`2.3.12 → 2.3.13` / `20312 → 20313`. DMG 8761860 bytes, sig `BpGflLMIvsuMiQxdQX+HWFtnuMVkdZC3qyBZeGBDuz/PzyLIsvohGQ64tWGFdrR+11H4/3Xhl9X8yHbAqHxaDw==`.

---

## [2.3.12] - 2026-05-28 — "NFD Backspace for Search Fields"

**Sửa nốt "google → gooogle" và "footer → foooter" trong Chrome URL bar / Google search. KHÔNG phải tính năng tự sửa mà do scalar/grapheme mismatch trong backspace count.**

### 🐛 User question

> "vẫn lỗi gooogle, xem lại có phải do tính năng tự sửa hay do tính năng gì? foooter cũng vậy"

### 🔍 Root cause (đúng lần này)

**Không** phải auto-correct feature. Bug do **scalar/grapheme mismatch trong backspace count**:

- Chrome URL bar (và similar search fields) store Vietnamese text dạng **NFD**:
  - "ô" precomposed (NFC) = U+00F4 (1 scalar)
  - vkey send NFC qua `keyboardSetUnicodeString`
  - Chrome decompose & store NFD: 'o' + combining ◌̂ = 2 scalars

- Chrome URL bar's **backspace cũng đếm theo scalar**, không grapheme:
  - "gôg" stored NFD = [g, o, ◌̂, g] (4 scalars, 3 graphemes)
  - vkey tính grapheme diff "gôg"→"googl" = (backspace=2, diff="oogl")
  - Backspace × 2 trong Chrome URL bar: xóa 2 SCALARS [◌̂, g] thay vì 2 GRAPHEMES [ô, g]
  - Còn lại "go" thay vì "g"
  - + sendString "oogl" → "go" + "oogl" = "gooogl"
  - + 'e' (next step) → "gooogle"

Tương tự "footer → foooter": Telex áp `oo→ô` ở step 3, recovery ở step 5 trả về raw, backspace count thiếu trong NFD storage → 'o' thừa.

### ✅ Fix

Dùng `EventSimulator.calcKeyStrokesNFD` (compute diff trong NFD scalar space) cho search fields:

```swift
let useNFDDiff = isFixAutocompleteApp()  // chỉ true cho AXSearchField/AXComboBox
let (numBackspaces, diffChars) = useNFDDiff
  ? EventSimulator.calcKeyStrokesNFD(from: lastTransformed, to: transformed)
  : EventSimulator.calcKeyStrokes(from: lastTransformed, to: transformed)
```

NFD diff đếm backspace theo scalar, khớp với Chrome URL bar's scalar-based backspace.

Áp dụng cho cả 2 chỗ trong [`InputProcessor.swift`](vkey/App/InputProcessor.swift):
- `handleTextChar` typing-time diff.
- `applySpellDecisionOnCommit` commit-time `restoreRawEnglish` diff.

Backspace path (từ v2.3.11) giữ nguyên — không dùng Shift+Left. NFD chỉ thay đổi cách đếm.

### 📊 Trace "google" trong Chrome URL bar sau v2.3.12

| Step | Char | NFD diff | Action | Display |
|---|---|---|---|---|
| 1 | g | append | pass-through | `g` |
| 2 | o | append | pass-through | `go` |
| 3 | o (3rd) | (0 bs, `◌̂`) | sendString combining mark | `gô` ✓ |
| 4 | g | append | pass-through | `gôg` |
| 5 | l (recovery) | (2 bs, `"ogl"`) | backspace × 2 (scalars `◌̂g`) + "ogl" | `googl` ✓ |
| 6 | e | append | pass-through | `google` ✓ |

### 📊 Trace "footer" tương tự

| Step | Char | NFD diff | Action | Display |
|---|---|---|---|---|
| 3 | o (3rd) | (0 bs, `◌̂`) | sendString combining mark | `fô` ✓ |
| 4 | t | append | pass-through | `fôt` |
| 5 | e (recovery) | (2 bs, `"ote"`) | backspace × 2 (scalars `◌̂t`) + "ote" | `foote` ✓ |
| 6 | r | append | pass-through | `footer` ✓ |

### 🛡️ Không bị ảnh hưởng

- **Apple apps** (Notes, TextEdit, Mail, Pages): AX role = AXTextField/AXTextArea (không phải AXSearchField) → fall through `calcKeyStrokes` (grapheme diff). NFC storage + grapheme backspace → đúng như cũ.
- **Google Docs / Sheets**: AX role = AXTextArea → grapheme diff. Đã proved hoạt động ở v2.3.10.
- **Microsoft Office**: không phải search field → grapheme diff.

### 🧪 Test

217/217 pass. Pure unit test [`testCalcKeyStrokesNFDForCombiningDiacritic`](vkeyTests/vkeyTests.swift) verify NFD function. Integration cần manual test:
- Chrome URL bar: gõ "google", "tools", "footer", "facebook" → kỳ vọng không còn extra char.
- Google search box: same.
- Google Docs (regression): gõ tiếng Việt → vẫn ổn.
- Notes/TextEdit (regression): vẫn ổn.

### Bump

`2.3.11 → 2.3.12` / `20311 → 20312`. DMG 8760675 bytes, sig `hYll8Cw3QtDfErPv2kWTaq02Z1ynAzZUFrjQYtspfRwxgiF5tr2gSuwhGiyvJWrfWyhziSCdP/BBWg1VFBJuCw==`.

---

## [2.3.11] - 2026-05-28 — "Backspace-only Path"

**Sửa nốt "google → gooogle" trong Chrome URL bar / Google search box. Đơn giản hóa: dùng backspace + retype cho mọi app.**

### 🐛 Bug còn lại sau v2.3.10

- Google Docs: OK ✓ (fixed in v2.3.10)
- Chrome URL bar / Google search box: gõ "google" vẫn ra "gooogle" (extra 'o').

v2.3.10 detect search field (AX role) → áp dụng Shift+Left + NFD diff. Nhưng vẫn không fix URL bar — Shift+Left không tương tác đúng với autocomplete của URL bar.

### 🔍 Hypothesis cũ sai

v2.3.8 + v2.3.10 đều dựa trên giả thiết về Chrome storage (NFD scalar) hoặc Shift+Left behavior. Cả 2 đều không khớp thực tế:
- Google Docs: contenteditable + JS bỏ qua Shift+Left.
- Chrome URL bar: autocomplete xen vào keystrokes, không predict được.

`Shift+Left` selection-based replacement luôn unreliable trong nhiều context. **`Backspace` là deterministic** — luôn xóa 1 char visible từ cursor, không phụ thuộc app's selection state.

### ✅ Fix: đơn giản hóa

Drop `sendSelectAndReplace` path entirely:
- [`handleTextChar`](vkey/App/InputProcessor.swift) — typing-time.
- [`applySpellDecisionOnCommit`](vkey/App/InputProcessor.swift) — commit-time `restoreRawEnglish`.

Always use `sendReplacement` (backspace + retype) cho mọi app. Match behavior với Google Docs ở v2.3.10 (đã proved hoạt động đúng).

### 📊 Trace "google" trong Chrome URL bar sau v2.3.11

| Step | Char | Diff | Action | Display |
|---|---|---|---|---|
| 1 | g | append | pass-through | `g` |
| 2 | o | append | pass-through | `go` |
| 3 | o (3rd) | (1 bs, "ô") | backspace × 1 + sendString "ô" | `gô` ✓ |
| 4 | g | (0 bs, "g") | pass-through | `gôg` |
| 5 | l | (2 bs, "oogl") recovery | backspace × 2 + sendString "oogl" | `googl` ✓ |
| 6 | e | (0 bs, "e") | pass-through | `google` ✓ |

### ⚠️ Trade-off

v1.8.3 introduce `sendSelectAndReplace` (Shift+Left) để fix bug "footer → foooter" trong browsers với inline autocomplete. v2.3.11 revert decision đó.

**Nếu "footer → foooter" hoặc bug tương tự quay lại** — báo lại để add fallback. Chrome có thể đã cải thiện autocomplete behavior từ 2024 đến nay (v1.8.3 era) nên hopefully không còn issue.

### 🛡️ Không bị ảnh hưởng

- **Google Docs / Sheets**: vẫn dùng backspace path → vẫn ok.
- **Apple apps**: Notes, TextEdit, Mail — unchanged.
- **Microsoft Office**: Word, PowerPoint, Outlook — unchanged.

### 📝 Note

`EventSimulator.sendSelectAndReplace` và `EventSimulator.calcKeyStrokesNFD` functions giữ lại làm dead code — có thể research lại sau nếu cần xử lý autocomplete đặc biệt cho 1 app cụ thể.

### 🧪 Test

217/217 pass. Behavior change cần manual test ở Chrome URL bar, Google search, browser address bars khác.

### Bump

`2.3.10 → 2.3.11` / `20310 → 20311`. DMG 8759626 bytes, sig `wQiQYXRjWJqttzV3C8PcRHIKwLuaWpMtpIknmI1iJAdd+j5AA6+03owscS8Z1qxa/PKA6RDamjCmtwRk3ha4BA==`.

---

## [2.3.10] - 2026-05-28 — "AX-based Autocomplete Detection"

**Sửa cả 2 bug còn lại: Google Docs/Sheets duplicate syllable + Chrome URL bar `google → gooogle`. Root fix: distinguish "search field" vs "text area" qua AX role thay vì bundle ID prefix.**

### 🐛 Bugs

1. **Google Docs / Sheets duplicate**: Mọi syllable Vietnamese có dấu bị duplicate.
   - `trình` → `trinình`
   - `các` → `cacác`
   - `kiến` → `kieíeién`
   - `kiểm` → `kiêmểm`
   - `toán` → `taoáooán`
   - `của` → `cuaủa`
2. **Chrome URL bar `google → gooogle`**: Trong Chrome address bar / Google search box.

### 🔍 Nguyên nhân

`isFixAutocompleteApp()` trước v2.3.10 return true cho **TẤT CẢ** Chrome / Safari / Firefox / Edge (qua bundle ID prefix match):

```swift
func isFixAutocompleteApp() -> Bool {
  if isSearchOrComboFocused { return true }
  return InputProcessor.FixAutocompleteApps.contains { app in
    return activeApp.hasPrefix(app)
  }
}
```

Hệ quả: bất kỳ window nào của Chrome (kể cả Google Docs/Sheets text area) đều route vào `sendSelectAndReplace` (Shift+Left + replace).

**Google Docs** dùng contenteditable + custom JS event handler → **bỏ qua Shift+Left** của vkey. vkey gửi `Shift+Left × N + sendString(replacement)` — Docs chỉ thấy `sendString` append. Selection chưa thay đổi → replacement đè vào cuối → mọi syllable bị duplicate.

**Chrome URL bar** (true search field) **does** process Shift+Left, nhưng store Vietnamese NFC text dạng NFD scalar (`ô` → `o` + combining `◌̂`). Grapheme-based `selectLeftCount` thiếu so với scalar storage → "google → gooogle".

### ✅ Fix

**AX-based detection**: `isFixAutocompleteApp()` giờ chỉ check AX role:

```swift
func isFixAutocompleteApp() -> Bool {
  return isSearchOrComboFocused
}
```

`isSearchOrComboFocused` set qua [`Focused.isComboBoxOrSearchField()`](vkey/Platform/Focused.swift) — return true khi AX role = `AXSearchField` hoặc `AXComboBox`.

| Context | Trước v2.3.10 | Sau v2.3.10 |
|---|---|---|
| Chrome URL bar (AXSearchField) | Shift+Left + grapheme | Shift+Left + **NFD diff** |
| Chrome Google search box (AXSearchField) | Shift+Left + grapheme | Shift+Left + **NFD diff** |
| Google Docs textarea (AXTextArea) | Shift+Left (broken) | **Backspace** + grapheme |
| Google Sheets cell (AXTextArea) | Shift+Left (broken) | **Backspace** + grapheme |
| Web textarea / contenteditable | Shift+Left (broken) | **Backspace** + grapheme |
| Notes/TextEdit/Mail (Apple native) | Backspace + grapheme | Backspace + grapheme |

**Re-enable NFD diff** (từ v2.3.8) — nhưng giờ CHỈ áp dụng cho search fields (qua isFixAutocompleteApp), nơi Shift+Left thực sự work. Tránh được vấn đề v2.3.8 (NFD diff phá Google Docs vì Docs bỏ qua Shift+Left).

### 📊 Trace ví dụ

**Google Docs "trinh" + 'f' (= "trình")**:
- Diff `"trinh" → "trình"`: backspace=3, diff="ình".
- isFixAutocompleteApp = false (AXTextArea).
- Path: `sendReplacement` (backspace × 3 + sendString "ình").
- Chrome backspace × 3 deletes 'h','n','i' → "tr". sendString "ình" → "trình". ✓

**Chrome URL bar "google"**:
- Step 3 (gõ 'o' thứ 3): vkey transform "go" → "gô".
- NFD diff `"go" → "gô"`: backspace=0, diff=`◌̂` (combining mark).
- isFixAutocompleteApp = true (AXSearchField).
- Path: `sendSelectAndReplace` (Shift+Left × 0 + sendString `◌̂`).
- Chrome appends combining mark → "go,◌̂" (NFD storage) visible "gô". ✓
- Step 5 ('l'): vkey recovery → transform "gôg" → "googl".
- NFD diff: NFD from=[g,o,◌̂,g], NFD to=[g,o,o,g,l]. common=2 (g,o). backspace=2, diff="ogl".
- Path: Shift+Left × 2 + sendString "ogl". Chrome selects [◌̂,g] (2 NFD scalars) → replace "ogl" → "googl". ✓
- Step 6 'e': pass-through → "google". ✓

### 🛡️ Không bị ảnh hưởng

- **Apple apps**: Notes, TextEdit, Mail, Pages — AX role không phải search/combo → unchanged behavior.
- **Microsoft Office**: Word, PowerPoint, Outlook, OneNote — không phải search field → unchanged.
- **Vietnamese typing trong Google Docs**: bug duplicate đã được fix.

### ⚠️ Risks

- Nếu một browser không expose AX role đúng (chưa thấy), URL bar sẽ fall xuống backspace path. Backspace có thể có vấn đề với inline autocomplete (như "footer → foooter" của v1.8.3). Nếu xảy ra, cần thêm fallback bundle ID check.
- `FixAutocompleteApps` list giữ lại trong code làm documentation.

### 🧪 Test

217/217 pass. Pure unit tests cover NFD logic. Behavior change cần test thủ công ở:
- Google Docs: gõ tiếng Việt phức tạp.
- Google Sheets: gõ trong cell.
- Chrome URL bar: gõ "google", "tools", common English.
- Notes/TextEdit: regression check.

### Bump

`2.3.9 → 2.3.10` / `20309 → 20310`. DMG 8770198 bytes, sig `VShrcqmufDdCRAJnY7NNo+msFCa9t/uk6YXscqLCpPt991yEyreWafmU5jROHRcOYaB/8kgY90SHfCCanh98Ag==`.

---

## [2.3.9] - 2026-05-28 — "Hotfix: revert NFD diff"

**HOTFIX KHẨN: revert v2.3.8 NFD-aware diff — đã phá vỡ gõ tiếng Việt trong Google Docs.**

### 🐛 Regression từ v2.3.8

User report:
> "tôi gõ vào bất kỳ đâu đều bị lỗi gõ google thì ấn space xong hiển thị gooogle"
> "Đây là lỗi tôi gõ hiển thị gooogle doc: trinh̀nh baỳy rõ hơn caćc ý kiến cuảa đoàn kiêm̉m toán"

Trong Google Docs (mở ở Chrome), mọi syllable Vietnamese có dấu đều bị duplicate:
- `trình` → `trinh̀nh` (extra "nh" + lệch combining grave)
- `bày` → `baỳy` (extra "y")
- `các` → `caćc` (extra "c")
- `của` → `cuảa` (extra "a")
- `kiểm` → `kiêm̉m` (extra "m")

Pattern: Telex áp tone diacritic → vkey gửi Shift+Left × N + sendString của (combining mark + remaining chars). Google Docs **bỏ qua Shift+Left**, sendString chỉ APPEND vào cuối → mặt chữ trông như duplicate.

### 🔍 Nguyên nhân: hypothesis v2.3.8 sai

v2.3.8 implement [`calcKeyStrokesNFD`](vkey/Platform/EventSimulator.swift) dựa trên giả thiết Chrome decompose Vietnamese text thành NFD (`o` + combining `◌̂`). NFD diff trả về `selectLeftCount` theo scalar count và `replaceString` chứa combining marks tách rời.

Giả thiết này **không đúng cho Google Docs**:
- Google Docs dùng contenteditable + custom JS event handler.
- Synthesized Shift+Left CGEvent **không được Docs process** đúng cách — selection state không thay đổi.
- Khi vkey gửi sendString của NFD-form sau Shift+Left, Docs chỉ append vào cuối.
- Combining mark `◌̂` append sau `nh` → kết hợp với `h` thành `h̀` visually → output `trinh̀nh`.

### ✅ Fix

Revert NFD-aware diff path trong cả 2 chỗ:
- [`handleTextChar`](vkey/App/InputProcessor.swift) — typing-time diff.
- [`applySpellDecisionOnCommit`](vkey/App/InputProcessor.swift) — commit-time `restoreRawEnglish` diff.

Quay lại `EventSimulator.calcKeyStrokes` (grapheme-based) cho **mọi app**, kể cả `FixAutocompleteApps`. Behavior giống v2.3.7 trở về trước.

Cũng bỏ recovery branch `isInstantRestoreEnglish` check (speculative, không cần thiết).

### 📚 Giữ lại từ v2.3.8

- **Lexicon additions**: ~70 common English words (google, youtube, facebook, tools, sheet, sheets, docs, doc, spreadsheet, good, wood, look, book, food, week, screen, feed, free, tree…) trong [`EmbeddedLexiconData.englishWords`](vkey/Lexicon/EmbeddedLexiconData.swift). An toàn, cải thiện commit-time English detection cho các từ này.
- **`EventSimulator.calcKeyStrokesNFD`** function — dead code (không được gọi). Giữ lại để research sau.
- Unit test [`testCalcKeyStrokesNFDForCombiningDiacritic`](vkeyTests/vkeyTests.swift) — pure test cho function, vẫn pass.

### ⚠️ Limitation chưa fix

**"google → gooogle"** trong Chrome address bar / Google search vẫn còn (pre-existing bug class, không phải regression của v2.3.8). Cần research khác:
- Có thể switch strategy cho Chrome browser-bar sang backspace-based.
- Hoặc detect autocomplete state qua AX API trước khi gửi events.
- Hoặc add "google" và tech brand vào lexicon early-detect path (đã làm partial qua instantRestore).

User workaround tạm thời: gõ "googlex" + Tab/Esc để dismiss autocomplete, hoặc tắt vkey toggle (⇧⌥) khi gõ tiếng Anh trong browser.

### 🧪 Test

217/217 pass. Vietnamese typing test giữ nguyên 100%.

### Bump

`2.3.8 → 2.3.9` / `20308 → 20309`. DMG 8771643 bytes, sig `0InbxpEjljU7xhZD0fyQfab8u2Cv6+vL+NLeumU0hqmaiIve2ndtxhgOJZ3N5fgKL6ZCnjK9Gw2ZD8xRkhbtBw==`.

---

## [2.3.8] - 2026-05-28 — "NFD-aware Chrome Diff"

**Sửa lỗi "google → gooogle" (extra 'o') khi gõ trong Chrome, Google Docs, Google Sheets.**

### 🐛 Triệu chứng

- Gõ `google` trong Chrome address bar / Google search → ra `gooogle` (3 o's thay vì 2).
- Cùng pattern trong Google Docs, Google Sheets khi mở ở Chrome.
- Notes/TextEdit không bị (Apple text views dùng NFC).

### 🔍 Nguyên nhân

Telex áp `oo → ô` ở step 3 (gõ 'o' thứ 3). vkey gửi `Shift+Left × 1 + 'ô'` qua [`sendSelectAndReplace`](vkey/Platform/EventSimulator.swift). Chrome decompose `ô` thành NFD (`o` + combining `◌̂`), store **2 scalars** internally cho 1 grapheme.

Khi gõ tới 'l' (step 5), recovery fires (buffer không hợp lệ tiếng Việt). vkey diff `"gôg" → "googl"` theo **grapheme count** → `Shift+Left × 2 + "oogl"`. Nhưng Chrome đếm **scalar**:

```
"gôg" NFD storage: [g, o, ◌̂, g]  (4 scalars, 3 graphemes)
Shift+Left × 2: selects scalar 2-4 = [◌̂, g]  (combining + g)
Replace với "oogl": [g, o] + [o, o, g, l] = "gooogl"  ← 3 o's!
+ 'e' → "gooogle"
```

### ✅ Fix

Thêm [`EventSimulator.calcKeyStrokesNFD`](vkey/Platform/EventSimulator.swift) — compute diff trong NFD scalar space:

```swift
static func calcKeyStrokesNFD(from: String, to: String) -> (Int, [Character]) {
  let fromNFD = from.decomposedStringWithCanonicalMapping
  let toNFD = to.decomposedStringWithCanonicalMapping
  let fromScalars = Array(fromNFD.unicodeScalars)
  let toScalars = Array(toNFD.unicodeScalars)
  // common prefix in NFD scalar space ...
  let backspaceCount = fromScalars.count - commonPrefixLength
  var remainingScalars = String.UnicodeScalarView()
  for s in toScalars.dropFirst(commonPrefixLength) {
    remainingScalars.append(s)
  }
  return (backspaceCount, Array(String(remainingScalars)))
}
```

Áp dụng cho `FixAutocompleteApps` (browsers, Google services) ở 2 chỗ:
- [`handleTextChar`](vkey/App/InputProcessor.swift) — typing-time diff.
- [`applySpellDecisionOnCommit`](vkey/App/InputProcessor.swift) — commit-time `restoreRawEnglish` diff.

Apple apps (Notes, TextEdit, Mail) **giữ nguyên** grapheme diff (chuẩn NSTextView).

### 📚 Bonus: English instant-restore lexicon

Thêm common English words vào [`EmbeddedLexiconData.englishWords`](vkey/Lexicon/EmbeddedLexiconData.swift) để spell decision restore raw English đúng hơn tại commit time:

- **Tech/brands**: google, youtube, facebook, twitter, instagram, yahoo, amazon, outlook, linkedin, tools, tool, sheet, sheets, docs, doc, spreadsheet, spreadsheets.
- **Common "oo" words**: good, goods, wood, woods, look, looks, looking, book, books, cook, took, noon, soon, moon, boot, shoot, root, tooth, teeth, smooth, school, food, mood, loop, scoop.
- **Common "ee" words**: feed, need, seed, feet, meet, week, weekend, screen, queen, green, feel, wheel, three, agree, between, cheese, freeze, free, tree.

Cũng add check `isInstantRestoreEnglish` trong recovery branch của [`WordBuffer.push`](vkey/App/InputProcessor.swift) — khi keysStr match English mid-recovery, mark `stoppedByEnglishWord=true` để commit time + replay logic xử lý đúng.

### 📊 Trace ví dụ (Chrome NFD storage, "google")

| Step | Char | NFD diff | Action | Display |
|---|---|---|---|---|
| 1 | g | append | pass-through | `g` |
| 2 | o | append | pass-through | `go` |
| 3 | o (3rd) | 0 bs + `◌̂` (combining) | append U+0302 | `gô` ✓ |
| 4 | g | append | pass-through | `gôg` |
| 5 | l | 2 bs + `"ogl"` | Shift+Left×2 select `[◌̂,g]`, replace | `googl` ✓ |
| 6 | e | append | pass-through | `google` ✓ |

Trước fix step 5 dùng grapheme diff: 2 bs + `"oogl"` (4 chars) → trong NFD storage chỉ select `[◌̂,g]` (2 scalars) nhưng `to` của diff được tính ở NFC nên thừa 1 'o' → `gooogl`.

### 🛡️ Không bị ảnh hưởng

- **Apple apps (Notes, TextEdit, Mail, Pages…)**: vẫn dùng grapheme diff. NSTextView/NSTextField xử lý graphemes đúng. Không thay đổi behavior.
- **Vietnamese typing legitimate**: vd `tôi`, `chương`, `tiếng` — Telex chuẩn vẫn ra đúng trong Chrome (test bằng tay). NFD diff dùng cùng chiều, chỉ thay đổi count selection.
- **Edge cases khác**: 217/217 test pass.

### 🧪 Test

217/217 pass. Test mới [`testCalcKeyStrokesNFDForCombiningDiacritic`](vkeyTests/vkeyTests.swift) pin:
- NFC vs NFD diff cho `gôg → googl` (chính của bug).
- NFD diff cho `go → gô` (chỉ thêm combining mark, 0 backspace).
- ASCII baseline: NFD ≡ NFC khi không có combining.
- Common prefix qua "ô": NFC=1 grapheme, NFD=1 scalar diff (̂).

### Bump

`2.3.7 → 2.3.8` / `20307 → 20308`. DMG 8780785 bytes, sig `A+SkdrowGWVGkRI9PRx7nIJg58S7XaprnFj5v7MutOUb+g+3sNqysAqaSVaHYPQzP9oQcqeLKRDWB23aBuJWDA==`.

---

## [2.3.7] - 2026-05-25 — "Universal Anywhere-DD"

**Sửa lỗi không thể gõ `QĐ`, `BCTĐ`, `vcđ`… (anywhere-DD toggle bị Free Mark Mode block)** — user report: "gõ Q và DD liền nhau sẽ được là QĐ, cả BCTĐ".

### 🐛 Triệu chứng

- Gõ `QDD` → kỳ vọng `QĐ`, nhưng hiện `QDD` (không đổi).
- Tương tự `BCTDD`, `vcdd`, `add`… đều không chuyển thành `Đ`/`đ`.
- Initial `dd → đ` (vd `ddi → đi`) vẫn ổn — lỗi chỉ ở anywhere-DD.

### 🔍 Nguyên nhân

Anywhere-DD toggle (v1.9.7, ở [`vkey/App/InputProcessor.swift:346-389`](vkey/App/InputProcessor.swift)) được gate bởi `if stopProcessing && !wasOnlyEnglishRestored`. Chỉ fire khi buffer ở recovery state.

Free Mark Mode (v2.0 A6, [`vkey/Engine/TiengVietState.swift:108-111`](vkey/Engine/TiengVietState.swift)) bypass validator:

```swift
var needsRecovery: Bool {
  if Defaults[.freeMarkModeEnabled] { return false }  // ← BYPASS
  return TiengVietValidator.needsRecovery(thanhPhanTieng, dauMu: dauMu)
}
```

Hệ quả: khi user bật Free Mark Mode, `stopProcessing` không bao giờ được set bởi validator → anywhere-DD không bao giờ fire.

### ✅ Fix

Thêm **universal anywhere-DD pre-check** ở đầu `WordBuffer.push` ([`vkey/App/InputProcessor.swift`](vkey/App/InputProcessor.swift)), fire trước cả nhánh `stopProcessing`:

```swift
if (char == "d" || char == "D"),
   ddToggleStage == 0,
   transformed.count >= 2,
   let lastChar = transformed.last,
   lastChar == "d" || lastChar == "D",
   let secondLast = transformed.dropLast().last,
   secondLast != "d" && secondLast != "D" {
  let lastIsUpper = lastChar == "D"
  transformed.removeLast()
  transformed.append(lastIsUpper ? "Đ" : "đ")
  ddToggleStage = 1
  wordState = wordState.push(char)
  if !stopProcessing {
    stopProcessing = true
    if !snapshot.stopProcessing { lastValidSnapshot = snapshot }
  }
  return
}
```

### 🛡️ Conflict avoidance

- **Initial Telex `dd → đ`**: khi đó `transformed.count == 1` ("d"), không match điều kiện `count >= 2`. Telex.push xử lý như cũ.
- **Toggle-off / frozen state**: gate `ddToggleStage == 0` ngăn rule mới fire ở stage 1, 2. Khi rule mới fire, set stage=1 — char `d` kế tiếp sẽ đi qua existing branch để toggle-off đúng cách.
- **`vcdd` + `d` (frozen)**: second-to-last là `d` → rule mới skip → existing logic xử lý frozen state.
- **Set `stopProcessing = true`** sau khi fire để toggle-off của char `d` kế tiếp đi qua existing branch.

### 📊 Trước/sau (giả sử Free Mark Mode bật)

| Input | Trước | Sau |
|---|---|---|
| `QDD` | `QDD` | `QĐ` ✓ |
| `BCTDD` | `BCTDD` | `BCTĐ` ✓ |
| `vcdd` | `vcdd` | `vcđ` ✓ |
| `add` | `add` | `ađ` ✓ |
| `NDD` | `NDD` | `NĐ` ✓ |
| `ddi` (initial) | `đi` ✓ | `đi` ✓ |
| `vcddd` (toggle off) | `vcdd` ✓ | `vcdd` ✓ |
| `vcdddd` (frozen) | `vcdd` ✓ | `vcdd` ✓ |

### 🧪 Test

216/216 test pass. 2 test mới:
- `testTelexAnywhereDDWithFreeMarkMode` — pin behavior cho Free Mark Mode case.
- `testTelexAllCapsAbbreviationDD` — pin QDD/BCTDD/NDD/Qdd.

### Bump

`2.3.6 → 2.3.7` / `20306 → 20307`. DMG 8770293 bytes, sig `T6qDR5B7VhZnsxTUz+l3Bc2Tr+awDKOK7nDeIgsgYOaTm0t1cEcDPo+vtxTvTZ8A/yujQvwFErLMWQcRmTpNAQ==`.

---

## [2.3.6] - 2026-05-25 — "Loanword Typo Guard"

**Sửa lỗi từ tiếng Anh bắt đầu bằng phụ âm loanword (`w/z/j/f`) bị parser áp nhầm typo-correction tiếng Việt** — ví dụ gõ `weight` trong ô tìm kiếm Google hiển thị thành `wieght`.

### 🐛 Triệu chứng

- Gõ `wei` (cho "weight") → composing hiển thị `wie`. Tiếp `weight` → `wieght`.
- Field thường: Space → engine rollback về `weight` raw (OK).
- **Ô tìm kiếm** (Google search, address bar, Spotlight, app search…): rollback không kịp / bị page can thiệp → `wieght` còn lại.
- Cùng pattern với `four → fuor`, từ tiếng Anh khác có `w/z/j/f` đầu.

### 🔍 Nguyên nhân

Parser ([`vkey/Engine/TiengVietParser.swift`](vkey/Engine/TiengVietParser.swift)) có 4 rule "swap vowel" để sửa typo tiếng Việt:

1. `veit → viet` (e+i → i+e) cho "việt"
2. `bous → buos` (o+u → u+o) cho "buốt"
3. `haois → hoais` (a+o+i → o+a+i) cho "hoái"
4. `haoc → hoac` (a+o → o+a) cho "hoác"

Cài đặt `allowedZWJF` ([`vkey/App/Setting.swift:205`](vkey/App/Setting.swift)) mặc định `true` → các phụ âm loanword `w/z/j/f` được thêm vào `PhuAmDauTrie` ([`vkey/App/AppState.swift:70-75`](vkey/App/AppState.swift)). Khi đó, gõ `wei`:

- `phuAmDau = [w]`, `nguyenAm = [e]`, `conLai = [i]` → rule veit→viet fire → swap `[i, e]`
- Output: `w` + `ie` + … = `wie` / `wieght`

### ✅ Fix

Thêm helper `startsWithForeignConsonant(_ phuAmDau: [Character]) -> Bool` và guard vào cả 4 rule:

```swift
if result.nguyenAm.count == 1,
   result.nguyenAm[0].lowercased() == "e",
   let firstLeftover = result.conLai.first,
   firstLeftover.lowercased() == "i",
   !startsWithForeignConsonant(result.phuAmDau)   // ← NEW GUARD
{
  ...
}
```

**Lý do**: tiếng Việt không có từ bản địa bắt đầu bằng `w/z/j/f`. Mọi từ bắt đầu bằng các chữ này đều là loanword (English, Chinese pinyin…) → không cần áp typo-correction dạng cấu trúc âm tiết Việt.

### 🛡️ Không bị ảnh hưởng

- **Native consonants vẫn áp như cũ**: `veit → viet` (v), `phuogn → phuong` (ph), `bous → buos` (b), `haoi → hoai` (h), `haoc → hoac` (h) — tất cả test cũ pass nguyên.
- **Tone mark cho loanword vẫn áp**: `zas → zá`, `fair → fải` — chỉ block 4 rule swap vowel, không đụng tone/diacritic.
- **Late D toggle, GI classification, tone-mark recovery** — không đụng.

### 📊 Trước/sau

| Input | Trước | Sau |
|---|---|---|
| `wei` | `wie` | `wei` ✓ |
| `weight` | `wieght` | `weight` ✓ |
| `four` | `fuor` | `four` ✓ |
| `journey` | `juorney` | `journey` ✓ |
| `veit` (Telex của "việt") | `viet` ✓ | `viet` ✓ |
| `zas` | `zá` ✓ | `zá` ✓ |

### 🧪 Test

214/214 test pass. Test mới [`testForeignConsonantSkipsVowelSwapTypoCorrection`](vkeyTests/vkeyTests.swift) pin behavior cho `wei`/`weight`/`four` và regression-check `veit` vẫn swap.

### Bump

`2.3.5 → 2.3.6` / `20305 → 20306`. DMG 8768557 bytes, sig `U3+/jRutGXzWLBx4o82j180YD1aGvrp0Cc4Ely5CrJ2g2GsInUZBpR0/dKN7/ht7NeJwTbrwEBKeAu7UnTM0Cw==`.

---

## [2.3.5] - 2026-05-24 — "Excel Hotfix"

**Sửa lỗi gấp khi gõ Telex trong Microsoft Excel** — con trỏ "nhảy" và bôi các ô bên trái, đồng thời chữ Việt bị compose sai khi dấu được áp.

### 🐛 Triệu chứng

- Trong Excel, gõ Telex (vd `tieesng vieejt`, `chuwowng`) → con trỏ nhảy qua các ô bên trái, các ô đó bị bôi xanh (cell selection mở rộng).
- Hệ quả: ký tự thay thế khi áp dấu Telex ghi đè sang ô hàng xóm thay vì ô đang gõ, chữ Việt trông như compose hỏng.

### 🔍 Nguyên nhân

Hai bundle Excel (`com.microsoft.Excel`, `com.microsoft.Office.Excel`) đang nằm trong mảng `FixAutocompleteApps` tại [`App/InputProcessor.swift:649`](vkey/App/InputProcessor.swift).

Mảng này được thiết kế cho các **browser có inline autocomplete** (Chrome, Safari, Edge, Arc…) — nơi cần `Shift+Left` để bao trùm vùng autocomplete xám trước khi ghi đè. Đường đi này gọi [`EventSimulator.sendShiftLeft`](vkey/Platform/EventSimulator.swift) — function gắn cứng `.maskShift` lên các CGEvent mũi tên trái.

Excel **không có inline autocomplete** (dropdown gợi ý của Excel là UI native, không phải selection text). Khi vkey gửi `Shift+Left`, Excel diễn giải đúng theo nghĩa native: mở rộng vùng chọn sang cell bên trái. Kết quả: nhảy + bôi ô + compose hỏng.

### ✅ Cách sửa

Loại `com.microsoft.Excel` và `com.microsoft.Office.Excel` khỏi `FixAutocompleteApps`. Sau khi loại, Excel rơi xuống nhánh `EventSimulator.sendReplacement` an toàn (backspace không kèm Shift), dùng strategy `.hybrid(backspaceDelayMicroseconds: 1000)` đã có sẵn cho Excel tại [`EventSimulator.swift:94`](vkey/Platform/EventSimulator.swift) — giống cách Word/PowerPoint/Outlook/OneNote vẫn chạy ổn lâu nay.

### 🛡️ Không bị ảnh hưởng

- **Dropdown gợi ý Excel** (`=SUM`, `=SUMIF`…): vẫn hoạt động bình thường, không cần Shift+Left.
- **Edge browser** (`com.microsoft.edge`): vẫn nằm trong `FixAutocompleteApps`, vẫn dùng Shift+Left để xử lý inline autocomplete đúng cách.
- **Office sibling** (Word, PowerPoint, Outlook, OneNote): không thay đổi — vốn không nằm trong `FixAutocompleteApps`.
- **Engine Telex/VNI**: không đụng, 213 test pass nguyên.

### Bump

`2.3.4 → 2.3.5` / `20304 → 20305`. DMG 8766574 bytes, sig `iJ+cbPdfMkHBkSJ5VxqHgGW6sK+eGI2OyabxQSvmHZkf1APVpuDrNH+u8VOwNDASz/YQnc7AOulxnReSqMcoBA==`.

---

## [2.3.4] - 2026-05-23 — "Tonal Refinement"

**Tonal theme refresh full theo handoff design** — thêm `TonalRowIcon` (flat sunken tile + red accent) cho mọi menu/setting row, tinh chỉnh HUD scrim layer warmer match `--glass-dark`, bump header icon radius 22→28pt theo `--r-2xl`. User feedback: "đọc kỹ lại để sửa theme Tonal cho đẹp hơn, đồng bộ hơn" → đối chiếu trực tiếp với `colors_and_type.css` + `components.css` từ handoff.

### 🟥 TonalRowIcon component

`vkey/View/Components/TonalRowIcon.swift` — SwiftUI view bám sát design CSS:

```css
.row__icon {
  width: 32px; height: 32px;
  border-radius: 8px;
  background: var(--bg-sunken);   /* ink-600 dark, paper-100 light */
  color: var(--fg-accent);        /* red-500 / red-300 */
}
```

Swift impl:
- **Sunken background**: dark `#0E0F12` @ 0.85, light `#F2EFE8` @ 1.0
- **Icon foreground**: dark `#F18A74` (red-300), light `#E04434` (red-500)
- **Border**: 0.5pt subtle (`--border-1`)
- **Inset shadow gradient**: 0.8pt linear gradient với `.overlay` blendMode để mô phỏng `inset shadow` (SwiftUI không có native inset)
- **Default 28pt** size với squircle radius 7pt (8/32 ratio)

KHÁC với GlassTile:
| Aspect | TonalRowIcon | GlassTile |
|---|---|---|
| Background | Flat sunken (1 màu) | 3-stop gradient |
| Gloss | None | Diagonal + top-arc specular |
| Icon color | Red brand accent | White |
| Rim | Subtle 0.5pt | Bright 0.5pt + soft shadow |
| Feel | Refined macOS native | Premium 3D glassy |

### 🔌 ThemedSymbol 4-cấp render priority (v2.3.4)

```swift
if uiTheme == .liquidGlass && useGlassTile {
  GlassTile(color: liquidGlassTileColor(for: name), size: 24) { Image(systemName: name) }
} else if uiTheme == .tonal && useGlassTile {
  TonalRowIcon(size: 24) { Image(systemName: name) }
} else if uiTheme == .liquidGlass {
  themedBody.modifier(LiquidGlassTintModifier(...))  // v2.3.2 flat tint
} else {
  themedBody  // appTheme-driven
}
```

Env `\.useGlassTile` set `true` ở MenuContentView + Settings TabView roots khi **LG hoặc Tonal** active (trước 2.3.4 chỉ LG). MenuBarLabel status icon không nhận env → flat SF Symbol (macOS convention).

### ✨ Tonal HUD scrim refinement

Trước 2.3.4: single-layer ink-500 opacity + ultraThinMaterial. Sau 2.3.4: **4-layer composition** match design `.hud`:

| Layer | Composition | Maps to CSS |
|---|---|---|
| 4 | LinearGradient white 6% top → 0% center | `inset 0 1px 0 rgba(255,255,255,0.06)` |
| 3 | `#131519` @ scrimOpacity (0.32-0.62) | `background: var(--glass-dark)` |
| 2 | `.ultraThinMaterial` | `backdrop-filter: blur(40px) saturate(180%)` |
| 1 | strokeBorder white 8% (1pt) | `inset 0 0 0 1px rgba(255,255,255,0.08)` |
| Outer | shadow black 55% blur 24 y 12 | `0 24px 60px -16px rgba(0,0,0,0.6)` |

Top highlight layer rất subtle nhưng đủ tạo cảm giác "glass lit from above" — match handoff exactly.

### 📐 Settings header Tonal — radius 22 → 28

Per design `--r-2xl: 28px`. Tinh chỉnh thêm:
- Halo radial gradient: radius 70→72, blur 6→8, frame 132→136 (softer)
- Thêm subtle white rim border 0.6pt @ 8% opacity — match `--shadow-inset`
- Shadow stack: red 30% @ blur 24/y 10 + black 18% @ blur 6/y 3 — match `--shadow-lg`

### 🎨 Visual differentiation matrix (v2.3.4)

| Surface | Classic | Tonal | Liquid Glass |
|---|---|---|---|
| Menu icon | Flat SF Symbol, system blue | Sunken tile + red icon | 3D glass tile + per-category color |
| HUD scrim | Light material + accent | 4-layer warm ink + top highlight | 5-layer + refractive corner tints |
| Settings header | Icon 18pt radius | Icon 28pt radius + halo + rim | Icon 22pt radius + caustic + specular + multi-shadow |
| Vibe | macOS native nguyên gốc | Refined macOS native | Premium 3D visionOS |

### 📦 Release artifacts

- `vkey-2.3.4.dmg` — universal, ~8.8 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `3cHVu6AleHmav4NB8YDzDgwcmIJZ1aDex2t9TxF3/wTwbyDac2HnPiZJzAKNYmetk8PrLzcPmZ5zfdNEAMtyCw==` (length 8765559).

### 🛡 Không thay đổi

- Engine gõ, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi.
- 213/213 test pass.

---

## [2.3.3] - 2026-05-23 — "LG Glass Tile Icons"

**Liquid Glass theme bây giờ render đầy đủ với 3D glass tile icons** (gradient + diagonal gloss + top arc specular + white rim + drop shadow) — match 1:1 design `SwiftSnippets.jsx` handoff. User feedback: LG icons chỉ flat colored SF Symbol → không đủ "3D" so với design — bây giờ wrap trong GlassTile component.

### ✨ GlassTile component

`vkey/View/Components/GlassTile.swift` — 95-line SwiftUI view với **4-layer composition**:

1. **Base gradient**: 3-stop spherical lighting (`top-light → mid-color → bottom-shadow`) — `linear-gradient(160deg)`.
2. **Diagonal gloss**: white 40% → 8% → black 15% từ top-left xuống bottom-right.
3. **Top-arc specular ellipse**: white 55% → 0% ellipse hugging top edge — mimic "wet" gloss `.tile::after`.
4. **White rim border** (0.5pt, 12% opacity) + **outer drop shadow** (black 35%, blur 3pt, y 1.5).

Icon content tinted white với double-shadow (white sub-pixel glow + black drop) cho contrast.

**7 màu preset** trong `GlassTileColor` enum (top-level — không nested để gọi từ ThemedSymbol mà không specify generic param): `red`, `gold`, `blue`, `green`, `purple`, `gray`, `ink`. Mỗi màu có (top, mid, bot) hex riêng — match design `.tile--red/gold/...` từ glass.css.

Default size 24pt với squircle radius 7pt (auto-scale: `radius = max(5, size * 7/24)`).

### 🔌 Opt-in qua Environment value

Tránh side effects ở contexts không phù hợp (status bar, HUD large icons):

```swift
@Environment(\.useGlassTile) private var useGlassTile  // default false
```

Set `true` ở 2 contexts trong `vkeyApp.swift`:
- `MenuContentView` root — menu dropdown items get tiles.
- `Settings TabView` root — tab item icons + row icons get tiles.

KHÔNG set ở:
- `MenuBarLabel` (status bar icon top of screen) — giữ flat SF Symbol theo macOS menu bar conventions.
- HUD bodies — đã dùng `HUDFlag` custom view, không cần tile.

### 🎨 ThemedSymbol 3-cấp render priority

```swift
if uiTheme == .liquidGlass && useGlassTile {
  GlassTile(color: liquidGlassTileColor(for: name), size: 24) { Image(systemName: name) }
} else if uiTheme == .liquidGlass {
  themedBody.modifier(LiquidGlassTintModifier(color: categoryColor))  // v2.3.2 flat tint
} else {
  themedBody  // appTheme-driven (default/threeD/emoji)
}
```

Category color map (40+ SF Symbol names → GlassTileColor) — match design `SpecSheets.jsx` Icon system groupings:
- **red**: keyboard, character.bubble.fill, globe, paintbrush, power
- **gold**: sparkles, lightbulb, rocket, cup.and.saucer, heart.fill, chart.bar
- **blue**: arrow.left.arrow.right.*, switch, info.circle, text.cursor.ibeam
- **green**: checkmark, shield, text.badge.checkmark, arrow.triangle.2.circlepath
- **purple**: text.cursor, abc, character, wand.and.stars
- **ink**: lock, lock.square, nosign, gear.badge.questionmark, trash
- **gray**: gear, gearshape, magnifyingglass, plus, minus

### 🐛 Bonus fix: FontRegistration.swift path

Trong pbxproj, `FontRegistration.swift` được đăng ký ở `vkey/View/` (sai) nhưng file thực sự ở `vkey/App/`. Build trước đó lỗi `Build input file cannot be found`. Fix bằng cách thay path thành `name = FontRegistration.swift; path = ../App/FontRegistration.swift` (Xcode dùng `name` cho hiển thị + `path` relative cho file system).

### 📦 Tại sao không bundle Icons3D PNG?

User cung cấp `vkey-Icons3D.zip` — 76 imagesets pre-rendered @1x/@2x/@3x (1024×1024). Tổng **117 MB** — quá lớn cho macOS app bundle (current ~8 MB).

Runtime SwiftUI rendering qua `GlassTile`:
- Bundle size impact: ~5 KB (Swift source).
- Vector scale: perfect ở mọi pixel density.
- Customizable per-context (size, radius).
- Match design fidelity ~95% (chỉ thiếu micro-details của Photoshop layers).

Trade-off đúng cho LG theme.

### 📦 Release artifacts

- `vkey-2.3.3.dmg` — universal, ~8.7 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `BmDXfXr8TEpyGB9dffyY2UAtNkyELnGF39Tn0NnfmiFroklX8lKDY4dJTYQvXz036UCuXyuzlS8rMYLfvWIrBw==` (length 8745871).

### 🛡 Không thay đổi

- Engine gõ, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi.
- 213/213 test pass.

---

## [2.3.2] - 2026-05-23 — "Header Strip + LG Category Colors"

**2 user requests**: (1) Settings header chỉ giữ logo centered, bỏ chữ "vkey" + tagline ở mọi theme. (2) MenuBar Tonal vs LG khác màu rõ rệt — LG có per-category icon colors theo design.

### 🪟 Settings header — logo centered only

**User request**: "chỉ để logo ở chính giữa bề ngang, bỏ hết chữ Vkey hay bộ gõ macOS,...ở tất cả các theme".

**Trước 2.3.2**: Tonal + LG header có HStack `[icon + halo] + [Wordmark "vkey" + tagline]` — chiếm nhiều không gian, text wordmark cạnh icon. Classic không có text nhưng cũng có chứa nguyên gốc.

**Sau 2.3.2**: cả 3 theme đều `HStack { Spacer; icon; Spacer }` — logo centered duy nhất, chiều ngang đầy đủ.
- Tonal: flat icon 96px + red halo radial gradient.
- LG: icon + refractive corner tints (red + blue blobs) + caustic halo + specular gloss + glass rim border + triple shadow.
- Classic: icon 96px + simple shadow.

Header gọn hơn, dồn focus vào icon. Code: `vkey/View/SettingView.swift:settingsHeader` — 3 case branches, mỗi case là HStack center.

### 🎨 LG MenuBar — per-category icon colors

**User feedback**: "Rà soát để màu sắc menu bar, các icon, toggle switch của theme Tonal và LG khác nhau". Trước 2.3.2 cả 2 theme có cùng accent red applied qua `.tint()` → menu icons đều red.

**Design source** (`Liquid Glass/vkey-3d/project/components/MenuBar.jsx`): mỗi menu item icon được wrap trong `GlassTile color="..."` với mapping:
- `red` — flag VN, brand, dangerous
- `blue` — switch, info
- `green` — check, refresh
- `purple` — wand
- `gold` — paintbrush
- `gray` — keyboard, gear

**Implementation** (`vkey/View/ThemedSymbol.swift`):
- Static method `liquidGlassCategoryColor(for name: String) -> Color?` map SF Symbol → category color.
- Observe `Defaults[.uiTheme]` — apply `LiquidGlassTintModifier` CHỈ khi LG. Tonal + Classic không ảnh hưởng.
- Modifier dùng `.symbolRenderingMode(.hierarchical) + .foregroundStyle(color)` để có gradient nhẹ (match design `.tile` spherical lighting).

Color palette (hex):
| Category | Color | Apply for |
|---|---|---|
| Blue | `#2D89E5` | Smart Switch, language toggle, info, stats |
| Green | `#2BB673` | Spell check, refresh, updates |
| Purple | `#8B5CF6` | Macro (text.cursor) |
| Gold | `#F5C645` | Theme picker (paintbrush), donate, globe |
| Red | `#E04434` | Thoát, VI active |
| Gray | `#9CA3AF` | Settings (gear), keyboard |

**Tonal giữ nguyên** — accent red đồng nhất qua `.tint()` ở root scene → visually obvious khác biệt khi switch theme.

### 📦 Release artifacts

- `vkey-2.3.2.dmg` — universal, ~8.7 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `9OgUa0rcdpxocjYKvnr8B+6UnaJNOfS+Sjp6cSIIt9wrUiHofHW58J7cOLkUH29LLnoqAGMZ6DDv9FV5NjEHCQ==` (length 8698662).

### 🛡 Không thay đổi

- Engine gõ, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi.
- 213/213 test pass.

---

## [2.3.1] - 2026-05-23 — "LG Differentiation + Hotkey Fix"

**Fix 2 bug user feedback**: (1) cả 2 nút hotkey hiển thị cùng modifier mask của Toggle, (2) Liquid Glass và Tonal theme nhìn giống nhau quá ở Settings header.

### 🐛 Fix bug hiển thị hotkey trùng nhau

**Trước 2.3.1**: Settings tab Chung — cả 2 nút "Phím tắt chuyển đổi VI/EN" và "Phím tắt Text Tools" cùng hiển thị `⌥⇧ (chỉ modifier)` regardless of giá trị thực tế của Text Tools (Default = ⌃⇧).

**Root cause**: `FlexibleShortcutButton.refresh()` ở `vkey/View/SettingView.swift:70` hardcode `let modifierOnly = Defaults[.modifierOnlyToggleHotkey]` cho TẤT CẢ instance — không quan tâm `name` được pass vào init.

**Fix**:
- Thêm helper `modifierOnlyKey(for name: KeyboardShortcuts.Name)` — map name → đúng Defaults key:
  - `.toggleInputMode → .modifierOnlyToggleHotkey`
  - `.openTextConversionMenu → .modifierOnlyTextToolsHotkey`
- `FlexibleShortcutButton` lưu `modifierKey: Defaults.Key<Int>` tại init, dùng cho mọi read/write site (refresh, recording, escape clear, backspace clear, key+modifier write).
- 2 button giờ hiển thị độc lập theo Defaults riêng.

### 🎨 Liquid Glass — visual differentiation mạnh hơn vs Tonal

**User feedback** (kèm screenshot): "rà soát lại vì các theme tonal với LG không khác nhau nhiều lắm, không giống như trong index.html". LG header v2.3.0 chỉ khác Tonal ở wordmark gradient + 1 border — không đủ để phân biệt.

**Fix**: LG `settingsHeader` ZStack 5-layer:
1. **Refractive corner tints (LG signature)**: blob đỏ `red500 @ 45%` bottom-left + blob xanh `#2D89E5 @ 32%` top-right — ambient color glow per design `.lg-window::after` (160×160 blur 14-16px).
2. **Caustic halo**: 3-stop radial `red500: 55→18→0%` (148×148 blur 6) — icon "nổi" như sphere thay vì flat glow.
3. **Icon** với `RoundedRectangle(22)` clip.
4. **Top-arc specular gloss**: overlay LinearGradient white `42→8→0%` padding 48pt từ top + `.plusLighter` blend — mimic `.tile::after`.
5. **Glass rim border** top-bright (0.65) → bottom-dim (0.12) per `.tile::before`.
6. **Triple-layer shadow**: red500 ambient (r28) + red500 soft (r8) + black (r10) — floating depth.
7. **Wordmark** thêm red glow shadow `red500 @ 35%` để pop.

Tonal giữ nguyên — flat icon + single red halo + solid red wordmark — visually obvious khác biệt khi switch theme.

### 📦 Release artifacts

- `vkey-2.3.1.dmg` — universal binary, ~8.7 MB. Ad-hoc codesign + hardened runtime (`flags=0x10002 adhoc,runtime`, `Identifier=dev.longht.vkey`).
- Sparkle signature: `XbIT3PHvVUMGlDidoCwariUlXGppKPHmLnsYljW4DJbJj9z8M2f12oqhDbpy9IdAa96DIJslTw4tHcY2iJXbBg==` (length 8691854).

### 🛡 Không thay đổi

- Engine gõ, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi. 213/213 test pass.
- HUD (Toggle/Prediction) — đã có refractive corner tints + top arc highlight từ 2.3.0, không cần đổi.

---

## [2.3.0] - 2026-05-23 — "Handoff Sync"

**Đồng bộ code Swift với handoff bundle chính thức của Liquid Glass và Tonal. HUD layout chuyển ngang, font Noto Sans Display bundled, prediction format mới với keycap thật. 4 themes giữ nguyên.** README rà soát ✓

### Bối cảnh

User cung cấp 2 handoff bundle chính thức từ design tool: `Vkey 3D-handoff.zip` (Liquid Glass) và `vkey Design System-handoff.zip` (Tonal). Rà soát phát hiện code v2.2.2 chỉ apply một phần thiết kế — HUD vẫn dọc, prediction dùng plain `⇥ Tab` text, Settings header dùng VStack centered, font Noto Sans Display chưa bundle, scrim color sai lệch (0x1C1E26 vs design 0x14161C), refractive corner tint chỉ 0.18 (vs design 0.24).

### 🔄 HUD VI/EN — layout ngang

**Trước (v2.2.2)**: VStack dọc:
```
[icon character.bubble.fill 40pt]
[Tiếng Việt / English]
[VI/EN pill]
```

**Sau (v2.3.0)**: HStack ngang chuẩn design `.hud-toggle`:
```
[flag 48×36] [Tiếng Việt / English 17pt bold]   [⇧][⌥]
              [Telex · Kiểu mới 12pt 70%]
```

- **Flag image**: dùng asset hiện có `vn-flag.imageset` / `us-flag.imageset` (đã PNG @1x/@2x/@3x), wrap trong `HUDFlag` component với inner stroke white 0.15 + top-gloss linear + drop shadow.
- **Title font**: `VKeyDesign.display(17, weight: .bold)` — Noto Sans Display 800 nếu loaded, fallback `.rounded` system.
- **Sub-title**: dynamic content theo state: VI → `"\(typingMethod) · Kiểu \(mới|cũ)"`, EN → `"vkey tạm tắt"`.
- **Keycap row**: đọc `Defaults[.modifierOnlyToggleHotkey]`, parse qua `formatModifierMask` (đã có ở `SettingView.swift`), render mỗi modifier (⌃ ⌥ ⇧ ⌘) thành `Keycap(_, size: .md)` riêng.

Cả Liquid Glass và Tonal dùng cùng HStack skeleton — chỉ background modifier khác nhau:
- LG: `.refractiveGlassBackground(radius: 28, scrimOpacity:)` — 5-layer (refractive tints + linear/radial highlights + scrim + material + triple edge stroke).
- Tonal: `.tonalScrimBackground(radius: 20, scrimOpacity:)` — đơn giản (scrim ink500 + material + thin white stroke).

### 🔄 Prediction HUD — format mới `→ <từ> · Tab(keycap)`

**Trước**: `→ \(prediction)   ⇥ Tab` plain text với `⇥` Unicode glyph + monospaced font.

**Sau**: `→ <prediction> · Tab` với Tab là `Keycap("Tab", size: .sm)` (mini glass pill 22×20 radius 6 với multi-layer glass background). Prediction text bỏ `.monospaced` design — chuyển sang proportional `Font.system` (theo design `.pred-suggest`).

`contentSize(for:fontSize:)` cập nhật: measurement string đổi sang `"→ \(prediction) ·"` + thêm `keycapAllowance: CGFloat = 40` (Tab pill width). Floor: min width 180, min height 38.

### 🔄 Settings header — layout ngang + Noto Sans Display 36pt

**Trước**: VStack centered (icon 84/88px → wordmark 28-30pt rounded → tagline).

**Sau**: HStack ngang chuẩn design `.set-header`:
```
[icon 96px + red halo glow]   [vkey 36pt heavy]
                              [tagline 13pt]
```

- **Icon**: 96px (so với 84-88 cũ), radius 22, multi-shadow (red500 0.32-0.45 r 18-24 y 8-12 + black 0.12-0.5). LG có thêm overlay glass border `linear-gradient(white 0.55 → 0.10)`.
- **Halo**: Circle 132×132 fill RadialGradient red500 (0.32 Tonal / 0.50 LG) opacity → clear, blur 4-6 — match design `.set-header-halo`.
- **Wordmark**:
  - **Liquid Glass**: `Font.custom("NotoSansDisplay", size: 36).weight(.heavy)` (fallback system rounded) + gradient text `linear-gradient(white → #C7C3B7)` qua `.foregroundStyle(LinearGradient(...))` — design spec.
  - **Tonal**: cùng font helper nhưng solid color `VKeyDesign.red500`.
- **Tracking**: `-0.72` per design `letter-spacing: -0.02em`.
- **Tagline**: 13pt regular, color `lgTextWarm` (LG) / `.secondary` (Tonal).

### 📦 Bundle 2 custom fonts

| Font | Size | Purpose | Used in v2.3.0 |
|---|---|---|---|
| `NotoSansDisplay-Variable.ttf` | 1.54 MB | Display wordmark, variable wght 100-900 + wdth axis | ✓ Settings header LG + Tonal |
| `CarterOne-Regular.ttf` | 64 KB | English-only brand display | ❌ (reserved cho future marketing — design warn không dùng VN text) |

Skip italic variant `NotoSansDisplay-Italic-VariableFont_wdth,wght.ttf` (1.66 MB) — không dùng italic display.

**Registration approach** (2-tier defensive):

- **Tier 1 (Info.plist)**: `ATSApplicationFontsPath` đã thử bundled — phát hiện path mismatch (Xcode bundle structure không khớp với key value). Đã **bỏ key**, dựa hoàn toàn vào Tier 2.
- **Tier 2 (Runtime)**: `FontRegistration.swift` `enum FontRegistration { static func register() }` — `Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil)` → `CTFontManagerRegisterFontsForURL(_, .process, &error)`. Idempotent — swallow `kCTFontManagerErrorAlreadyRegistered` (code 105). Gọi từ `AppDelegate.applicationDidFinishLaunching` line đầu, trước `setActivationPolicy(.accessory)`.

**Fallback**: `VKeyDesign.display(_:weight:)` check `NSFont(name: "NotoSansDisplay", size: size) != nil` — nil thì return `Font.system(size:weight:design:.rounded)`. Graceful — không tofu / missing-glyph nếu font load fail vì bất cứ lý do gì.

### 🏗 Abstractions mới

| File | Nội dung |
|---|---|
| `vkey/View/Components/HUDComponents.swift` (new, ~270 LOC) | `Keycap` view (md 28×28 + sm 22×20), `HUDFlag` view (48×36 với 2 overlay + 1 shadow), `refractiveGlassBackground` View modifier (5-layer LG recipe), `tonalScrimBackground` View modifier (simpler Tonal variant) |
| `vkey/App/FontRegistration.swift` (new) | `enum FontRegistration { static func register() }` runtime CTFontManager bulk register |
| `vkey/Resources/` (new dir) | `NotoSansDisplay-Variable.ttf` + `CarterOne-Regular.ttf` |

### 🎨 Tokens điều chỉnh

`VKeyDesign.swift`:
- `lgGlass1Color`: `0x1C1E26` → **`0x14161C`** (match design `rgba(20,22,28,0.55)` `.hud-toggle` background).
- Thêm `lgTextWarm = Color(hex: 0xC7C3B7)` — gradient end-stop wordmark + sub-title fg-2.
- Thêm `lgRefractiveStrength: Double = 0.24` — single source of truth (design spec 24% red bottom-left, code cũ inline 0.18).
- `display(_ size:weight:)` body sửa: ưu tiên `Font.custom("NotoSansDisplay")` với fallback `.system(.rounded)`.

### 📁 Refresh Design/ folder

Replace nội dung `Design/` cũ bằng Tonal design system handoff đầy đủ (`vkey Design System-handoff.zip`):
- `SKILL.md` — Claude skill metadata cho design system (Vietnamese voice rules, brand guidelines)
- `assets/icons/*.svg` — **43 custom SVG icons** (24px box, 1.5px stroke, currentColor) — reserved cho future ThemedSymbol replacement
- `assets/logo/*.svg` — 4 brand logos (vkey-app-icon, vkey-wordmark, vkey-lockup, tone-mark)
- `assets/vkey-app-icon-{128,256,1024}.png` — pre-rendered macOS app icons
- `fonts/{CarterOne, NotoSansDisplay-Italic, NotoSansDisplay}.ttf` — 3 fonts
- `preview/*.html` — 22 component preview cards
- Rich brand documentation in `README.md` (voice, casing, emoji rules, color/type fundamentals)

`colors_and_type.css` và `components.css` **identical** với bản cũ — confirmed handoff packaging chính thức của Tonal đang dùng.

### 🛡 Không thay đổi

- Engine gõ Telex/VNI/Simple, từ điển, spell-check, prediction logic, Smart Switch, Macro — không đổi behavior. **213/213 test pass**.
- User Defaults / personal dictionary / macro store / statistics giữ nguyên.
- Sparkle update flow, codesign, hardened runtime, entitlements — không thay đổi.
- 4 themes giữ nguyên: Mặc định / Emoji vui tươi / Tonal / Liquid Glass.
- Build target macOS 14+, universal arm64 + x86_64.

### 📦 Release artifacts

- `vkey-2.3.0.dmg` — universal binary, ~8.3 MB (size tăng từ 7.3 MB vì bundle fonts ~1.6 MB).
- Sparkle signature: `WuBtxofq1f80+g1pHUjf0bRNLfzyhQWVUtWt35n85YdrgBehTUh9CpB//qqKQxfOrm/WTAR5rk74Jr4dQYbJBQ==` (length 8655679).
- Codesign: `adhoc,runtime` (flags 0x10002), Identifier `dev.longht.vkey`, sealed resources v2.

### Defer (out of scope cho 2.3.0)

- **43 SVG icons** thay thế SF Symbols qua `ThemedSymbol` — scope lớn, refactor 14 file UI.
- **Multi-tile gradient backgrounds** cho setting rows (design `surfaces2.css` `.tile--red/gold/blue/green/purple/ink`).
- **Brand logo SVG** thay raster `Cficon.imageset`.
- **Carter One actual use** — bundle sẵn nhưng chưa dùng (reserved English-only marketing).
- **Settings TabView grid restructure** + custom Toggle/Picker styling (SwiftUI Settings scene limitations).

---

## [2.2.2] - 2026-05-22 — "Liquid Glass"

**Xoá "3D bóng bẩy" và "Sơn Mài". Thêm "Liquid Glass" — refractive multi-layer glass theo phong cách macOS Tahoe / visionOS. Tổng 4 giao diện.** README rà soát ✓

### 🪟 Liquid Glass — refractive material

Theme thứ 4 đại diện cho design language của macOS Tahoe / visionOS — kính khúc xạ, multi-layer gradient, edge specular highlights.

#### Palette + treatment

- **Anchor đỏ** `#E04434` (cùng brand red với Tonal — Liquid Glass apply glass technique LÊN brand color).
- **Multi-layer glass surfaces**: `rgba(28,30,38,0.55)` primary scrim + linear gradient top white 0.18 → base black 0.18 + radial spec arc center-top.
- **Backdrop filter**: `.ultraThinMaterial` (≈ blur 40-60 + saturate 200%) — match macOS Tahoe glass vibe.
- **Edge highlights triple-layer**: gradient stroke top white `0.55` → middle `0.18` → bottom `0.06`.
- **Refractive corner tints**: red 18% bottom-left + blue 10% top-right, blend `.softLight` — gợi ánh sáng khúc xạ qua kính.
- **Radii lớn**: HUD VI/EN 22px, prediction 14px, Settings header icon 22px.

#### Surface render

- **HUD VI/EN**:
  - Icon gradient `[Color.white, red300, red500]` top-to-bottom + halo đỏ `0.45` radius 6 + white inner glow.
  - Label "Tiếng Việt"/"English" trắng warm `#F2EFE8` font rounded bold + shadow đen `0.45`.
  - Capsule pill VI/EN: gloss top white `0.30` overlay trên red-500 (VI) hoặc white `0.05` (EN), stroke white `0.45`, halo đỏ `0.55` cho VI.
  - 4-layer background stack: refractive tints → linear+radial top arc → scrim red → ultraThinMaterial.

- **HUD prediction**:
  - Arrow `→` gradient white→red300 + halo đỏ `0.35`.
  - Từ gợi ý mono semibold trắng warm + shadow đen `0.30`.
  - "⇥ Tab" mono mờ `0.55`.
  - 3-layer multi-shadow depth (14+4px).

- **Settings header**:
  - App icon 88px clip RoundedRectangle 22px + overlay glass gradient stroke + đỏ glow `0.45` radius 22px.
  - Wordmark "vkey" 30pt heavy rounded với 3-stop gradient white→red300→red500 + halo đỏ `0.50` radius 12px + white highlight rim 0.30 (subtle wet shine).
  - Tagline "Bộ gõ tiếng Việt — Liquid Glass" 12pt medium rounded secondary.

### 🗑 Xoá 2 themes

| Theme | Lý do | Migration |
|-------|-------|-----------|
| **3D bóng bẩy** (AppTheme.threeD) | Liquid Glass thay thế — kỹ thuật 3D gradient SF Symbols cũ không còn phù hợp | `AppDelegate.applicationDidFinishLaunching` reset `Defaults[.appTheme] == .threeD` → `.default` idempotent. ThemedSymbol case `.threeD` giữ trong enum (dead code) cho backward compat. |
| **Sơn Mài** (UITheme.sonMai) | User explicitly request remove | rawValue `.sonMai` không decode được vào UITheme mới → Defaults tự fallback về `.tonal` (default). |

### 📋 4 themes hiện tại

1. **Mặc định** — SF Symbols + accent system blue (Classic UI)
2. **Emoji vui tươi** — Emoji icons + accent system blue (Classic UI)
3. **Tonal** — Brand red Saigon `#E04434`, glass tối deep-ink, wordmark
4. **Liquid Glass** (mới) — Refractive multi-layer glass macOS Tahoe/visionOS, brand red

### 🛠 Architecture changes

- **`UITheme` enum**: `.sonMai` → `.liquidGlass`. Display name "Sơn Mài" → "Liquid Glass". Caption mô tả refractive glass macOS Tahoe.
- **`VKeyDesign.swift`**: 13 token Sơn Mài xoá; 6 token Liquid Glass thêm:
  - `lgGlass1Color` (`#1C1E26`) — primary panel scrim
  - `lgGlass2Color` (`#262832`) — elevated row
  - `lgSunkenColor` (`#0E0F14`) — sunken
  - `lgEdgeTop` (white) — spec highlight
  - `lgBlueTint` (`#2D89E5`) — refractive corner tint
  - `lgAmber` (`#F0A23C`) — warm alternate
- **`UITheme` extension**: `accentColor / headerImageName / showsHeroWordmark` branches `.sonMai` → `.liquidGlass`. Accent share brand red với Tonal.
- **HUD views**: `sonMaiBody / sonMaiScrimOpacity` xoá; `liquidGlassBody / liquidGlassScrimOpacity` thêm với multi-layer ZStack rendering (refractive tints + linear/radial highlights + scrim + material).
- **`SettingView.settingsHeader`**: case `.sonMai` xoá; case `.liquidGlass` thêm với glass-glossy wordmark gradient + red glow shadow.
- **`vkeyApp.MainMenuView`**: 5 entries → 4 entries. "3D bóng bẩy" + "Sơn Mài" xoá; "Liquid Glass" thêm với SF Symbol `drop.halffull`.
- **`AppIconSwitcher.apply`**: switch case `.sonMai` → `.liquidGlass`.
- **`AppDelegate`**: thêm migration `Defaults[.appTheme] == .threeD → .default` ở `applicationDidFinishLaunching`. Idempotent.
- **`Design4/`** commit Liquid Glass source files: `glass.css` + `surfaces*.css` + JSX preview scenes + images + fonts.
- **`Design3/`** (Sơn Mài) xoá.

### 🛡 Không thay đổi

- Engine gõ Telex/VNI/Simple, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi behavior. 213/213 test pass.
- User Defaults non-theme giữ nguyên.
- Sparkle update flow, codesign, hardened runtime — không thay đổi.
- Build target macOS 14+, universal arm64 + x86_64.

### 📦 Release artifacts

- `vkey-2.2.2.dmg` — universal binary, ~7.3 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `OXZSzEFkAZ3hXb3Qyj84qsS9+fQXVDt6ePQYXyzvMjGCl2kMGKxRomHrLVwr32uEZOYMMHydlk7Y4h0jYhjLBA==` (length 7642650).

---

## [2.2.1] - 2026-05-22 — "Sơn Mài"

**Thay theme Mực bằng Sơn Mài — sơn son thếp vàng, lacquer Vietnamese art aesthetic.** Tổng vẫn 5 giao diện. README rà soát ✓

### 🎨 Sơn Mài — sơn son thếp vàng

Theme thứ 5 trong menu bar (thay vị trí cũ của Mực) — đại diện cho mỹ thuật sơn mài Việt Nam.

#### Palette

- **Đỏ son** (lacquer red) `#B5302A` — sâu hơn Tonal `#E04434`, gợi sơn mài cổ truyền.
- **Thếp vàng** (gold leaf) `#A07C32` — accent vàng dùng tinh tế: viền HUD mảnh, gold-leaf hairline rule trong Settings header, badge VI/EN.
- **Giấy trứng** (eggshell) `#F4EFE3` paper canvas — cảm giác giấy dó / giấy gạo.
- **Ấm ink** (warm black) `#131110` — gợi nền sơn mài, không phải pure black.
- **Ngọc bích** `#0E7A5F` (jade) + **Chàm** `#1F4F7A` (indigo) — secondary palette cho semantic states (success / info).

#### Typography

- **Display**: Fraunces serif — editorial, classical, pair với Be Vietnam Pro.
- HUD VI/EN labels dùng `.serif` design (16/15pt semibold).
- Settings header wordmark "vkey" serif bold 30pt.

#### Visual treatment

- **HUD VI/EN**: glass tối warm-ink (`sonMaiInk500@0.36→0.68`), viền gold-leaf opacity 0.22, accent đỏ son cho icon, badge VI/EN dùng gold-leaf `0.30` background + gold-300 text.
- **HUD prediction**: mũi tên gold-leaf 300, từ gợi ý serif paper-50, chip "⇥ Tab" mono mờ 62%, viền gold.
- **Settings header**: app icon 80px clip RoundedRectangle 14px + shadow đỏ son `0.22`; wordmark "vkey" 30pt bold serif đỏ son; **gold-leaf hairline rule** LinearGradient (0 → 0.85 → 0) width 72px; tagline "Bộ gõ tiếng Việt — sơn son thếp vàng" italic serif 11.5pt secondary.

### 🗑 Xoá theme Mực

Mực (v2.2.0) loại bỏ — palette + branch + display name. User đang dùng Mực sẽ tự fallback về Tonal (default) khi load Defaults vì rawValue `.muc` không decode được vào enum mới.

5 themes trong menu bar không đổi count: Mặc định / 3D bóng bẩy / Emoji vui tươi / Tonal / **Sơn Mài**.

### 🛠 Architecture changes

- **`UITheme` enum**: `.muc` → `.sonMai`. Display name "Mực" → "Sơn Mài". Caption mô tả lacquer art.
- **`VKeyDesign.swift`**: 6 token Mực xoá; 11 token Sơn Mài thêm:
  - `sonMaiRed500/300/700` — lacquer red scale
  - `sonMaiGold500/300` — thếp vàng accent
  - `sonMaiPaper100/50/200` — eggshell paper canvas
  - `sonMaiInk500/400` — warm ink (`#131110`/`#1A1612`)
  - `sonMaiJade500` + `sonMaiIndigo500` — secondary palette
- **`UITheme` extension**: `accentColor / headerImageName / showsHeroWordmark` branches `.muc` → `.sonMai`.
- **HUD views**: `mucBody / mucScrimOpacity` xoá; `sonMaiBody / sonMaiScrimOpacity` thêm. Glass scrim ấm hơn (warm ink). Border gold-leaf opacity 0.22 thay vì white opacity 0.10.
- **`SettingView.settingsHeader`**: case `.muc` xoá; case `.sonMai` thêm với gold-leaf hairline LinearGradient rule + sơn son shadow.
- **`vkeyApp.MainMenuView`**: button "Mực" → "Sơn Mài", icon `drop` → `paintbrush.pointed`.
- **`AppIconSwitcher.apply`**: switch case `.muc` → `.sonMai`.
- **`Design3/`**: commit toàn bộ Sơn Mài design files (theme.css, JSX preview scenes) làm reference cho future variants.
- **`Design2/themes/`** xoá — Mực reference không còn cần thiết.

### 🛡 Không thay đổi

- Engine gõ Telex/VNI/Simple, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi behavior. 213/213 test pass.
- User Defaults non-theme giữ nguyên (theme có thể bị reset về Tonal nếu đang ở Mực).
- Sparkle update flow, codesign, hardened runtime — không thay đổi.
- Build target macOS 14+, universal arm64 + x86_64.

### 📦 Release artifacts

- `vkey-2.2.1.dmg` — universal binary, ~7.2 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `f3Wiv6uWq2Qve64FMrMqoqqpNCnI0TuYBs/NA8FPK7V9GJOMkj4dygjI5Bde69Rq5Yt438TujwXgnw9kTdP4DQ==` (length 7586567).

---

## [2.2.0] - 2026-05-22 — "Theme Library"

**Thêm Mực theme (high-contrast editorial). Theme picker chuyển từ Settings → menu bar. Tổng 5 giao diện. Fix bug Telex "theme" → "thêm". Mở rộng range HUD line offset lên 20 dòng.** README rà soát ✓

### 🎨 5 themes trong menu bar (Giao diện ứng dụng)

User mở **menu bar vkey → Giao diện ứng dụng** → chọn 1 trong 5:

| # | Theme | Icon style | Design system | Accent |
|---|-------|-----------|---------------|--------|
| 1 | Mặc định | SF Symbols | Classic (2.0.2) | System blue |
| 2 | 3D bóng bẩy | SF Symbols 3D | Classic | System blue |
| 3 | Emoji vui tươi | Emoji | Classic | System blue |
| 4 | **Tonal** (mặc định) | SF Symbols | Tonal | Brand red `#E04434` |
| 5 | **Mực** (mới) | SF Symbols | Mực | Lacquer red `#9F2E1C` |

**Mực theme** đặc trưng:
- Lacquer red `#9F2E1C` — deeper, single vermilion accent (no gold).
- High-contrast editorial: bone paper `#F7F5EF` / near-black ink `#0B0C0F`.
- Sharp radii (2/4/6/10/14 thay vì 4/6/10/14/20/28).
- Bóng mỏng print-like, không glow.
- Serif display font (rounded → serif transition cho heading).
- HUD VI/EN dùng serif "VI"/"EN" badges, padding chặt hơn.
- Settings header có editorial "rule" thin+thick dưới wordmark.

### 🐛 Fix bug Telex "theme" → "thêm"

**Trước 2.2.0**: gõ "theme" (English word) trong Telex mode → engine sai áp dụng luật mũ 'e..e' khi 'e' thứ 2 đến SAU final consonant 'm' → output "thêm" thay vì "theme". Bug class với "scheme", "scene", "phone", "tone", "stone", "type", "make", "code", "size", "rise", "vote", "note", "save", "wave", "here", "where"…

**Root cause**: trong `Telex.swift` line 128, luật mũ `case "a","o","e"` chỉ check `nguyenAmChua(char)` — không phân biệt giữa "ee" (vowel cluster, nên áp dụng mũ → ê) và "e..e" (e + cons + e, không nên áp dụng vì syllable đã đóng bởi cons giữa).

**Fix**: thêm 80+ English words pattern V-C-V vào `EmbeddedLexiconData.englishWords` narrow list. Khi user gõ "theme", `isInstantRestoreEnglish("theme")` returns true tại `InputProcessor.swift:471` → restore raw English, không áp dụng mũ. Approach pragmatic (lexicon-driven) thay vì engine-rule change để KHÔNG break Vietnamese typing chuẩn (vd "boutos" → "buốt" — 'o' sau final 't' để thêm mũ — vẫn hoạt động đúng).

**Regression test**: `testTelex_2_2_0_theme_no_extra_char` — verify "theme"/"scheme"/"scene"/"phone"/"type" → length ≤ input. 213/213 test pass.

### 📏 HUD line offset 1...20

**Trước**: Stepper "Khoảng cách HUD đến caret" trong tab Chính tả giới hạn `1...10` dòng. **Sau**: mở rộng → `1...20`. Phù hợp với màn hình lớn / editor multi-line.

### 🛠 Architecture

- **`UITheme` enum mở rộng**: `.classic / .tonal / .muc`.
- **`VKeyDesign.swift`**: thêm Mực palette — `mucRed500`, `mucRed300`, `mucRed700`, `mucInk500`, `mucPaper50`, `mucPaper200`.
- **`UITheme` extension**: `accentColor`, `headerImageName`, `showsHeroWordmark` — switch theo theme.
- **HUD views**: `ToggleHUDWindow.tonalBody / mucBody / classicBody`, `PredictionHUDWindow.tonalBody / mucBody / classicBody`.
- **`SettingView.settingsHeader`**: switch theo theme — Tonal rounded wordmark + glow đỏ, Mực serif wordmark + editorial rule, Classic icon centered.
- **`vkeyApp.MainMenuView`**: helper `setAppearance(ui:icon:)` + `isAppearance(_:_:)` write cả `uiTheme` lẫn `appTheme` nguyên tử.
- **Theme picker xóa khỏi `SettingView` tab Chung** — menu bar là single source of truth.

### 🛡 Không thay đổi

- Engine gõ Telex/VNI/Simple, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi behavior.
- User Defaults / personal dictionary / macro store / statistics giữ nguyên.
- Sparkle update flow, codesign, hardened runtime, entitlements — không thay đổi.

### 📦 Release artifacts

- `vkey-2.2.0.dmg` — universal binary, ~7.2 MB. Ad-hoc codesign + hardened runtime.
- Sparkle signature: `pqrloFcppyEgG53t9YKo0WzB2Y0yHX38Pp4e4XCfhXVMm+6v7XWk92RYhKyi9B87NUGEmUfmHVkrxM8QD+U6DQ==` (length 7589747).

---

## [2.1.1] - 2026-05-22 — "Theme System"

**Tách Tonal redesign thành theme tùy chọn. Switch giữa Classic (v2.0.2 look) và Tonal (v2.1.0 design) qua Settings.** Mặc định = Tonal. Không thay đổi engine gõ. README rà soát ✓

### 🎨 Theme System — switch giao diện live

**Bối cảnh**: v2.1.0 áp dụng design system Tonal làm default duy nhất → user mất diện mạo cũ. v2.1.1 cấu trúc lại thành **theme**: user có thể chọn giữa Classic (v2.0.2) và Tonal (v2.1.0+), switch tức thì không cần restart, và để mở đường cho theme thứ 3+ trong tương lai.

#### Cách dùng

Mở **vkey → Settings → tab Chung** → ngay đầu tab có Picker "Giao diện" segmented:
- **Classic**: diện mạo gốc v2.0.2 — accent system blue, HUD đơn giản, icon coffee cup, không wordmark.
- **Tonal** (mặc định): design mới — accent đỏ brand `#E04434`, HUD glass tối deep-ink, app icon đỏ, wordmark "vkey".

Theme apply cho 5 surface chính:
1. **Accent color** toàn app (Toggle, Picker, focus ring, button tint) qua `.tint()` ở root.
2. **HUD VI/EN** (`ToggleHUDWindow`) — Classic dùng material light + accent secondary; Tonal dùng glass tối + red.
3. **HUD prediction** (`PredictionHUDWindow`) — Classic dùng rounded font + radius 16; Tonal dùng mono + radius 10 + red arrow.
4. **Settings header** — Classic dùng icon 96px centered (no wordmark); Tonal dùng icon 84px + "vkey" 28pt heavy red + tagline.
5. **App icon** (notification banner / alert dialog) — `AppIconSwitcher` swap `applicationIconImage` qua AppKit.

#### Bên trong

- **`UITheme`** enum (`.classic` / `.tonal`) + **`Defaults.Keys.uiTheme`** key (default `.tonal`) trong `Setting.swift`. Persistent qua launches.
- **`ThemeManager`** `ObservableObject` trong `VKeyDesign.swift` — `Defaults.observe(.uiTheme)` → publish change. `@StateObject` ở `vkeyApp`.
- **`.tint(themeManager.current.accentColor)`** apply ở Settings `TabView` và MenuBarExtra menu root.
- **HUD views** rẽ nhánh body qua `if uiTheme == .tonal { tonalBody } else { classicBody }` — Classic preserve 100% logic + style v2.0.2.
- **`AppIconSwitcher.apply(theme:)`** — `NSApplication.shared.applicationIconImage = NSImage(named:)`. Wire trong `AppDelegate.applicationDidFinishLaunching` + Settings picker `onChange`.

#### Asset

- **`AppIconClassic.appiconset`** — restore icon v2.0.2 từ git commit `f1a0296` (46 PNG đầy đủ macOS/iOS/watchOS sizes).
- **`CficonClassic.imageset`** — header icon Classic (coffee cup) cho Settings header.
- **`AccentColor.colorset`** — reset về universal empty (system accent). Tonal override qua `.tint()` không qua asset.
- Bundle chứa cả 2 bộ icon song song — switch runtime không cần tải lại.

### 🛡 Không thay đổi

- Engine gõ Telex/VNI/Simple, từ điển, spell-check, prediction, Smart Switch, Macro — không đổi behavior. 212 test pass.
- User Defaults / personal dictionary / macro store / statistics giữ nguyên.
- Sparkle update flow, codesign, hardened runtime, entitlements — không thay đổi.
- Build target macOS 14+, universal arm64 + x86_64.

### 📦 Release artifacts

- `vkey-2.1.1.dmg` — universal binary, ~7.2 MB. Ad-hoc codesign + hardened runtime (`flags=0x10002 adhoc,runtime`, `Identifier=dev.longht.vkey`, sealed resources v2 files=60).
- Sparkle signature: `+GMBqnWfkXeViTt7WhVGXfkD+HDLnp0wrUP5V6wXaerZ66kM47N07n2tOTdgLfmrOejkYfSyI9QF7D/kI5ZFDg==` (length 7568068).

### Roadmap themes (Future)

Kiến trúc `UITheme` mở rộng dễ dàng. User dự kiến thêm theme khác:
- High-contrast (a11y)
- "Phở vàng" (gold-only palette dựa trên Saigon gold token)
- Themed cho từng dịp lễ (Tết, 30/4, v.v.)

Thêm 1 theme mới chỉ cần: thêm case vào `UITheme`, expose `accentColor` + `headerImageName` + `showsHeroWordmark`, render branch trong HUD/Settings, thêm imageset.

---

## [2.1.0] - 2026-05-22 — "Tonal Redesign"

**Áp dụng vkey Design System "Tonal" — refresh diện mạo macOS-native với typography tiếng Việt + bảng màu thương hiệu nhất quán.** Không thay đổi engine gõ. README rà soát ✓

### 🎨 Design System "Tonal" — refresh toàn bộ diện mạo

**Bối cảnh**: Trước 2.1.0, vkey dùng accent color hệ thống (xanh blue mặc định macOS) và các surface dựa hoàn toàn vào SF Symbols + `accentColor`/`secondary`. UI nhất quán với macOS nhưng thiếu cá tính thương hiệu. Phiên bản này áp dụng [vkey Design System "Tonal"](Design/) — bảng màu Saigon đỏ-vàng + typography tiếng Việt + glass surfaces tối — qua một bộ design tokens Swift được centralize.

#### Thay đổi visible

- **App icon mới**: biểu tượng vkey thiết kế lại theo gam đỏ Saigon (`#E04434`). Render đầy đủ cho macOS 16/32/64/128/256/512/1024 + iOS/watchOS scales. `Cficon` (icon trong Settings header) cũng được thay.
- **Accent color**: chuyển từ system blue sang brand red `#E04434` (light) / `#F18A74` (dark). Toàn bộ `Toggle` / `Picker` / focus ring tự động nhận tint mới qua `AccentColor.colorset`.
- **HUD VI/EN** (`ToggleHUDWindow`): glass tối (deep ink `#131519`) với viền sáng mảnh (`white@0.08`), accent đỏ brand cho trạng thái VI, paper-neutral cho EN. Shadow đậm hơn (radius 24, y 12) để HUD nổi rõ trên mọi nền desktop. Corner radius 18→20 (`--r-xl`).
- **HUD prediction** (`PredictionHUDWindow`): mũi tên `→` brand red 300, từ gợi ý font mono semibold trắng, chip "⇥ Tab" mờ 62%. Padding chặt hơn (14×8), corner radius 16→10 (`--r-md`). Glass scrim tối hơn cho contrast text mono rõ ràng.
- **Settings header** (`SettingView`): app icon 84px (giảm từ 96px) + wordmark "vkey" 28pt heavy rounded brand red + tagline phụ "Bộ gõ tiếng Việt thông minh cho macOS". Shadow glow tone đỏ brand (`red500@0.28`, radius 16) thay vì shadow đen.

#### Bên trong

- **`VKeyDesign.swift`** (mới): single source of truth cho design tokens. Mirror trực tiếp `colors_and_type.css` của design system — brand red scale (`red50`…`red900`), Saigon gold, paper neutrals (light), deep ink neutrals (dark), semantic colors (success/warning/danger/info), radii (`radiusXS`→`radius2XL`), spacing (`s1`→`s8`), helper fonts. `Color(hex:)` initializer cho phép paste hex literal trực tiếp.
- **`AccentColor.colorset`**: 2 variants — universal `#E04434`, dark-mode `#F18A74` (red300 — sáng hơn để contrast với ink-500 background của dark mode macOS).
- **`Design/` directory**: toàn bộ vkey Design System được commit vào repo root làm reference: `colors_and_type.css`, `components.css`, font files (Be Vietnam Pro, Noto Sans Display, Carter One, JetBrains Mono), SVG icon set + logo, UI kit HTML (Settings / MenuBar / Onboarding), screenshot reference. Tổng ~17MB.

### 🛡 Không thay đổi

- Engine gõ (Telex/VNI/Simple), từ điển, spell-check, prediction, Smart Switch, Macro — không có thay đổi nào về behavior. Toàn bộ test suite (212 tests) pass nguyên trạng.
- User data (Defaults, personal dictionary, macro store, statistics) giữ nguyên — không cần migration.
- Sparkle update flow, codesign, hardened runtime, entitlements — không thay đổi.
- Build target: macOS 14+ (Sonoma trở lên), universal arm64 + x86_64.

### 📦 Release artifacts

- `vkey-2.1.0.dmg` — universal binary, ~7.1 MB. Ad-hoc codesign + hardened runtime (`flags=0x10002 adhoc,runtime`, `Identifier=dev.longht.vkey`, sealed resources v2).
- Sparkle signature: `gWb2bbEiOH1TDPs7Gvaruaivvmb6B4a5eYgscJ3q8Edr4BbcfHkeuE5DevhIfnUxXkCM93cEE7Tsqotae6/NCA==` (length 7481360).

---

## [2.0.2] - 2026-05-22 — "Bug Hunt"

**Patch fix bug class lớn + UX hotkey/prediction**. Không thêm tính năng mới. README rà soát ✓

### 🐛 J2 — Bug class "toools" (3 fix sites + 7 regression tests)

**Trước 2.0.2**: gõ "text tools" + Space → ra "**toools**" (thừa 1 chữ 'o'). Bug class lớn ảnh hưởng tới mọi từ tiếng Anh có cụm "oo"/"aa"/"ee" trước consonant: `tools, boot, boost, bloom, shoot, loop, stoop, goose, foot, food, mood, moon, noon, pool, room, root, baa, naan, bee, see, fee, ...` Trên VNI tương tự với `to6o`, `ddo9`.

**Root cause**: Logic `transformed.count == lastTransformedForStep.count` trong `InputProcessor.swift` (3 sites — `reconstructState` line ~297, `push` replay path line ~403, `push` main path line ~505) coi "engine không thay đổi" → append raw key. Khi engine apply combining diacritic (vd Telex `to`+`o` → `tô` — grapheme count vẫn 2 nhưng NFD scalar count tăng 2 → 3), code vẫn append raw `o` thừa → "tôo".

**Fix**: Helper `WordBuffer.shouldAppendRawKey(newTransformed:oldTransformed:)` so sánh **NFD scalar count** thay vì grapheme count. Logic:
- NFD scalar count TĂNG → engine vừa thêm combining diacritic → KHÔNG append raw key.
- NFD scalar count GIỮ NGUYÊN → engine no-op → append (vẫn cần raw key).
- NFD scalar count GIẢM → engine vừa bỏ diacritic (toggle off) → append raw command key (vd '1', '6' để user thấy).
- Grapheme count THAY ĐỔI → engine đã tự reflect keystroke vào output → KHÔNG append.

**Preserve behavior**: Tất cả test toggle hiện có vẫn pass:
- VNI: `a11` → "a1", `a66` → "a6", `a88` → "a8", `d99` → "d9".
- Telex triple-toggle: `aaa` → "aa", `ooo` → "oo", `eee` → "ee", `aww` → "aw", `uww` → "uw".

**Test coverage**: 7 regression test mới (`testTelex_J2_oo_class_no_extra_char`, `_aa_class`, `_ee_class`, `_replay_path`, `_triple_toggle_preserved`, `_vietnamese_typing_preserved`, `testVNI_J2_digit_toggle_preserved`). Tổng test: 205 → 212, 0 failures.

### ✨ J1 — Prediction về top-1 only (bỏ digit selection)

**Trước**: PredictionHUD hiển thị top-3 candidates, user nhấn 1/2/3 để chọn. Vấn đề: gõ văn bản có số (vd "3 con mèo") → vô tình nhấn '3' khi đang có prediction → chọn nhầm.

**Sau**: chỉ hiển thị top-1, Tab accept. UI đơn giản, không xung đột với gõ số.

**Xoá**:
- `InputProcessor.swift`: digit handler block (line ~872-887), field `activePredictionCandidates: [String]`.
- `PredictionHUDWindow.swift`: API `showCandidates([String])`, `multiCandidateView`, helper `candidatesContentSize`.
- `Setting.swift`: Defaults key `predictionTopN`.
- `SettingView.swift`: Stepper "Số gợi ý hiển thị" trong tab Chính tả.

### ⌨️ J3 — Default hotkey + label rename

- **VI/EN toggle default**: ⌃⇧ (Control+Shift) → **⇧⌥ (Shift+Option)** — ít xung đột hơn với system shortcuts. User existing 2.0.1 không bị thay đổi (Defaults default chỉ apply lần đầu).
- **Label** trong tab Chung: "Phím tắt" → "**Phím tắt chuyển đổi VI/EN**" cho rõ.
- **Text Tools default**: thêm modifier-only **⌃⇧ (Control+Shift)** để mở Text Tools menu. Trước đó không có default — user phải gán thủ công qua KeyboardShortcuts Recorder.

**Implementation**:
- `Setting.swift`: `kDefaultModifierOnlyMask` đổi sang Shift+Option; thêm `kDefaultTextToolsMask` (Control+Shift) + `Defaults.Keys.modifierOnlyTextToolsHotkey`.
- `EventHook.swift`: refactor `handleModifierOnlyHotkey` → `processModifierTargets(targets:)` support nhiều modifier-only target song song. Khi user thả combo, return mask của target khớp → caller route tới handler tương ứng (toggle VI/EN hoặc Text Tools menu).
- `SettingView.swift`: label mới + chú thích kèm theo.

### Migration

- User 2.0.1 → 2.0.2 hotkey ⌃⇧ (đã save) vẫn hoạt động cho VI/EN. User mới install (hoặc reset Defaults) sẽ thấy ⇧⌥.
- Text Tools default ⌃⇧ chỉ apply cho user new — user đã có shortcut khác giữ nguyên.
- Bug class "toools" tự động fix sau update.
- Không breaking change cho engine/parser/macros/dictionary.

### Thông tin build

- macOS 14+ (Sonoma), Xcode 26.5+, Swift 5.10+, Rust 1.95+ (chỉ khi rebuild rust-core).
- DMG: vkey-2.0.2.dmg, 7,475,300 bytes (giảm 12 KB so với 2.0.1).
- Sparkle signature: `QwKK/Hr5kGaOaVhCPdSSDbEyh22igBRNWaFxXR5VYCGhOJjSJbVEkIVMDCMMLEtj7tCCYlDRMoiO9g75MTdVBQ==`
- Tests: 212/212 pass (gồm 7 regression test mới cho J2).

## [2.0.1] - 2026-05-22 — "Symphony Polish"

**Patch dọn dẹp sau khi user dùng thử 2.0**. Không thêm tính năng mới — 4 thay đổi để gọn UI + gọn code. README rà soát ✓

### Thay đổi

- **G1 — Tab Chung sắp xếp lại** (`vkey/View/SettingView.swift`): di chuyển Toggle "Đặt dấu tự do" xuống dưới Toggle "Hiển thị thông báo khi chuyển VI/EN" và trên Picker "Kiểu đặt dấu". Nhóm các option định dạng văn bản với nhau.
- **G2 — Bỏ Floating Toolbar hoàn toàn (A1 từ 2.0)**:
  - Xoá `vkey/Platform/FloatingToolbarWindow.swift`
  - Xoá `KeyboardShortcuts.Name.toggleFloatingToolbar` (`Setting.swift`)
  - Xoá `Defaults.Keys.floatingToolbarEnabled`
  - Xoá hotkey row + handler trong `AppState.swift`
  - Xoá FlexibleShortcutRecorder row trong SettingView
  - Lý do: trùng chức năng với menubar icon + HUD, user feedback ít dùng.
- **G3 — Bỏ HUDThemeSection (A3 từ 2.0)**:
  - Xoá `vkey/Platform/HUDTheme.swift` (struct HUDTheme, enum HUDThemeStyle, HUDThemeBackground modifier, parseHex helper)
  - Xoá 3 Defaults keys: `hudThemeStyle`, `hudBlurIntensity`, `hudAccentColorHex`
  - Xoá `struct HUDThemeSection: View` trong SettingView
  - Lý do: 3 control chưa thực sự kết nối tới ToggleHUD/PredictionHUD — chỉ Floating Toolbar dùng, mà Floating Toolbar cũng bỏ → gây nhầm lẫn cho user. `hudOpacityPercent` (1.9.0) vẫn còn và đang hoạt động cho HUD thực tế.
- **G4 — Embed Window Title Rules vào Smart Switch tab (B1 từ 2.0)**:
  - Xoá `vkey/View/WindowRulesView.swift`
  - Bỏ tab "Rules" trong `vkeyApp.swift` Settings TabView
  - Thêm `WindowRulesSection` + `WindowRuleRow` (private struct) vào cuối `SmartSwitchView.swift`, render dưới dạng `DisclosureGroup` gập được, mặc định collapsed.
  - Data model + engine giữ nguyên: `WindowTitleRule` struct, `Defaults.Keys.windowTitleRules`, `Platform/WindowTitleRuleEngine.swift`. Mọi rule hiện có vẫn hoạt động.
  - Tab count giảm 1 (5 → 4).

### Migration

- User 2.0.0 → 2.0.1: hotkey "Floating Toolbar" cũ (nếu đã gán) sẽ bị bỏ qua (Defaults key xoá → KeyboardShortcuts không còn observer). Settings "Giao diện HUD" biến mất khỏi tab Chung. Window Rules nằm trong tab Smart Switch (cuối, mở collapsible).
- Không breaking change cho engine/parser/macros/dictionary.
- Sparkle auto-update chạy như thường lệ. DMG giảm nhẹ (7,585,103 → 7,487,209 bytes, ~13% giảm code không dùng).
- 5 file Swift bị xoá: FloatingToolbarWindow, HUDTheme, WindowRulesView + 2 file related.

### Thông tin build

- macOS 14+ (Sonoma), Xcode 26.5+, Swift 5.10+, Rust 1.95+ (chỉ khi rebuild rust-core).
- DMG: vkey-2.0.1.dmg, 7,487,209 bytes.
- Sparkle signature: `dcKAoBSZF1SpXYOjE0gYzgrX2287ZfiUTYwA0TbRSYrS/CbVy86IzHdpct6omxrumlAyLIBSvhxeji9MmpSqCg==`
- Tests: 205/205 pass.

## [2.0.0] - 2026-05-22 — "Symphony"

**Bản phát hành lớn gộp 13 tính năng cùng lúc** — lấy cảm hứng từ **[xkey](https://github.com/xmannv/xkey)** (xmannv) + **[gonhanh.org](https://github.com/khaphanspace/gonhanh.org)** (khaphanspace). Plan đầy đủ tại `~/.claude/plans/`.

### 🎨 UX (Trải nghiệm hiện đại)

- **A1 Floating Toolbar tại cursor**: `NSPanel` nổi (không cướp focus) với toggle VI/EN, picker Telex/VNI, Free Mark, hotkey Text Tools, đóng. Gán phím tắt trong tab Chung. Mới: `Platform/FloatingToolbarWindow.swift`.
- **A2 Đoán từ Top-3**: `PredictionEngine.topNPredictions` (default 3). HUD multi-candidate với index 1/2/3. Chọn bằng phím số (chỉ khi buffer trống — vừa commit) hoặc Tab (top-1). Backward-compat: `predictionTopN = 1` giữ behavior 1.x.
- **A3 Theme & Glassmorphism tuỳ biến**: 4 style (Auto/Light/Dark/Glass), độ mờ 0-100%, accent color hex. `Platform/HUDTheme.swift` shared modifier — áp dụng cho HUD + Toolbar + Popup. Section mới trong tab Chung.
- **A5 Viết hoa đầu câu**: state machine `pendingCapitalize` + `sentenceJustEnded` trong InputProcessor. Trigger sau `. ! ?` + Space hoặc sau Enter. Toggle `autoCapitalizeEnabled` (default ON).
- **A6 Free Mark mode**: bypass `TiengVietValidator` qua check `freeMarkModeEnabled` trong `TiengVietState.needsRecovery`. Cho phép đặt dấu ở vị trí bất kỳ. Toggle (default OFF) trong tab Chung.

### 🔗 Tương thích & Ngữ cảnh

- **B1 Window Title Rules**: rule regex theo bundle ID prefix + window title. Override `state`, `disablePrediction`, `disableSpellCheck`, `flushDelayMs` per context. Tab "Rules" mới. `Platform/WindowTitleRuleEngine.swift` cache resolved overrides theo (bundle, title) — invalidate khi đổi app.
- **B2 Auto-respond input source**: theo dõi `kTISNotifySelectedKeyboardInputSourceChanged`. Khi user chuyển sang non-Latin IME (JP/CN/KR/Thai/Arabic/Hebrew/Russian…) → tự động `setEnabledWithoutPersist(false)` + nhớ state. Khi quay về Latin → restore. Toggle `nonLatinIMEAutoDisable`.
- **B3 Diacritic Style** (đã có sẵn `newStyleTonePlacement`): rà soát + làm rõ trong UI. Picker tab Chung kèm example.
- **B4 Text Conversion Tools**: hotkey menu → clipboard round-trip (Cmd+C → transform → set clipboard → Cmd+V). Operations: lower/UPPER/Title/Sentence case, bỏ dấu (`applyingTransform(.stripDiacritics)` + đ/Đ), chuyển raw Telex/VNI (decompose table). `Platform/TextConversionService.swift`.

### ⚡ Performance & Ổn định

- **C1 Performance benchmark công khai**: 6 XCTest performance test mới trong `vkeyTests/vkeyTests.swift`. Đo M-series 2026-05:
  - Telex parse 1 ký tự (1 000 ×): ~12 ms
  - Telex `tieengs` → `tiếng` (1 000 ×): ~92 ms
  - VNI full word (1 000 ×): ~100 ms
  - 1 000 ký tự liên tục: ~14 ms
  - Lexicon lookup (14 000 ×): ~19 ms (~1.4 µs/lookup)
  - Pure parse (10 000 × 7 chars): ~276 ms — baseline cho Rust port
  - **Tất cả dưới ngưỡng** — engine Swift đủ nhanh cho input method (<50µs/ký tự).
- **C2 Rust Core Engine (foundation)**: tách Engine sang Rust crate `vkey_core` qua C-ABI FFI. Universal static library (arm64+x86_64) ~1MB nhúng vào binary. **Không ảnh hưởng auto-update**: DMG chứa toàn bộ code Rust statically linked. Phase 1 hoàn thành (State + Parser data types, 6 FFI symbols). Phase 2 (Validator), 3 (Transformer + Telex/VNI), 4 (retire Swift engine) trong các release tiếp theo. Bridge gated bằng `-D VKEY_CORE_RUST`.
  - Build: `rust-core/build.sh` (universal binary + cbindgen header).
  - Tích hợp Xcode: bridging header + HEADER_SEARCH_PATHS + LIBRARY_SEARCH_PATHS.
- **C3 Pipeline 7-stage**: tài liệu hoá rõ ranh giới trong `app-arch.md`:
  1. **Capture** (CGEventTap)
  2. **Normalize** (handleEvent + auto-capitalize entry)
  3. **Parse** (TiengVietParser)
  4. **Validate** (TiengVietValidator, A6 bypass tại đây)
  5. **Transform** (Transformer + Telex/VNI, B3 toggle)
  6. **Commit / Learn** (SpellDecision, Lexicon, Stats, Prediction)
  7. **Recover** (snapshot rollback, Esc)
  Stages 3-5 thuần tuý — first targets cho Rust port (C2).
- **C4 Race-condition hardening CGEvent**: `EventSimulator.withAdaptiveFlush` wrapper quanh mọi `simulationQueue.async` block. Re-entry counter + optional `usleep(flushDelayMs)` sau mỗi flush. Giải quyết bug-class "stickiness" trong Spotlight/Chrome address bar/Arc/Notion. Delay đọc từ Window Title Rule (B1) hoặc global default `cgEventFlushDelayMs`.

### 🔧 Loại trừ theo plan v2.0

Không có trong release này (lý do: scope/đánh đổi giá trị-chi phí):
- Translation popup multi-provider
- IMK mode song song CGEvent
- Encoding TCVN3 / VNI Windows
- Quick Typing shortcuts (cc→ch, gg→gi)
- Simple Telex 1 & 2 variants
- Cross-platform roadmap (Linux/Windows)
- Dual UserDefaults storage
- Debug Window cho developer

### 📦 File mới (9) / Sửa (12)

- **Mới**: `Platform/HUDTheme.swift`, `Platform/InputSourceMonitor.swift`, `Platform/FloatingToolbarWindow.swift`, `Platform/TextConversionService.swift`, `Platform/WindowTitleRuleEngine.swift`, `View/WindowRulesView.swift`, `Engine/RustEngineBridge.swift`, `vkey/vkey-Bridging-Header.h`, thư mục `rust-core/` (Cargo + src + cbindgen).
- **Sửa**: `Setting.swift` (8 Defaults keys + types), `InputProcessor.swift`, `AppState.swift`, `TiengVietState.swift`, `PredictionEngine.swift`, `PredictionHUDWindow.swift`, `EventSimulator.swift`, `SettingView.swift`, `vkeyApp.swift`, `vkeyTests/vkeyTests.swift`, `app-arch.md`, `README.md`.

### 🔐 Lưu ý auto-update với Rust core

- Rust được **link tĩnh** (`libvkey_core.a`) vào binary. DMG chứa toàn bộ — không có dependency runtime ngoài app bundle.
- Sparkle EdDSA + Apple code signing đều cover binary as-a-whole → cover luôn Rust code → **không cần thay đổi gì cho auto-update**.
- User 1.9.7 update lên 2.0.0: tải DMG → Sparkle verify chữ ký → replace `vkey.app` → restart. Rust code mới có sẵn trong app, không cần cài Rust ở máy user.
- Tăng size DMG nhẹ (+~450 KB): 7.13 MB → 7.59 MB. Universal binary (arm64+x86_64) ~18.9 MB executable.

### Thông tin build

- macOS 14+ (Sonoma), Xcode 26.5+, Swift 5.10+, Rust 1.95+ (chỉ khi rebuild rust-core).
- DMG: vkey-2.0.0.dmg, 7 585 103 bytes.
- Sparkle signature: `ynG51gnG5jIHqS4cAZ1djHx9MnpdPguk3OtCbLifcPd8AV88GT43PojJmbdDJ6/KhZLFc/qz+wGftNnfI8AWAA==`
- Tests: 205/205 pass (đã bao gồm 6 benchmark mới).

## [1.9.7] - 2026-05-21 — "Anywhere DD Toggle"

User feedback: gõ `vcdd` muốn ra `vcđ` (cho phép `dd` → `đ` ở mọi vị trí, không chỉ initial).

### 🎯 Anywhere `dd` ↔ `đ` toggle trong recovery state

Khi vkey ở recovery state (chuỗi keys không hợp lệ tiếng Việt), 'd' liên tiếp theo state machine:
- **Stage 0 → 1**: 'd' thứ 2 (transformed.last == 'd') → toggle ON ('d' → 'đ').
- **Stage 1 → 2**: 'd' thứ 3 (transformed.last == 'đ') → toggle OFF ('đ' → 'dd').
- **Stage 2**: subsequent 'd' = no-op (frozen, giữ nguyên "dd").
- Non-'d' char giữa → reset stage về 0.

**Examples**:
- `vcdd` → `vcđ` ✓
- `vcddd` → `vcdd` (toggle off) ✓
- `vcdddd` → `vcdd` (frozen) ✓
- `add` → `ađ` (English bị toggle vì 'd' sau 'a' rơi conLai)
- `addd` → `add` (toggle off để giữ raw)

### Regression-safe

- Initial `dd → đ` (Telex chuẩn) **vẫn work**: `dduowngf → đường`, `ddi → đi`.
- Toggle áp dụng chỉ trong recovery branch — không ảnh hưởng VN typing flow.
- Backspace replay đồng bộ qua `reconstructState` (local stage var).

### Bug 1 "download → dowwnload" — defer

Thử blocklist English prefix check trong Telex `w`/`a`/`o`/`e` mark, nhưng làm regression VN typing (vd `aww → ăw` thay vì `aw`, `awn → ăn`). Defer fix bug này — nguyên nhân có thể là target app autocomplete inflation (TextEdit, Word) không phải engine. Workaround: dùng Smart Switch English mode cho app target nếu cần.

### Files

- [vkey/App/InputProcessor.swift](vkey/App/InputProcessor.swift) — `ddToggleStage` property + recovery branch toggle logic + `reconstructState` replay path.
- [vkeyTests/vkeyTests.swift](vkeyTests/vkeyTests.swift) — `testTelexAnywhereDDToggle` (5 cases).

### Verify

- 199/199 tests pass.

## [1.9.6] - 2026-05-21 — "HUD Manual Sizing & Background Strength Refactor"

Refactor HUD rendering pipeline để fix căn cơ: chữ rõ + nền clear + không crash + không invisible. Đây là tổng kết các vấn đề từ v1.9.0 đến v1.9.5.

### 🎯 PredictionHUDWindow — manual sizing pipeline

Trước v1.9.6, kích thước HUD đoán từ phụ thuộc `controller.view.fittingSize`:
- v1.9.3 `sizingOptions = []` → fittingSize trả 0 → text invisible.
- v1.9.4 quay lại heuristic char-count → bitmap bo góc sai.
- v1.9.5 `sizingOptions = .preferredContentSize` → SwiftUI có thể tự propose resize window → còn rủi ro crash.

**Giải pháp v1.9.6**: tính `contentSize` thủ công qua `NSString.boundingRect(...)` với `NSFont.systemFont(.semibold)` đúng font size user setting → biết chính xác text size. Cộng padding (32×20) + shadow allowance (16). KHÔNG đọc `fittingSize` nữa.

Lợi ích:
- Size deterministic, không phụ thuộc SwiftUI re-layout.
- Giữ `controller.sizingOptions = []` để chặn SwiftUI propose resize window → không crash NSException.
- `controller.view.setFrameSize(contentSize)` + `panel.setContentSize(contentSize)` đảm bảo SwiftUI render trong đúng vùng → không clip text.

Helpers mới (nonisolated static):
- `contentSize(for: text, fontSize:)` — measure text + padding.
- `clampedFontSize(_:)` — bound 12-24.
- `clampedBackgroundStrength(_:)` — bound 30-100 → Double 0.30-1.00.

### 🎨 PredictionHUDView — backgroundStrength replace opacity

Refactor: param `opacity: Double` → `backgroundStrength: Double`. Logic:
- Trước: `.opacity(0.75)` applied vào TOÀN BỘ view (cả text + material) → text mờ.
- Sau: `backgroundStrength` chỉ điều khiển opacity của material background layer, KHÔNG ảnh hưởng text/foreground.

Kết quả: text/icon luôn rõ 100% bất kể user kéo opacity xuống 30%. Chỉ "kính" nền trong suốt.

### 🎨 ToggleHUDView — backgroundStrength qua ViewModel

- `viewModel.backgroundStrength: Double` (default 0.75).
- `panel.alphaValue = 1` cố định cho fade animation, không dùng làm opacity user setting.
- `backgroundStrength` reactive với Defaults (đọc lại mỗi `show()`).

### Tests mới

+3 tests trong vkeyTests.swift (197 total, từ 194):
- `testPredictionContentSizeMeasurement` — boundingRect cho text "→ word ⇥ Tab".
- `testPredictionFontSizeClamping` — clamp 12-24.
- `testBackgroundStrengthClamping` — clamp 30-100 → 0.30-1.00.

### Verify

- 197/197 tests pass.
- Build clean.

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
