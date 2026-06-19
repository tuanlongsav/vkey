<h1>
  <img src="images/vkey-icon.png" alt="vkey logo" width="56" style="vertical-align: middle;">
  &nbsp;vkey
</h1>

Bộ gõ tiếng Việt cá nhân, đơn giản, cho macOS. Viết bằng Swift native, chạy như một app menu bar nhỏ gọn, hỗ trợ macOS 14 Sonoma trở lên.

**Phiên bản hiện tại: 3.16 — "Lịch sử clipboard tùy chỉnh"** ([CHANGELOG](CHANGELOG.md))

> **3.16** — 📋 **Lịch sử clipboard tùy chỉnh (tắt mặc định).** ⌘C lưu vào danh sách RAM; ⌥⌘V mở menu chọn mục để dán; ⌘V và ⇧⌘V dán bình thường như macOS. Cài đặt số mục (3–50) và chế độ chỉ văn bản / văn bản + tệp. 253 test pass.
>
> **3.15** — 💡 **HUD đoán từ căn giữa phía trên ô nhập** — hết lỗi pill `→ … · Tab` nhảy góc trên-phải màn hình khi app không trả caret (Electron/Claude); setting khoảng cách 1–20 dòng hoạt động cả khi fallback AX. 🧠 **Đoán từ theo cụm tiếng Việt có nghĩa** — thống kê chỉ ghi cụm hợp lệ; prediction thêm layer cụm nhúng sẵn + học từ phrase stats (vd `kính gửi` → `anh`). 249 test pass.
>
> **3.14** — 💡 **HUD gợi ý từ không che vùng gõ.** Hết lỗi pill `→ … · Tab` chèn đè lên dòng đang gõ khi ô chat ở đáy màn hình (Claude desktop, Electron) — bỏ placement dưới caret, ưu tiên phía trên/bên phải, không dùng bounds cả ô text làm vị trí caret. 🔧 **Text Tools** chờ clipboard async (không block UI). 📋 Pasteboard đổi từ app khác không còn xoá từ đang gõ giữa chừng. 247 test pass.
>
> **3.13** — 🐛 **Ổn định gõ ở thanh địa chỉ Chrome và Window Title Rule.** Sync focus trước mỗi keystroke (hết race sau Cmd+L / click omnibox); `axDirect` áp cho mọi đường transform (Backspace, Escape, spell, macro, prediction); Window Title Rule không còn toggle VI/EN liên tục khi click/tab trong app. AX leo cây tốt hơn cho hộp Save. 244 test pass.
>
> **3.12** — 🐛 **Fix triệt để `Source`→`Suorce` + HUD cân giữa.** Bổ sung cho 3.11: prefix `sou`/`Sou` không còn bị swap thành `Suo` giữa chừng (nguyên nhân `Suorce` trên màn hình thật dù test từ đủ ký tự đã pass); thêm guard prefix từ tiếng Anh + instant-restore `source`/`you`/`count`… HUD VI/EN đo kích thước thủ công (`max` cả hai nhãn) thay vì `fittingSize` bất đồng bộ — toggle luôn căn giữa. Path VN `bou→buo` vẫn đầy đủ. 244 test pass.
>
> **3.11** — 🐛 **Gõ chuẩn từ tiếng Anh + HUD cân giữa.** Hết lỗi từ tiếng Anh có `ou`/`ei` bị tự "sửa lỗi gõ nhầm" ở chế độ tiếng Việt (`source` → `suorce`, `count` → `cuont`, `their` → `thier`…) — trước đây phải chuyển sang tiếng Anh mới gõ được. Nay luật hoán đổi nguyên âm chỉ áp khi tạo ra âm tiết tiếng Việt hợp lệ (không còn ký tự rác); các đường gõ nhầm tiếng Việt (`bou→buo`, `veit→viet`, `haoi→hoai`) vẫn đầy đủ. Đồng thời HUD VI/EN không còn lệch phải khi đổi trạng thái — luôn cân giữa màn hình. Toàn bộ 244 test pass.
>
> **3.10** — 🛡️ **Đợt củng cố độ ổn định.** Sửa race condition ở Thống kê n-gram & từ điển Anh–Việt; áp dụng đầy đủ Window Title Rule (tái đánh giá khi đổi focus/tiêu đề, Smart Switch không ghi đè); backup/restore giữ thêm nhiều setting mới (phím tắt Text Tools, HUD prediction, theme, Window Title Rules, auto-capitalize, non-Latin IME, Free Mark Mode, CGEvent); Text Tools khôi phục clipboard cũ sau khi paste và không đè nếu bạn vừa copy thứ khác; sửa accept prediction bằng Tab. Toàn bộ test pass.
>
> **3.9** — 🐛 **Sửa triệt để lỗi gõ ở thanh địa chỉ Chrome.** Thủ phạm là tính năng **tự gợi ý (autocomplete) bôi đen text** của thanh địa chỉ — backspace xoá nhầm phần bôi đen nên lệch ký tự (NFC → thừa chữ `"truường"`, NFD → thiếu chữ `"truờng"`). Không phải bài toán NFC/NFD. Nay vkey định tuyến thanh địa chỉ qua chế độ **ghi thẳng Accessibility (axDirect)** — đọc nội dung thật rồi ghi đúng kết quả, bỏ qua cả autocomplete (cùng cơ chế đã ổn cho Spotlight). Web page, app native, hộp thoại lưu file vẫn nguyên. Toàn bộ test pass.
>
> **3.8** — 🐛 **Fix `"trường"` → `"truường"`** (thừa chữ) khi gõ ở **thanh địa chỉ Chrome** và các ô do Chromium tự vẽ. Cơ chế ép NFC của 3.6/3.7 nhận diện field native quá rộng (omnibox cũng nằm ngoài `AXWebArea` nhưng là field Chromium Views, lưu/xoá theo scalar). 3.8 siết về đúng **hộp thoại modal native** (`AXSheet`/dialog) → omnibox quay lại diff NFD chuẩn, hộp thoại lưu file vẫn được fix như 3.6. Toàn bộ test pass.
>
> **3.7** — 🔧 **Củng cố bản 3.6 sau code-review.** Siết phần phát hiện ô nhập native theo Accessibility để **không đoán mò**: khi cây Accessibility quá sâu hoặc phản hồi chậm, vkey giữ kiểu gõ theo app thay vì ép NFC — tránh lỗi mất chữ theo **chiều ngược** ở ô web lồng sâu. Gộp truy vấn Accessibility khi đổi focus cho nhẹ. Engine gõ không đổi hành vi đã thấy ở 3.6. Toàn bộ test pass.
>
> **3.6** — 🐛 **Fix "nhập" → "nḥ̂p"** (mất chữ cái, dấu rời bám nhầm) ở **Gemini app** (bundle ID thật `com.google.GeminiMacOS`, v3.4 ghi nhầm) và khi **gõ tên file/thư mục trong hộp thoại tải về của Chrome** (NSSavePanel native trong process Chromium). Fix 3 lớp: đúng bundle ID; tự phát hiện field native ngoài `AXWebArea` → flip NFC theo từng ô nhập; và diff NFD không bao giờ gửi dấu rời "trần" (lùi về đầu cụm grapheme, retype trọn chữ). Toàn bộ test pass.

> **3.5** — 🔏 **App được ký bằng chứng chỉ Apple Developer ID và notarized bởi Apple**: tải DMG về **mở ngay không bị Gatekeeper chặn** — hết thời "chuột phải → Mở". Hardened runtime bật. Engine gõ không đổi (code y hệt 3.4). ⚠️ Nâng cấp từ ≤3.4: cấp lại quyền Trợ năng **một lần** (chữ ký đổi); từ nay về sau chữ ký ổn định, không phải cấp lại nữa.

> **3.4** — ⌨️ **Gõ chuẩn hơn**: hỗ trợ **bàn phím số (keypad)** cho VNI (Shift+keypad giữ nguyên chữ số, đúng macOS); **Caps Lock chuẩn** — Shift+Caps Lock ra chữ thường, Caps Lock không còn làm sai phím dấu câu; **diff NFC/NFD theo từng app** khi xoá/sửa từ → hết lệch ký tự trong Chrome/app web, thêm Google Gemini vào nhóm NFC. 💡 **Gợi ý từ**: lọc ứng viên rác (giữ đủ từ đơn "ở"/"ừ"/"à"…), tăng trọng số học cá nhân (trigram ×6, bigram ×3). 📚 **Từ điển cá nhân**: nút **Nhập file / Xuất file** (.txt/.csv, tự dò bảng mã). 🔧 File bật/tắt `/tmp/vkey_switch` tách riêng theo user.

> **3.3** — 🚨 **Fix bug treo nghiêm trọng**: alert quyền Trợ năng (bật khi TCC cũ làm tapCreate fail sau khi đổi chữ ký) **vô hình** mà vẫn chặn main thread → menu bar không bấm được, Settings không mở. Nay alert hiện đúng + có guard chống bật chồng. **HUD hết "khoanh vuông mờ"** quanh viên capsule (vá đủ 3 nguyên nhân: shadow margin + mask blur + bỏ blend mode). **Menu bar chau chuốt** — header trạng thái VI|EN, icon nhuộm brand khi tính năng bật, popover theme có swatch màu, footer 1 hàng. Gỡ dependency `Settings` (sindresorhus) không còn dùng. 235 test pass.

> **3.2** — 🚨 **Fix lỗi nghiêm trọng**: thu hồi quyền Trợ năng khi vkey đang chạy không còn làm **treo toàn bộ macOS** (mọi bản trước đều dính — tap giằng co với hệ thống + AX call block giữ dòng sự kiện). Nay tháo tap trong ~2s, cấp lại quyền là tự chạy lại không cần mở lại app. Kèm: cờ 🇻🇳/🇺🇸 menu bar sáng đúng ngôn ngữ đang bật, ✓ Telex/VNI cập nhật ngay; thêm font **Inter** + **Nunito** (gỡ Carter One, JetBrains Mono). 235 test pass.

> **3.1** — Theme thứ ba **Neural AI**: aurora tím–cyan + gradient "trí tuệ" (tô tiêu đề / nav / nút / HUD / menu bar), slider cường độ phát sáng. Loạt fix 3.0: nút Sáng/Tối bấm được, **Liquid Glass thành kính thật** (blur nền sau cửa sổ), **chọn phông chữ hoạt động** (5 font nhúng, gỡ Carter One), layout Settings 2 cột tự dựng (bỏ ô tìm kiếm, header mỏng, titlebar liền màu theme), hết crash đổi theme. Cấu hình lưu riêng theo từng theme. Engine gõ không đổi.

> **3.0** — **Đại tu cửa sổ Cài đặt**: dựng lại bằng NavigationSplitView (sidebar + 6 tab, thêm tab **Quản lý giao diện**). Hai theme **Mặc định** (Tonal) và **Liquid Glass** (trong mờ, blur khúc xạ — macOS Tahoe), đổi nhanh trên menu bar. Tab Quản lý giao diện cho chỉnh **màu nhấn, phông chữ (6 font nhúng), bo góc, mật độ dòng, độ trong suốt** — lưu riêng theo từng theme. HUD + biểu tượng đổi theo theme. Bù đầy đủ thống kê chi tiết + quy tắc Smart Switch theo cửa sổ. Dọn sạch theme cũ. Engine gõ không đổi.

> **2.15** — (1) **Gõ tiếng Việt trong Spotlight cuối cùng đã chuẩn** (hết "goõ tieếng việt"): phát hiện ô Spotlight qua AX role thật rồi ghi thẳng qua Accessibility API (axDirect), không phụ thuộc `eventTargetUnixProcessID` (vốn sai trên macOS 26). (2) **Sửa bug "Opus"→"uOs"** ảnh hưởng mọi app: luật tự-sửa-gõ-nhầm "ou→uo" không còn nuốt phụ âm giữa. 235 test pass.

> **2.14** — Gia cố đường ghi AX-direct cho Spotlight theo kỹ thuật của [PHTV](https://github.com/PhamHungTien/PHTV): verify sau khi ghi (app trả success nhưng không áp), xử lý selection/suffix autocomplete chuẩn, lùi caret theo cụm grapheme (an toàn NFD), fallback post vào HID tap, vá auto-switch đè strategy. Kèm log chẩn đoán. 232 test pass.

> **2.13** — Khi TẮT "cho phép âm tiết đầu w/z/j/f", `w` giờ hoạt động đúng kiểu Telex cổ điển: **`w`→ư, `tw`→tư, `nhw`→như, `twf`→từ** (trước đây vẫn ra "w" do engine thiếu nhánh w-đứng-không và bảng impossible-prefix khoá `tw/dw/sw/wr`). Khi BẬT (mặc định) không đổi gì — vẫn gõ "web" bình thường. 229 test pass.

> **2.12** — Fix triệt để Spotlight: hoá ra Spotlight **nuốt synthetic backspace bất kể tốc độ** (inline-autocomplete) nên mọi chiến lược gửi phím đều thất bại. Nay vkey **ghi thẳng nội dung ô text qua Accessibility API** (`axDirect` — cùng cách gonhanh.org & xkey dùng): không phím giả lập nào được gửi, retry khi Spotlight bận, fallback an toàn. 227 test pass.

> **2.11** — Fix lại lỗi ký tự đôi Spotlight: v2.10 thêm đúng chiến lược nhưng Spotlight trên macOS 26 là UIElement (không phát notification đổi app) nên chiến lược không bao giờ được kích hoạt. Nay vkey đọc **PID app đích trực tiếp từ mỗi event** — nhận diện chính xác từng phím, mọi overlay; Smart Switch per-app cũng hoạt động đúng trong overlay. 227 test pass.

> **2.10** — Sửa lỗi gõ tiếng Việt bị **ký tự đôi trong Spotlight** ("goõ tieếng viiệt"): dùng chiến lược gửi từng phím như fix Launchpad v2.7, kèm đồng bộ chiến lược theo focus thật (bắt cả overlay mở bằng ⌘Space). Thêm: khi macOS thu hồi quyền Accessibility (sau update), vkey **tự hiện cảnh báo hướng dẫn cấp lại** thay vì chết im lặng. 227 test pass.

> **2.9** — Mở rộng fix v2.8: rà soát toàn bộ danh sách từ tiếng Anh tự khôi phục, loại thêm 18 từ mà Telex ra **từ tiếng Việt hợp lệ & phổ biến** (moon→môn, theme→thêm, tree→trê, beer→bể…). Giữ lại các từ Anh phổ biến (this/these/three…). 226 test pass.

> **2.8** — Sửa lỗi ở mode tiếng Việt gõ Telex "queen" ra "queen" thay vì **"quên"**: bỏ "queen"/"queens" khỏi danh sách từ tiếng Anh tự khôi phục (vì "quên" là từ tiếng Việt hợp lệ). 225 test pass.

> **2.7** — Sửa lỗi gõ tiếng Việt bị loạn (lặp/mất chữ, sai dấu) trong ô tìm kiếm **Launchpad**: ô này chạy trong tiến trình Dock, nay dùng chiến lược gửi phím `stepByStep` (từng phím một) để đồng bộ đúng. 223 test pass.

> **2.6** — Sửa lỗi sau khi nhấn **Enter** (xuống dòng) rồi **Backspace** có thể khôi phục nhầm từ của dòng trước (desync): nay chỉ Space mới giữ lịch sử từ để sửa lại; Enter/Tab xoá lịch sử ở ranh giới. Đối chiếu bản vá của xkey & gonhanh.org — phần lớn lỗi khác vkey đã xử lý sẵn. 221 test pass.

> **2.5** — Sửa lỗi HUD gợi ý đoán từ **đè lên dòng đang gõ** (che ô nhập) khi để offset nhỏ / cỡ chữ HUD lớn: ép đáy HUD luôn cách đỉnh caret tối thiểu 6px nên không còn che dòng văn bản. (Với app web/Electron, caret từ Accessibility API có thể lệch ngang — hạn chế riêng của app.)

> **2.4** — Bản cài gọn nhẹ hơn: bật strip symbol cho cấu hình Release (bản trước vô tình **không** strip nên binary mang theo toàn bộ symbol của thư viện Rust) + `-Osize`. Binary `vkey` **18.4 MB → ~7.0 MB**, bản tải .dmg giảm ~22% (8.4 MB → 6.6 MB). Không đổi tính năng. Thêm `deinit` gỡ NSWorkspace observer trong `AppState` (fix rò rỉ nhỏ). 218/218 test pass. Từ bản này version dùng 2 cấp `MAJOR.MINOR`.

> **2.3.21** — v2.3.20 fix "google" thành công nhưng "footer" vẫn lỗi vì "footer" không có trong English lexicon → `transformedIsEnglish` return false. Fix triệt để hơn: detect Telex mu cancellation pattern (rawInput có 3 nguyên âm liên tiếp `ooo/aaa/eee/uuu/iii` AND collapse triple→double cho ra transformed → keep transformed). Catches mọi English word ngoài lexicon: "foooter→footer", "nooose→noose", "baaad→baad". 218/218 test pass.

> **2.3.20** — **ROOT CAUSE FIX** confirmed từ v2.3.19 runtime logs. Bug "google → gooogle" thực ra do user gõ "gooogle" (3 o's intentionally để cancel Telex mu). vkey engine produces transformed="google" (raw không mu). At commit, evaluate's line 136 (`if rawToken != transformedToken → return .restoreRawEnglish(rawInput)`) sai vì restoreRawEnglish dùng RAW INPUT ("gooogle") thay vì keep transformed ("google" English). Fix: thêm check `if transformedIsEnglish { return .keepRaw }` TRƯỚC line 136. Giữ transformed khi đã là English word hợp lệ. Real cases ("text"→"tẽt"→restore "text") vẫn work (transformed="tẽt" không phải English → restore raw). Remove debug logs từ v2.3.19. 217/217 test pass.

> **2.3.19** — User confirm v2.3.18 vẫn lỗi. Tất cả hypothesis từ trước SAI. Phiên bản này KHÔNG fix bug — thêm `os_log` để capture state thực tại runtime. User chạy Console.app, filter `subsystem:dev.longht.vkey category:SpellCommit`, gõ "google" + space, gửi log lines lại để chẩn đoán đúng root cause. 217/217 test pass.

> **2.3.18** — User confirm v2.3.17 (short-circuit chỉ restoreRawEnglish) vẫn lỗi. Bug có thể fire qua .suggest hoặc decision path khác. v2.3.18 short-circuit UNIVERSAL ở ENTRY của `applySpellDecisionOnCommit`: nếu `current == rawInput` (vkey chưa transform gì), bypass entire spell decision logic. Real cases (Vietnamese typing với diacritics, English-with-Telex-tones như "text"→"tẽt") vẫn fire spell decision bình thường (current != rawInput). 217/217 test pass.

> **2.3.17** — User diagnostic CHÌA KHÓA: bug "gooogle" CHỈ xảy ra khi bật spell check, tắt thì không bug. Root cause: cho "google" typing, recovery đã set `transformed="google"` (raw đúng). Tại space, spell decision returns `.restoreRawEnglish("google")` (rawIsEnglish=true). Code chạy Option+Backspace + sendString "google " để restore raw — nhưng `current == restoredWord` rồi (không cần restore). Việc fire restoration gây side-effect → bug. Fix: short-circuit `return false` khi `current == restoredWord`. Để endingChar pass-through như khi spell check OFF (đã proved không bug). Restoration vẫn work cho real cases (vd "text"→"tẽt"→"text"). 217/217 test pass.

> **2.3.16** — User confirm v2.3.15 vẫn lỗi. Hypothesis: Option+Backspace v2.3.15 chỉ set flag `.maskAlternate` không đủ với Notes/Claude desktop (apps check actual modifier state qua NSEvent, không react với synthesized flag). v2.3.16 gửi đầy đủ event sequence như user thực sự nhấn: Option DOWN → Backspace → Backspace UP → Option UP. Tăng usleep 2ms → 10ms để app process kịp word deletion. 217/217 test pass.

> **2.3.15** — Cách tiếp cận MỚI dựa trên user diagnostic. Bug "google → gooogle" xảy ra ngay cả Notes (Apple native), diverge tại commit-time (sau space). Trước đây hypothesis NFC/NFD đều sai. Root cause: display BEFORE space đã có extra 'o' (CGEvent round-trip ở intermediate steps), vkey buffer "google" đúng nhưng diff (0, " ") chỉ send space, không sửa được. Fix: dùng **Option+Backspace** (macOS standard "delete word") + sendString full word tại `restoreRawEnglish` commit. Bypass diff calc, wipe entire word + retype. 217/217 test pass.

> **2.3.14** — Revert v2.3.13 NFD diff. User confirm "gooogle, foooter" vẫn còn trong Claude desktop kể cả v2.3.13. Cascade v2.3.8–v2.3.13 thử nhiều hypothesis (NFC/NFD storage × grapheme/scalar backspace) đều thất bại. v2.3.14 quay về grapheme diff stable cho mọi app (giống v2.3.11). Bug "gooogle" trong Chromium/Electron VẪN CHƯA FIX — cần thông tin diagnostic chi tiết từ user. Workaround tạm: tắt vkey (⇧⌥) khi gõ English ngắn. 217/217 test pass.

> **2.3.13** — User report bug "gooogle, foooter ở claude desktop hay bất kỳ đâu". v2.3.12 chỉ áp NFD diff cho search fields → không đủ. v2.3.13 mở rộng: NFD diff cho TẤT CẢ non-Apple apps (Chromium, Electron, Claude desktop, browsers, web inputs…). Whitelist NFC+grapheme: `com.apple.*`, iWork, Microsoft Office native (Word/Excel/Powerpoint/Outlook/OneNote). Mọi thứ khác mặc định NFD. 217/217 test pass.

> **2.3.12** — Sửa nốt "google → gooogle" + "footer → foooter" trong Chrome URL bar / Google search. KHÔNG phải tính năng auto-correct mà do **scalar/grapheme mismatch**: Chrome URL bar store "ô" dạng NFD (`o` + combining `̂` = 2 scalars) và backspace cũng đếm scalar. Grapheme-based `backspaceCount=2` chỉ xóa 2 scalars `̂g` thay vì 2 graphemes `ôg` → còn 'o' thừa → "gooogl". Fix: dùng `calcKeyStrokesNFD` (đếm scalar) cho search fields. Apple text views + Google Docs vẫn dùng grapheme diff. 217/217 test pass.

> **2.3.11** — Sửa nốt "google → gooogle" trong Chrome URL bar / Google search. v2.3.10 fix được Google Docs nhưng URL bar vẫn lỗi (Shift+Left + NFD diff không tương tác đúng với autocomplete). v2.3.11 đơn giản hóa: dùng backspace + retype cho **mọi app**. Drop `sendSelectAndReplace` path. Trade-off: v1.8.3 introduce Shift+Left để fix "footer → foooter" trong browsers — nếu bug đó quay lại trong v2.3.11, sẽ cần fix khác. 217/217 test pass.

> **2.3.10** — Sửa cả 2 bug còn lại: Google Docs/Sheets duplicate syllable ("trình → trinình", "kiểm → kiêmểm"…) + Chrome URL bar "google → gooogle". Root fix: distinguish "search field" vs "text area" qua AX role thay vì bundle ID. Google Docs (AXTextArea) giờ dùng backspace path (hoạt động đúng trong contenteditable). Chrome URL bar / Google search box (AXSearchField) vẫn dùng Shift+Left + re-enable NFD-aware diff (Chrome URL bar store NFD scalar). 217/217 test pass.

> **2.3.9** — HOTFIX KHẨN: revert v2.3.8 NFD-aware diff. v2.3.8 dựa trên hypothesis sai (Chrome store NFD) — thực tế Google Docs ignore Shift+Left của vkey nên NFD diff biến mọi syllable Vietnamese trong Docs thành duplicate ("trình → trinh̀nh", "các → caćc", "kiểm → kiêm̉m"). v2.3.9 quay lại grapheme diff cho mọi app, giữ lexicon additions (google, tools, sheets, docs…). "google → gooogle" trong Chrome address bar / Google search vẫn còn (pre-existing), cần research khác. 217/217 test pass.

> **2.3.8** — Sửa lỗi "google → gooogle" (extra 'o') khi gõ trong Chrome, Google Docs, Google Sheets. Root cause: Chrome store Vietnamese text dạng NFD (o + combining ◌̂) trong khi vkey send NFC (precomposed ô). Shift+Left của Chrome đếm UTF-16 scalar, không phải grapheme → selectLeftCount thiếu → replace bỏ sót 'o'. Fix: thêm `calcKeyStrokesNFD` compute diff trong NFD scalar space, dùng riêng cho `FixAutocompleteApps` (browsers, Google). Apple apps (Notes, TextEdit) vẫn dùng grapheme diff. Bonus: thêm common English words vào instant-restore lexicon (google, youtube, facebook, sheets, docs, spreadsheet, good, wood, look, book, food, week, screen, feed, free, tree…). 217/217 test pass.

> **2.3.7** — Sửa lỗi không thể gõ `QĐ`, `BCTĐ`, `vcđ`… khi Free Mark Mode đang bật. Anywhere-DD toggle (v1.9.7) trước đây bị gate bởi `stopProcessing` — chỉ fire khi validator trả về `needsRecovery=true`. Free Mark Mode bypass validator → `stopProcessing` không set → toggle không fire. Fix: thêm universal pre-check ở đầu `WordBuffer.push`, fire bất kể recovery state. Conflict avoidance: gate bằng `ddToggleStage == 0` + second-to-last không phải d/D (giữ toggle-off/frozen state machine). Initial Telex `dd → đ` không đổi. 216/216 test pass.

> **2.3.6** — Sửa lỗi từ tiếng Anh bắt đầu bằng phụ âm loanword (`w/z/j/f`) bị parser áp nhầm typo-correction tiếng Việt: `weight → wieght`, `four → fuor`. Trong ô tìm kiếm (Google search, address bar…) rollback không kịp nên `wieght` còn lại trên màn hình. Fix: thêm guard `!startsWithForeignConsonant(phuAmDau)` vào 4 rule swap vowel (veit→viet, bous→buos, haois→hoais, haoc→hoac). Lý do: tiếng Việt không có từ bản địa bắt đầu bằng `w/z/j/f`. Native consonants vẫn áp như cũ (`veit → viet`), tone marks cho loanword vẫn áp (`zas → zá`). 214/214 test pass.

> **2.3.5** — Sửa lỗi gấp khi gõ Telex trong Microsoft Excel: con trỏ "nhảy" và bôi các ô bên trái, làm chữ Việt compose sai. Nguyên nhân: Excel nằm nhầm trong danh sách `FixAutocompleteApps` (vốn dành cho browser có inline autocomplete), nên đường gõ dùng `Shift+Left` — mà trong Excel `Shift+Left` = mở rộng selection sang cell trái. Fix: loại Excel khỏi danh sách → rơi xuống nhánh backspace+retype an toàn với strategy `.hybrid(1000μs)` đã có sẵn (giống Word/PowerPoint/Outlook/OneNote, vốn ổn lâu nay). Dropdown gợi ý của Excel (`=SUM`…) và Edge browser không bị ảnh hưởng.

> **2.3.4** — Tonal theme refresh full theo handoff design CSS. New **TonalRowIcon** component (flat sunken tile + red brand accent, match `.row__icon`) cho mọi menu/setting row. HUD scrim 4-layer match `.hud` exactly (top highlight + warm ink + material blur + inset border). Settings header icon radius 22→28pt (`--r-2xl`). Visual differentiation matrix Tonal (refined macOS native) vs LG (premium 3D visionOS) bây giờ rõ rệt.

> **2.3.3** — Liquid Glass theme bây giờ render đầy đủ với **3D glass tile icons** (gradient + diagonal gloss + top arc specular + white rim + drop shadow) match design `SwiftSnippets.jsx`. New `GlassTile` SwiftUI component + opt-in env `useGlassTile` cho MenuContent/Settings. MenuBarLabel status icon giữ flat (macOS conventions). 7 màu preset (red/gold/blue/green/purple/gray/ink) + 40+ SF Symbol category map. Bonus: fix pbxproj path cho FontRegistration.swift.

> **2.3.2** (1) Settings header bỏ wordmark "vkey" + tagline ở mọi theme — chỉ giữ logo centered. (2) Liquid Glass MenuBar có per-category icon colors theo design `MenuBar.jsx`: blue (Smart Switch/info), green (spell check/refresh), purple (Macro), gold (theme picker/donate), red (Thoát/VI), gray (gear/keyboard). Tonal giữ accent red đồng nhất → visually obvious khác biệt khi switch theme.

> **2.3.1** fix 2 bug user feedback: (1) cả 2 nút phím tắt VI/EN và Text Tools hiển thị cùng modifier mask (cùng hiện ⌥⇧) — parameterize `FlexibleShortcutButton` để mỗi nút đọc đúng Defaults key của nó. (2) Liquid Glass header giờ có refractive corner tints (red bottom-left + blue top-right), top-arc specular gloss, caustic halo 3-stop, glass rim border, triple shadow — visually obvious khác Tonal.

> **2.3.0** đồng bộ code Swift với handoff bundle chính thức của Liquid Glass + Tonal. HUD VI/EN restructure ngang (flag + label-stack + keycap row), prediction format mới `→ <từ> · Tab(keycap)`, Settings header ngang với Noto Sans Display 36pt + gradient text + halo đỏ radial. Bundle 2 custom fonts (Noto Sans Display Variable 1.54 MB + Carter One 64 KB) qua `FontRegistration.swift` runtime register. Refresh `Design/` folder với handoff đầy đủ (43 SVG icons + brand logos + 22 preview HTML + SKILL.md). Engine gõ + 213 test giữ nguyên. **2.2.2** xoá theme "3D bóng bẩy" và "Sơn Mài". Thêm **Liquid Glass** — refractive multi-layer glass theo phong cách macOS Tahoe / visionOS: đỏ brand `#E04434` + glass surfaces `rgba(28,30,38,0.55)` + edge highlights triple-layer + refractive corner tints + backdrop blur 40-60px saturate 200%. Tổng **4 giao diện** trong menu bar (Mặc định / Emoji vui tươi / Tonal / Liquid Glass). **2.2.1** thay theme Mực bằng Sơn Mài — sơn son thếp vàng, lacquer Vietnamese art aesthetic. **2.2.0** thêm Mực theme (high-contrast editorial, lacquer red), nâng tổng số giao diện lên **5** (Mặc định / 3D bóng bẩy / Emoji vui tươi / Tonal / Mực). Theme picker chuyển từ Settings → menu bar (gộp với "Giao diện ứng dụng"). Fix bug Telex "theme" → "thêm" (engine sai áp dụng luật mũ 'e..e' khi 'e' thứ 2 đến sau final consonant). Mở rộng range HUD line offset 1-10 → 1-20. **2.1.1** tách Tonal redesign thành **theme** tùy chọn — user có thể switch giữa Classic (v2.0.2 look) và Tonal (v2.1.0 design) qua Settings → tab Chung → Picker "Giao diện". Switch live, không cần restart. Kiến trúc mở để thêm theme thứ 3+ sau này. **2.1.0** áp dụng [vkey Design System "Tonal"](Design/) — refresh diện mạo macOS-native: app icon mới, accent color brand red `#E04434`, HUD glass tối với typography tiếng Việt, Settings header có wordmark "vkey", design tokens centralize trong `VKeyDesign.swift`. Engine gõ, từ điển và spell-check không thay đổi — toàn bộ 212 test pass nguyên trạng. **2.0** gộp 13 tính năng mới lấy cảm hứng từ xkey + gonhanh.org: Auto-capitalize, Free Mark mode, Window Title Rules, Auto-disable khi đổi IME, Text Conversion Tools, Pipeline 7-stage tường minh, Race-condition hardening, **Rust Core Engine foundation** (qua FFI). **2.0.1** dọn dẹp 3 mục chưa hoàn chỉnh (Floating Toolbar, HUD theme controls), gộp tab Rules vào Smart Switch. **2.0.2** fix bug class "toools" (gõ "text tools" → "toools"), đơn giản hoá prediction về top-1, đổi default hotkey VI/EN sang ⇧⌥ + Text Tools sang ⌃⇧.

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Data: CC BY-SA 4.0](https://img.shields.io/badge/Data-CC%20BY--SA%204.0-orange.svg)

> **vkey là một bản fork mở rộng từ [Caffee](https://github.com/khanhicetea/Caffee)** của tác giả Khanh Nguyen ([@khanhicetea](https://github.com/khanhicetea)). Toàn bộ engine xử lý âm tiết tiếng Việt (Telex / VNI / Parser / Transformer / Validator) cùng kiến trúc Platform-Layer ban đầu đều do tác giả gốc xây dựng.
>
> Đồng thời, kể từ phiên bản v1.3.9 trở đi, vkey đã **học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc** từ các dự án:
> - **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen ([@xmannv](https://github.com/xmannv)) — HUD mờ kính, AX Probing Smart Switch, bộ lọc phụ âm Impossible Clusters (v1.3.9 → v1.4.5).
> - **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** — thuật toán ma trận kiểm tra chính tả 6 bước, Vowel Inclusion Pairs, Space Restore, Escape Reversion, bảo toàn phím đúp (v1.4.1+).
>
> Đồng thời tích hợp dữ liệu từ điển từ 2 nguồn mã nguồn mở:
> - **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của Luông Hiếu Thi ([@hieuthi](https://github.com/hieuthi)) — baseline 7,184 âm tiết tiếng Việt curated (v1.5.0+).
> - **[undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary)** của Vũ Anh ([@undertheseanlp](https://github.com/undertheseanlp)) — bổ sung 1,710 syllables (Hồ Ngọc Đức + tudientv + Wiktionary VN) qua audit + phonotactic filter, GPL-3.0 (v1.6.1+).
>
> Bộ từ điển hiện tại (v9 — v1.7.9+): **8,960 syllables tiếng Việt** + **9,826 từ tiếng Anh** (mở rộng từ 126 ở v1.7.8 → 9,826 ở v1.7.9 qua `wordfreq` top 10000). VN baseline rà soát qua [Tools/audit_lexicon.py](Tools/audit_lexicon.py) + [Tools/merge_underthesea_deep.py](Tools/merge_underthesea_deep.py); EN qua [Tools/build_lexicon.py](Tools/build_lexicon.py). v1.7.1 inject lại 66 single-char VN diacritics (`à`, `á`, `ý`, `ô`, `ở`...) đã bị drop nhầm ở v7.

---

## Hiệu năng (v2.0+)

**Mục tiêu** đo bằng XCTest performance baseline (xem `vkeyTests/vkeyTests.swift` → `test_benchmark_*`):

| Phép đo                                                | Ngưỡng       | Đo được (M-series, 2026-05) | Ý nghĩa                                |
|--------------------------------------------------------|--------------|------------------------------|----------------------------------------|
| Telex parse 1 ký tự (1 000 ×)                          | ≤ 50 ms      | ~12 ms                       | Hot loop trong CGEvent tap callback    |
| Telex full word `tieengs` → `tiếng` (7 keys × 1 000)   | ≤ 300 ms     | ~92 ms                       | End-to-end parse + transform + tone    |
| VNI full word `tieng61s` (8 keys × 1 000)              | ≤ 300 ms     | ~100 ms                      | So sánh với Telex                      |
| 1 000 ký tự Telex liên tục                              | ≤ 50 ms      | ~14 ms                       | Stress test buffer + state machine     |
| Lexicon `isInstantRestoreEnglish` (14 từ × 1 000)      | ≤ 280 ms     | ~19 ms                       | Decision điểm cuối stage 6             |
| Pure parse (10 000 ×) — chỉ stage 3–5                  | baseline     | ~276 ms                      | Compare khi port sang Rust (C2)        |

Tất cả benchmark hiện tại **dưới ngưỡng** an toàn — engine Swift đủ nhanh cho input method (per-char latency < 0.05 ms).

> Cách reproduce: mở `vkey.xcodeproj` → ⌘+U → Test Navigator → chọn các method bắt đầu `test_benchmark_`. Lần đầu set baseline (⌥-click trên kết quả → Set as Baseline). Xcode sẽ cảnh báo nếu regression > 10%.

## Chức năng

- ✅ Gõ tiếng Việt với 2 kiểu phổ biến: **Telex** và **VNI**.
- ✅ Tuỳ chọn kiểu đặt dấu: **Kiểu mới** (thuỷ, khoẻ, hoà, uý) hoặc **Kiểu cũ** (thủy, khỏe, hòa, úy).
- ✅ **Hỗ trợ bàn phím số & Caps Lock chuẩn macOS (v3.4+)**: gõ dấu VNI bằng **keypad** hoạt động đúng (Shift+keypad giữ nguyên chữ số); **Shift+Caps Lock** trên chữ cái ra chữ thường, Caps Lock không ảnh hưởng phím dấu câu/số. Diff xoá/sửa từ phân biệt app lưu **NFC** (Apple, MS Office, iWork, Google Gemini) và **NFD** (Chromium/Electron/web) → backspace không còn lệch ký tự trong Chrome & app web. **v3.6+**: phát hiện theo **từng ô nhập** qua AX — hộp thoại native trong app Chromium (vd Save panel của Chrome khi tải file) tự flip sang NFC; diff NFD không bao giờ gửi dấu rời "trần" → hết lỗi mất chữ "nhập" → "nḥ̂p".
- ✅ **Tự động sửa lỗi gõ nhầm (Auto Typo Correction)**: Tự động sửa khi gõ nhầm dấu thanh sớm hoặc sai vị trí (ví dụ: `thfi` -> `thì`, `thfis` -> `thí`, `th2i` -> `thì`, `th1i` -> `thí`), sửa gạch chữ đ cuối từ (ví dụ: `dinhjd` -> `định` / `dinh59` -> `định`), sửa lỗi hoán đổi nguyên âm (ví dụ: `veeitj` -> `việt`) và hoán đổi phụ âm cuối (ví dụ: `phuowgn` -> `phương`). Có thể bật/tắt dễ dàng trong Cài đặt.
- ✅ Bộ gõ chỉ duy nhất Unicode (UTF-8), không hỗ trợ TCVN3/VNI Windows (giữ đơn giản).
- ✅ Nhớ chế độ Vi/En theo từng ứng dụng (per-app input mode memory).
- ✅ **Smart Switch 3-state per-app (v1.7.0+, major refactor)**: mỗi app có thể có 1 trong 3 state — 🇻🇳 **Tiếng Việt** / 🇺🇸 **Tiếng Anh** / ⛔ **Không dùng vkey**. Mỗi state hiển thị icon nguồn: 👤 (user đặt thủ công) hoặc 🤖 (vkey tự học từ Thống kê). User setting LUÔN override auto-learn. Thay list 1-chiều cũ "luôn tắt VN" của v1.5.x-v1.6.x.
- ✅ **Smart Switch auto-learn (v1.7.0+, nhanh hơn v1.7.2+)**: vkey theo dõi ngôn ngữ user gõ trong từng app qua Stats. **v1.7.2**: threshold giảm còn ≥1 ngày dataset, ≥5 commit/ngày, ratio ≥75% một ngôn ngữ → tự động set state. Chạy **1 lần/ngày** (thay 1 lần/tuần) → user thấy gợi ý sau ~1 ngày gõ.
- ✅ **AX Probing Smart Switch (push-based v1.8.0+, focus-shifting keys v1.8.2+)**: Tự động đổi chế độ khi vào các bảng nhập liệu dạng Overlay/Launcher (Spotlight, Raycast, Alfred, LaunchBar). **v1.8.0**: chuyển từ AX query đồng bộ trong event tap callback sang push-based — `currentFocusedBundleId` được cập nhật qua `NSWorkspace.didActivateApplicationNotification` + async refresh mouse-click. Event tap callback chỉ đọc cached value (zero AX work) → giảm nguy cơ macOS vô hiệu hóa tap. Cũng support đầy đủ Smart Switch 3-trạng thái trong overlay path (`.englishMode`/`.vietnameseMode`/`.disabled`), không chỉ `.englishMode` như trước. **v1.8.2** thêm focus-shifting key detection: phím Tab/Enter/Esc/mũi tên cũng trigger async refresh → focus update kịp thời khi user chuyển ô bằng phím. Đồng thời **tự động quét ô nhập liệu** (`AXComboBox`/`AXSearchField`) qua `Focused.isComboBoxOrSearchField` → kích hoạt strategy chống dính chữ tự động bất kể app nào (Safari address bar, Spotlight, Find bar...).
- ✅ **Kiểm tra Chính tả 6 bước & Vowel Inclusion Pairs (từ GoNhanh.org)**: Triệt để ngăn chặn gõ dấu sai cấu trúc âm tiết tiếng Việt. Bộ whitelisting các cặp nguyên âm có thể đi cùng nhau loại bỏ triệt để hiện tượng tự động sửa nhầm trên các từ tiếng Anh (như `claus`, `metric`, `house`, `beyond`). Hỗ trợ gõ phụ âm đầu ghép `kr` (như trong *Krông Ana*) và phụ âm cuối `k` (như trong *Đắk Lắk*).
- ✅ **Bảo toàn Phím đúp (Doubled Tone Mark Preservation)**: Giữ nguyên phím đúp liên tiếp (`ss`, `ff`, `rr`, `xx`, `jj`) cho các từ tiếng Anh thông dụng như `staff`, `off`, `class`. **v1.7.5+**: tone-cancel ưu tiên hơn — gõ "ả" + "r" (xoá hỏi) + "m" giờ ra "arm" thay vì "arrm" (trước đây bị "arr" English-preservation chặn). Trade-off: từ tiếng Anh rất ngắn như "ass"/"arr" gõ tuần tự (không qua impossible-cluster) mất 1 ký tự.
- ✅ **Tự động Khôi phục từ Tiếng Anh (Space Restore)**: Tự động phát hiện và khôi phục các ký tự tiếng Anh bị gõ nhầm khi nhấn phím Space (như `ò` -> `of`, `ì` -> `if`, `sê` -> `see`, `tê` -> `tee`).
- ✅ **Phục hồi Nhanh phím ESC (Escape Reversion)**: Nhấn ESC để hoàn tác ngay lập tức từ đang gõ dở dang về dạng phím thô ban đầu và đặt lại bộ đệm.
- ✅ **Hiển thị thông báo trực quan (Translucent Toggle HUD, customize v1.9.0+)**: Cửa sổ thông báo mờ kính (Glassmorphic HUD) hiển thị giữa màn hình khi chuyển đổi chế độ gõ (VI/EN) qua phím tắt, giúp nhận biết trạng thái gõ tức thời mà không cần nhìn lên Menu Bar. Tự động thông minh bỏ qua khi khởi động và Smart Switch. **v1.9.0** thêm 2 Stepper trong tab Chung: **Cỡ chữ HUD đoán từ** (10-20pt) và **Độ đậm HUD** (50-100%) — áp dụng cho cả ToggleHUD và PredictionHUD.
- ✅ **Macro** (viết tắt → cụm dài): gõ `vn ` → ra `Việt Nam `.
- ✅ Phím tắt linh hoạt: hỗ trợ cả tổ hợp key+modifier (vd `⌃⇧Z`) và **modifier-only** (vd nhấn-thả `⌃⇧` để toggle).
- ✅ Fix lỗi thanh địa chỉ trình duyệt + Excel autocomplete.
- ✅ Tương thích Electron / web app (Notion, Slack, Discord…): mặc định dùng **hybrid sending strategy** (backspace delay 800µs) đợi vòng composition. Một số app có per-app override sẵn để chạy ổn định nhất: Claude desktop + terminals (Terminal, iTerm2, Kitty, Ghostty, Warp, Hyper, Tabby, Alacritty) dùng `stepByStep`; Microsoft Office (Word, Excel, PowerPoint, Outlook, OneNote) dùng `hybrid` với backspace delay 1000µs.
- ✅ Tự bypass khi macOS bật secure input (gõ password an toàn). **v2.3.22+**: chế độ riêng tư (biểu tượng khoá) bám theo app đang dùng — nếu một app giữ ô mật khẩu rồi bạn chuyển sang app khác, vkey gõ lại bình thường ở app mới (chỉ khoá lại khi quay về app có ô mật khẩu, hoặc app hiện tại có ô mật khẩu của riêng nó).
- ✅ Khởi động cùng macOS (tuỳ chọn).
- ✅ Hoạt động xuyên QWERTZ / AZERTY / Dvorak (dùng physical key code → mapping QWERTY position cho Telex/VNI).
- ✅ **Cập nhật trực tiếp (Sparkle Integration)**: Tải và cài đặt trực tiếp bản cập nhật mới nhanh gọn, an toàn. Auto-check khi launch (throttle 1 lần/ngày từ v1.6.0), thông báo banner macOS khi có bản mới.
- ✅ **Thống kê sử dụng (v1.5.0+, cải tiến v1.6.0+, lọc mashing v1.8.0+)**: Theo dõi cục bộ (không gửi đi đâu) các từ bạn gõ nhiều nhất trong tuần. **v1.6.0+**: thay vì auto-promote ngầm, vkey hiển thị **danh sách đề xuất** để bạn review từng cụm ≥5 lần trước khi thêm vào Allow/Keep — tránh tích luỹ rác. **v1.6.1+**: track cụm 2-3 từ tiếng Việt liên tiếp (vd "công ty của tôi") để đề xuất macro. **v1.8.0+**: lọc keyboard mashing trước khi gợi ý — chuỗi không nguyên âm (`xzcvbn`), quá dài (>18 ký tự), hoặc cách quá xa từ tiếng Anh thật (Levenshtein > max(2, len/4)) bị reject thẳng. Hết noise loại "asdfgh" lọt vào suggestion list. Có thể tắt hoàn toàn hoặc xoá dữ liệu.
- ✅ **Section "Các tuần đã đóng" (v1.6.1+)**: hiển thị data thống kê tuần trước (historical) ngay trong tab Thống kê — không còn "biến mất" sau khi tuần ISO chuyển.
- ✅ **Top cụm 2-3 từ tiếng Việt + ngoài tiếng Việt (v1.7.9+)**: tab Thống kê thêm 2 sections "Top cụm 2-3 từ tiếng Việt" (`vnPhraseCounts2/3` từ v1.6.1) và "Top cụm ngoài tiếng Việt" (backend mới `enPhraseCounts2/3`). Hữu ích để xác định cụm thường gõ → tạo macro hoặc đề xuất personal dict. Section "Top từ ngoài tiếng Việt" cho phép cả raw text + ký tự lạ (vd "lol", "okay") để dễ thấy candidate bổ sung Personal Dict (filter nới v1.7.10+).
- ✅ **Balanced restore policy ưu tiên dấu Việt (v1.7.11+)**: ở chế độ **Cân bằng**, khi `transformed` có dấu Việt (`ả`/`ư`/`đ`/...) → vkey giữ VN bất kể raw có match English. Gõ "car " (telex của "cả") giờ ra "cả" thay vì "car"; "the→thể", "nuut→nứt" cũng đúng. Common-words list ~45 từ giờ chỉ fallback cho từ phẳng không dấu.
- ✅ **Đoán từ tiếp theo (v1.6.0+, default OFF, HUD chính xác v1.7.9+, file-backed v1.8.0+, UX fix v1.8.1+, chuyển sang Tab Chính tả v1.8.3+)**: HUD nổi cạnh caret hiện 1 ứng viên dự đoán sau khi commit 1 từ. Nhấn **Tab** để chấp nhận; phím khác để bỏ qua. **v1.6.1+** ranking ưu tiên từ điển gốc + cá nhân. **v1.7.7+** HUD hiển thị PHÍA TRÊN caret line (đỡ che cursor) + Tab smart-detect cho 2 case buffer khác nhau. **v1.7.9+** HUD dùng `kAXBoundsForRangeParameterizedAttribute` lấy pixel caret chính xác (multi-line editor không còn đặt HUD ở top editor). **v1.8.0+** bigram/trigram tách khỏi UserDefaults plist sang file JSON tại `~/Library/Application Support/vkey/ngram/` + background queue + throttled flush 10s. Dict prediction tăng vài MB không còn block UI khi commit từ. **v1.8.1+** sửa bug thừa space khi Tab accept sau commit Space (`"đoán  từ"` → `"đoán từ"`) + Stepper trong Settings cho user chỉnh **Khoảng cách HUD đến caret** (1-10 dòng văn bản, default 4) — không còn HUD che dòng đang gõ. **v1.8.3** chuyển toggle + Stepper sang **Tab Chính tả** → section "Cấu hình kiểm tra chính tả" (cùng nhóm với spell-checking).
- ✅ **Sao lưu & khôi phục dữ liệu cá nhân (v1.5.0+)**: Xuất / nhập JSON gồm toàn bộ Cài đặt, Macro, từ điển cá nhân, Smart Switch, per-app override, thống kê. Khi cập nhật phiên bản, app tự động hỏi sao lưu trước khi tiếp tục.
- ✅ **Từ điển GitHub tự động cập nhật (v1.5.0+, cải tiến v1.6.2+ / v1.7.9+, tra cứu inline v1.9.0+)**: vkey tự fetch `lexicon-update.json` từ `raw.githubusercontent.com/tuanlongsav/vkey` (v1.6.2+ chuyển từ Contents API, không còn giới hạn 1 MB + bỏ rate-limit) mỗi 24h khi launch. **Nút "Cập nhật từ điển ngay" (v1.6.2+)** trong tab Chính tả để force kiểm tra ngay. **v1.7.10** UI hiển thị riêng số từ VN + EN (`Tiếng Việt: vX · N từ` + `Tiếng Anh: vX · N từ`). Hiện tại **v9: 8,960 syllables VN + 9,826 từ EN** (file 257 KB). **v1.9.0** thêm section **"Tra cứu từ điển"** — gõ 1 từ → realtime hiển thị từ đó thuộc lexicon nào (VN / EN / Keep / Personal Allow/Keep/Deny).
- ✅ **Đề xuất Macro từ Thống kê (v1.5.5+, mở rộng v1.6.1+)**: vkey nhận diện các từ và cụm từ tiếng Việt bạn gõ ≥10 lần → đề xuất tạo macro với viết tắt tự sinh (vd "công ty → ct", "kính gửi anh → kga").
- ✅ **Sheet "Tự học từ Thống kê" (v1.7.0+)**: bấm trong tab Smart Switch để preview các app vkey gợi ý đổi state, áp dụng hàng loạt. User-set entries (🔒) tự động bị skip.
- ✅ **Gửi từ điển cá nhân cho tác giả (v1.7.2+, đưa ra ngoài v1.7.11+)**: nút **"Gửi cho tác giả"** đặt ngay trong tab Chính tả cạnh nút **"Sửa từ điển cá nhân"** (đổi tên từ "Quản lý" ở v1.7.11). Gate ≥50 từ trong tổng Allow/Keep/Deny. Click mở app mail mặc định gửi tới `tuanlong.sav@gmail.com` với body chứa 3 lists để tác giả rà soát + bổ sung vào từ điển chung.
- ✅ **Cửa sổ Cài đặt resize được (v1.6.1+, đúng API v1.7.6+, rộng hơn v1.8.4+)**: dùng SwiftUI `.windowResizability(.contentMinSize)` cho phép drag góc/cạnh tự do; kích thước được nhớ qua `setFrameAutosaveName` giữa các lần mở. **v1.7.8** default opening 432×648 + tab labels gốc + font `.system(size: 10)` cho tab bar compact. **v1.8.4** width 432→**540** để fit nút "Chạy compute đề xuất ngay" trong tab Thống kê. User vẫn resize lên rộng tuỳ ý.
- ✅ **3 giao diện ứng dụng (v1.5.5+, hoàn thiện v1.8.2+)**: chọn ở menu bar → "Giao diện ứng dụng": **Mặc định** (SF Symbol đơn giản), **3D bóng bẩy** (gradient + double shadow), **Emoji vui tươi** (Unicode emoji icons). **v1.8.2** rà soát toàn bộ View files + menu bar state icons + HUD icons sang dùng `ThemedSymbol` → theme apply consistent 100% (trước còn 6 file dùng `Image(systemName:)` không apply theme).
- ✅ **Diagnostic export Stats (v1.6.1+)**: nút "Xuất chẩn đoán Stats" trong tab Thống kê → ghi file text mô tả tình trạng files + counters → gửi maintainer khi báo lỗi.
- ✅ **Lịch sử clipboard tùy chỉnh (v3.16+, tắt mặc định)**: ⌘C lưu snapshot vào RAM (phiên làm việc); ⌥⌘V mở menu chọn mục → dán; ⌘V / ⇧⌘V dán clipboard hệ thống như macOS. Cài đặt số mục (3–50) và chế độ chỉ văn bản / văn bản + tệp trong tab Chung.
- ✅ Hỗ trợ **Ủng hộ tác giả** (Donate) qua VietQR.

## Hình ảnh minh hoạ

<p align="center">
  <img src="images/menubar-menu.png" width="260" alt="Menu bar dropdown">
  <img src="images/general-settings.png" width="260" alt="Tab Chung">
  <img src="images/smart-switch-settings.png" width="260" alt="Tab Smart Switch">
  <img src="images/macro-settings.png" width="260" alt="Tab Macro">
  <img src="images/spellcheck-settings.png" width="260" alt="Tab Chính tả">
  <img src="images/statistics-settings.png" width="260" alt="Tab Thống kê & Sao lưu">
</p>

## Cài đặt

### Tải file DMG (đơn giản nhất)

1. Tải `vkey-x.y.dmg` từ trang [Releases](../../releases/latest).
2. Mở DMG → kéo `vkey` vào thư mục `Applications`.
3. Mở app bình thường — từ **v3.5+** vkey được ký bằng **Apple Developer ID** và **notarized bởi Apple**, Gatekeeper không còn chặn (các bản ≤3.4 ký ad-hoc phải chuột phải → "Mở" 1 lần).
4. Vào **System Settings → Privacy & Security → Accessibility** → bật toggle cho `vkey`.
5. Tắt rồi mở lại app để event tap được nạp.

> **Nâng cấp từ bản ≤3.4**: do chữ ký app đổi (ad-hoc → Developer ID), macOS sẽ yêu cầu **cấp lại quyền Trợ năng một lần** sau khi cập nhật lên 3.5. Từ 3.5 trở đi chữ ký ổn định — các bản sau không phải cấp lại nữa.

### Build từ source

Yêu cầu: macOS 14+ (Sonoma), Xcode 15.3+ (Swift 5.10+).

```bash
git clone https://github.com/tuanlongsav/vkey.git
cd vkey
xcodebuild -project vkey.xcodeproj -scheme vkey \
  -configuration Release \
  -derivedDataPath /tmp/vkey-release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  clean build
ditto /tmp/vkey-release/Build/Products/Release/vkey.app /Applications/vkey.app
```

## Sử dụng

### Thao tác nhanh trên Menu Bar

Click icon cờ trên menu bar để mở các tác vụ nhanh.

| Tác vụ | Cách dùng |
|--------|----------|
| Chuyển VN ↔ EN bằng phím tắt | Nhấn + nhả **⌃⇧** (Control + Shift) đồng thời (mặc định) |
| Chuyển VN ↔ EN từ menu | Menu → **"Chuyển đổi ngôn ngữ 🇻🇳 \| 🇺🇸"** |
| Đổi kiểu gõ | Menu → **"Kiểu Telex"** / **"Kiểu VNI"** (✓ ở dòng đang chọn) |
| Bật/tắt nhanh Smart Switch | Menu → **"Smart Switch"** (✓ khi đang bật) — v1.7.0+: master toggle cho cơ chế 3-state per-app (xem tab Smart Switch để cấu hình từng app) |
| Bật/tắt nhanh Sửa lỗi chính tả | Menu → **"Sửa lỗi chính tả"** (✓ khi đang bật) |
| Bật/tắt nhanh Macro (1.5.3+) | Menu → **"Macro"** (✓ khi đang bật) — tạm dừng expansion mà vẫn giữ danh sách |
| Mở cửa sổ Cài đặt | Menu → **"Cài đặt"** |
| Chọn giao diện ứng dụng (1.5.5+) | Menu → **"Giao diện ứng dụng"** → submenu 3 lựa chọn: Mặc định / 3D bóng bẩy / Emoji vui tươi |
| Ủng hộ tác giả | Menu → **"Ủng hộ tác giả"** (quét mã VietQR) |
| Trang dự án trên GitHub | Menu → **"Thông tin dự án"** |
| Kiểm tra cập nhật app thủ công | Menu → **"Kiểm tra cập nhật"** (Sparkle update — khác với nút "Cập nhật từ điển ngay" trong tab Chính tả) |
| Thoát vkey | Menu → **"Thoát"** |

**Trạng thái icon menu bar:**
- 🇻🇳 cờ Việt Nam: đang gõ tiếng Việt
- 🇺🇸 cờ Mỹ: đang gõ tiếng Anh
- 🔒 ổ khoá: đang ở ô password (vkey tự bypass)
- ⚙️ bánh răng có dấu hỏi: chưa cấp quyền Accessibility

### Cài đặt → tab **Chung**

| Mục | Tác dụng |
|-----|---------|
| Bật / Tắt gõ TV | Toggle tổng — bật để gõ tiếng Việt, tắt để gõ thẳng tiếng Anh |
| Tự khởi động cùng hệ thống | Đăng ký vkey vào Login Items macOS |
| Kiểu gõ | Telex / VNI (segmented) |
| Phụ âm `z`, `w`, `j`, `f` | Cho phép coi chúng là phụ âm hợp lệ khi parse âm tiết |
| Tự động sửa lỗi gõ nhầm | Bật/tắt Auto Typo Correction (`thfi → thì`, `dinhjd → định`, `veeitj → việt`, `phuowgn → phương` …) |
| Hiển thị thông báo khi chuyển VI/EN | Bật/tắt Glassmorphic Toggle HUD ở giữa màn hình |
| Kiểu đặt dấu | **Kiểu mới** (thuỷ, khoẻ, hoà, uý) ⟷ **Kiểu cũ** (thủy, khỏe, hòa, úy) |
| Phím tắt | Bấm vào nút → nhập tổ hợp (`⌃⇧Z`) hoặc nhấn-thả modifier (`⌃⇧`) để dùng modifier-only. Backspace để xoá phím tắt, Esc để huỷ |
| Đoán từ tiếp theo (v1.6.1+, default OFF) | Bật để vkey hiển thị HUD dự đoán cạnh caret sau khi gõ xong 1 từ. **Tab** để chấp nhận, phím khác bỏ qua. Ưu tiên gợi ý từ trong từ điển gốc + từ điển cá nhân |
| Lịch sử clipboard (v3.16+, tắt mặc định) | ⌘C lưu vào danh sách; ⌥⌘V chọn mục để dán. ⌘V / ⇧⌘V dán bình thường. Số mục 3–50; chỉ văn bản hoặc văn bản + tệp |

### Cài đặt → tab **Smart Switch**

Tab này được **redesign hoàn toàn ở v1.7.0** — thay list 1-chiều "luôn dùng tiếng Anh" bằng 3-state per app với source tracking + auto-learn.

| Tác vụ | Cách dùng |
|--------|----------|
| Bật/tắt Smart Switch | Toggle ở đầu tab (hoặc nút nhanh ngoài menu bar) |
| Hiểu state mỗi app (v1.7.2+, icon mới v1.7.3+) | Mỗi row có **1 button icon state** (merged badge + picker): 🇻🇳 (Tiếng Việt) / 🇺🇸 (Tiếng Anh) / 🚫 (Không dùng vkey) / 🤖 (Vkey tự quyết — icon mới v1.7.3 thay chip cpu cũ). Tooltip hover hiện nguồn (user/auto) + state |
| Đổi state thủ công | Click button icon → popover **4 options** (🇻🇳/🇺🇸/🚫/🤖). Chọn 1-3 = source=👤 (lock khỏi auto-learn). Chọn 🤖 = xoá entry, vkey tự quyết ngày kế tiếp |
| Thêm app mới (paste) | Nhập Bundle ID → bấm **"Thêm"** (mặc định state = 🇺🇸 EN + source=👤) |
| **Thêm app từ list đang chạy (v1.7.1+)** | Button **"Chọn từ ứng dụng đang chạy"** → sheet hiển thị các app đang mở (filter `activationPolicy == .regular`). Click 1 app để thêm với state mặc định 🇺🇸 EN. Có search field filter theo tên/bundle ID |
| **Xoá app (v1.7.1+)** | Click 🗑 inline trên mỗi row trong list (đỏ, sau button "Sửa"). Xoá ngay, không cần confirm — có thể re-add nếu lỡ |
| Tự học từ Thống kê | Button **"Tự học từ Thống kê"** → sheet preview các app vkey gợi ý đổi state. Áp dụng hàng loạt; entries có 🔒 (user-set) tự skip |
| Lấy Bundle ID thủ công | Mở Terminal: `osascript -e 'id of app "Tên Ứng Dụng"'` (chỉ cần khi app không có trong list đang chạy) |

**Auto-learn rules** (v1.7.2+, chạy **1 lần/ngày** khi launch — đổi từ 1 lần/tuần ở v1.7.0):
- App phải có ≥**1 ngày** dataset (giảm từ ≥5 ở v1.7.1)
- ≥5 commit/ngày trung bình
- Ratio ngôn ngữ ≥75% → set state tương ứng (Tiếng Việt hoặc Tiếng Anh)
- Entries có source=👤 (user) KHÔNG bị thay đổi
- User upgrade từ 1.6.x: smartSwitchApps cũ tự convert thành configs 3-state (englishMode + source=👤)
- Reset 1 app về auto-learn: click button icon → chọn 🤖 "Để vkey tự quyết" → entry bị xoá, ngày kế tiếp auto-learn re-evaluate

### Cài đặt → tab **Macro**

| Tác vụ | Cách dùng |
|--------|----------|
| Bật/Tắt Macro (mới 1.5.3) | Toggle đầu tab (hoặc nút nhanh trên menu bar) — khi tắt, danh sách vẫn giữ nhưng macro tạm dừng |
| Thêm macro mới | Bấm **"Thêm"** → điền cột "Viết tắt" và "Cụm dài" |
| Xoá macro | Chọn dòng → bấm **"Xoá"** |
| Xuất macro ra JSON | Bấm **"Xuất"** — lưu file JSON để chia sẻ giữa máy |
| Nhập macro từ JSON | Bấm **"Nhập"** — gộp vào danh sách hiện tại, bỏ qua trùng |
| Kích hoạt khi gõ | Gõ phần "Viết tắt" rồi nhấn **Space** hoặc **dấu câu**, vkey thay bằng "Cụm dài" |
| Macro mặc định (1.5.3+) | Lần đầu mở app sau cập nhật: 19 macro văn phòng VN có sẵn (`vn`, `tv`, `kg` (Kính gửi), `bcao`, `cty`, `gd`, `sdt`, …). Tự xoá / sửa thoải mái. |
| Gợi ý từ Thống kê (1.5.5+, mở rộng v1.6.1+) | Hiển thị các từ và cụm 2-3 từ tiếng Việt gõ ≥10 lần chưa có macro. Bấm "Xem & thêm" → sheet auto-suggest viết tắt (vd "công ty → ct", "kính gửi anh → kga") + edit + add |

### Cài đặt → tab **Chính tả**

Tab này được **tinh gọn liên tục qua các version**:
- **v1.5.3**: bỏ Picker "Nguồn từ điển" + Toggle "Tự động tải từ GitHub" (đều luôn-on).
- **v1.6.1**: chuyển toggle "Đoán từ tiếp theo" sang tab Chung.
- **v1.6.2**: thêm Section "Từ điển từ GitHub" với nút cập nhật thủ công.
- **v1.7.0**: gộp 3 Section → 1 Section đổi tên **"Cấu hình kiểm tra chính tả"**. Còn 5 Section thay vì 7.
- **v1.7.1**: gộp "Gợi ý sửa lỗi chính tả" + "Tự động sửa khi tin cậy cao" vào CÙNG Section "Cấu hình kiểm tra chính tả". Còn **4 Section** thay vì 5.
- **v1.7.10**: section "Từ điển từ GitHub" hiển thị riêng 2 dòng VN + EN count.
- **v1.7.11**: nút "Quản lý từ điển cá nhân" đổi tên thành **"Sửa từ điển cá nhân"** + thêm nút **"Gửi cho tác giả"** song song.

4 Section hiện tại (v1.7.11):

1. **Phím tắt thông minh** — Master quick-enable toggle gộp.
2. **Cấu hình kiểm tra chính tả** — gồm:
   - Toggle "Kiểm tra chính tả" (gộp luôn "Kiểm tra trong câu" từ v1.7.0)
   - Toggle "Gợi ý sửa lỗi chính tả" + sub-toggle "Tự động sửa khi tin cậy cao"
   - Toggle "Sử dụng từ điển cá nhân" + 2 button: **"Sửa từ điển cá nhân"** + **"Gửi cho tác giả"** (v1.7.11)
   - Toggle "Tự động compute đề xuất hàng tuần" + button "Xem đề xuất pending"
3. **Tự động khôi phục tiếng Anh (Space Restore)** — `englishAutoRestoreEnabled` + restorePolicy + `useEnVnReference`.
4. **Từ điển từ GitHub** — 2 dòng version + count cho VN + EN, nút "Cập nhật từ điển ngay".

| Mục | Tác dụng |
|-----|---------|
| Kích hoạt nhanh tất cả tính năng mới | Toggle gộp — bật/tắt cùng lúc mọi tính năng chính tả + từ điển bên dưới |
| Kiểm tra chính tả (v1.7.0 gộp "trong câu") | Bật cơ chế 6-bước check + Vowel Inclusion Pairs (chặn gõ dấu sai cấu trúc âm tiết) cho cả từ vừa gõ và từ trong câu |
| Sử dụng từ điển cá nhân | Bật danh sách Allow / Keep / Deny do bạn tự định nghĩa |
| Sửa từ điển cá nhân (v1.7.11 đổi tên từ "Quản lý") | Mở editor → thêm / xoá từ trong 3 danh sách Allow / Keep / Deny. **v3.4+**: nút **Nhập file / Xuất file** — nhập danh sách từ `.txt` (mỗi dòng 1 từ) hoặc `.csv` (tách theo dấu phẩy), tự dò bảng mã, lọc trùng, báo số từ thêm mới; xuất tab hiện tại ra `.txt` |
| Gửi cho tác giả (v1.7.11 đưa ra ngoài) | Mở mail compose tới tuanlong.sav@gmail.com với 3 lists. Gate ≥50 từ tổng Allow+Keep+Deny |
| Tự động compute đề xuất hàng tuần (v1.6.0+) | Auto-compute đề xuất từ Thống kê tuần này. KHÔNG còn auto-promote ngầm — chỉ tạo danh sách để bạn review |
| Xem đề xuất pending (v1.6.0+) | Mở sheet review từng từ ≥5 lần gõ thống nhất → chọn ✓ thêm vào Allow/Keep hoặc bỏ qua |
| Gợi ý sửa lỗi chính tả | Hiện gợi ý khi gõ sai (Levenshtein + heuristic) |
| Tự động sửa khi tin cậy cao | Áp dụng gợi ý luôn nếu độ tin cậy ≥ 88% |
| Tự động khôi phục tiếng Anh | Bật Space Restore (`ò → of`, `ì → if`, `sê → see`, `tê → tee`…) |
| Chính sách khôi phục | **Ưu tiên tiếng Việt** / **Cân bằng** / **Ưu tiên tiếng Anh** cho từ mơ hồ |
| Dùng từ điển tham chiếu Anh-Việt | Bật bộ từ điển song ngữ Anh ↔ Việt nhúng trong package (mới ở 1.5.0). Hiện đang trống — sẽ được populate ở phiên bản tới khi build pipeline cập nhật |
| **Từ điển từ GitHub** (v1.6.2+, EN count v1.7.10+) | Hiển thị riêng 2 dòng: "Tiếng Việt: vX · N từ" + "Tiếng Anh: vX · N từ". Nút "Cập nhật từ điển ngay" để force-download bypass throttle 24h |

### Cài đặt → tab **Thống kê & Sao lưu**

Header tuần này (v1.7.0+) hiển thị tiếng Việt: **"Tuần 21 năm 2026 (từ 18/05 đến 24/05/2026)"** thay cho format ISO "2026-W21" — tính từ thứ Hai đến Chủ Nhật.

**Bố cục mới (v1.7.9+)**: Sao lưu → Personal Dict sync → **Quyền riêng tư** (chuyển xuống sát các mục thống kê) → Tuần hiện tại → Top từ tiếng Việt → **Top cụm 2-3 từ tiếng Việt** → Top từ ngoài tiếng Việt → **Top cụm ngoài tiếng Việt** → Top app → Các tuần đã đóng → Chẩn đoán.

| Mục | Tác dụng |
|-----|---------|
| Ghi nhận thống kê sử dụng | Bật/tắt log cục bộ (`~/Library/Application Support/vkey/stats/`) |
| Tự động hỏi sao lưu khi cập nhật app | Hiện prompt xuất JSON trước khi app chạy phiên bản mới |
| Xuất dữ liệu cá nhân | Lưu JSON gồm Cài đặt + Macro + từ điển cá nhân + Smart Switch + per-app + thống kê |
| Nhập từ tệp sao lưu (semantics đúng v1.7.7+) | 2 chế độ: **"Gộp thêm (file thắng nếu trùng)"** = giữ data hiện tại + thêm imported, duplicate → imported wins. **"Ghi đè toàn bộ (xoá data hiện tại)"** = clear sạch defaults + replace bằng imported (kèm clearAll stats). v1.7.6+ export lossless full state (9 fields trước đây thiếu + WeekBucket raw frequency tables) |
| Chạy compute đề xuất ngay (v1.6.0+) | Compute đề xuất từ Thống kê tuần này (không auto-write) |
| Xem đề xuất (v1.6.0+) | Review danh sách pending suggestions → chốt thêm vào Allow/Keep |
| Xoá toàn bộ dữ liệu thống kê | Reset cả tuần này lẫn các tuần đã đóng |
| Top từ tiếng Việt / app (tuần này) | Mỗi row có 🗑 để xoá entry cụ thể khỏi current week (giữ history). v1.7.4 đổi cap 20 → top 10% theo count + filter display |
| **Top cụm 2-3 từ tiếng Việt** (v1.7.9+) | Section mới — dùng API `aggregatedTopVietnamesePhrases` (data từ v1.6.1 nhưng UI mới v1.7.9). Giúp xác định cụm thường gõ để tạo macro |
| **Top từ ngoài tiếng Việt (gợi ý từ điển cá nhân)** (v1.7.9+, filter nới v1.7.10+) | Đổi tên từ "Top từ tiếng Anh / ký tự đặc biệt". Filter chỉ length≥2 + ngoài deny — hiện cả raw text ("hopwj") + ký tự lạ ("lol", "okay") để dễ thấy candidate add Personal Dict |
| **Top cụm ngoài tiếng Việt** (v1.7.9+) | Section mới — backend `enPhraseCounts2/3` track khi commit `.restoreRawEnglish`/`.keepRaw` liền nhau |
| **Các tuần đã đóng** (v1.6.1+) | Hiển thị tóm tắt 4 tuần lịch sử gần nhất — đảm bảo data tuần cũ không "biến mất" sau khi tuần ISO chuyển |
| **Xuất chẩn đoán Stats** (v1.6.1+) | Ghi file `~/Desktop/vkey-stats-diagnostic.txt` mô tả tình trạng files + counters để gửi khi báo lỗi |

### Phím gõ đặc biệt khi đang gõ

| Phím | Tác dụng |
|------|---------|
| **Space** sau từ tiếng Anh bị gõ nhầm | Tự khôi phục về tiếng Anh (Space Restore) |
| **Esc** giữa chừng | Hoàn tác về phím thô ban đầu, reset bộ đệm |
| **Tab** khi HUD đoán từ đang hiện (v1.6.0+, smart-detect v1.7.7+) | Chấp nhận prediction. **Buffer sạch** (sau Space commit) → chèn `" prediction"` (leading space). **Buffer có từ chưa commit** → Tab commit từ + chèn prediction trong 1 phím. Bất kỳ phím khác → bỏ qua HUD và tiếp tục gõ |
| Gõ đúp `ss`, `ff`, `rr`, `xx`, `jj` | Giữ nguyên đúp (không bị toggle dấu) — cho từ tiếng Anh như `staff`, `off`, `class`, `pass` |
| Click chuột vào ô khác giữa từ | Reset bộ đệm sạch sẽ — không dính chữ qua ô khác |

## FAQ

**1. Có an toàn không?**
Mã nguồn mở GPL v3, bạn tự build hoặc đọc code trước khi tin. App không gửi dữ liệu đi đâu, không telemetry.

**2. Tại sao phải cấp quyền Accessibility?**
vkey nghe keyboard system-wide (qua `CGEvent.tapCreate`) để chuyển ký tự bạn gõ thành tiếng Việt. Đây là quyền chuẩn cho mọi bộ gõ "hàng chế" trên macOS (OpenKey, EVKey, GoTiengViet cũng vậy). Apple's official IME thì dùng cơ chế khác (Input Method Kit) nhưng có nhược điểm gạch chân + bug khi click sang ô khác giữa từ.

**3. Sao chỉ nhận Telex và VNI?**
Triết lý "đơn giản nhất". Hai kiểu này phủ ~95% người dùng VN. Không có bảng setting to đùng như OpenKey/EVKey.

**4. Bản DMG có notarized không?**
Không. Đây là dự án cá nhân, không có Apple Developer ID. Bạn tin tưởng → right-click Open. Không tin → build lại từ source.

## Giấy phép & Bản quyền

vkey kế thừa giấy phép **GNU General Public License v3.0** từ Caffee. Xem file [`LICENSE`](LICENSE).

Điều này có nghĩa:
- Bạn **được** sao chép, sửa, phân phối lại.
- Bản phân phối lại của bạn **bắt buộc** cũng phải mở mã nguồn dưới GPL v3 (copyleft).
- Không được phép đóng nguồn và bán thương mại độc quyền.

### Ghi công (Credit & Attribution)

vkey là một sản phẩm nguồn mở phát triển vì cộng đồng, kế thừa và học hỏi các giải pháp xuất sắc từ các tác giả đi trước:
- **[Caffee](https://github.com/khanhicetea/Caffee)** © Khanh Nguyen ([@khanhicetea](https://github.com/khanhicetea)) — Đóng góp toàn bộ engine xử lý tiếng Việt ban đầu + kiến trúc lõi của bộ gõ.
- **[XKey](https://github.com/xmannv/xkey)** © Xuan Manh Nguyen ([@xmannv](https://github.com/xmannv)) — Đóng góp các ý tưởng sáng tạo và giải pháp kỹ thuật xuất sắc bao gồm giao diện mờ kính **Translucent Toggle HUD**, giải pháp AX Probing Smart Switch và bộ lọc phụ âm **Impossible Consonant Clusters**.
- **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** © Phan Anh Kha ([@khaphanspace](https://github.com/khaphanspace)) — Đóng góp thuật toán kiểm tra chính tả 6 bước, ma trận Vowel Inclusion Pairs, Space Restore, Escape Reversion và Doubled Tone Mark Preservation xuất sắc giúp hoàn thiện tối đa trải nghiệm gõ song ngữ Anh-Việt.
- **vkey** © 2026 longht ([@tuanlongsav](https://github.com/tuanlongsav)) — các tính năng mở rộng và hoàn thiện hệ thống.

Mỗi file source vẫn giữ header gốc của tác giả Caffee khi có. Vui lòng tôn trọng attribution khi tiếp tục fork.

### Nguồn dữ liệu từ điển (bổ sung từ v1.5.0)

vkey tích hợp dữ liệu từ điển song ngữ Anh-Việt từ các nguồn mở sau, tuân thủ đầy đủ điều khoản license của từng nguồn:

- **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** © Luông Hiếu Thi ([@hieuthi](https://github.com/hieuthi)) — baseline **7,184 âm tiết tiếng Việt** curated. Tích hợp từ **v1.5.0**.
- **[undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary)** © Vũ Anh ([@undertheseanlp](https://github.com/undertheseanlp)), **GPL-3.0** — tổng hợp từ Hồ Ngọc Đức + tudientv + Wiktionary VN. vkey extract syllables qua audit + phonotactic filter (3-tier classification A/B/C), bổ sung **+1,710 syllables** (v1.6.1 lexicon v6 → v1.6.3 lexicon v7). Tích hợp từ **v1.6.1**.
- **English Wiktionary** qua **[Wiktextract](https://github.com/tatuylonen/wiktextract)** + **[Kaikki.org](https://kaikki.org)** — Dữ liệu cặp từ Anh↔Việt (`en_vn_mapping`). Phân phối lại theo **CC BY-SA 4.0**. Tích hợp từ **v1.5.0**.
- **[wordfreq](https://github.com/rspeer/wordfreq)** © Robyn Speer — Bảng tần suất từ tiếng Anh để chọn lọc `english[]`. MIT license cho tool, CC BY-SA 4.0 cho phần data nguồn Wiktionary.

Tổng `vietnamese[]` hiện tại (v8 — v1.7.1+): **8,960 syllables** đã chuẩn hoá NFC + audit, bao gồm 66 single-char Vietnamese diacritics (`à`, `á`, `ý`, `ô`, `ở`...) đã restore ở v1.7.1 sau khi bị drop nhầm v7. Dữ liệu phái sinh nằm trong [`lexicon-update.json`](lexicon-update.json) (commit lên repo, app fetch qua `raw.githubusercontent.com`) và được phát hành lại theo **CC BY-SA 4.0** (data) song song với **GPL-3.0** (code). Xem chi tiết tại [`LICENSE-DATA.md`](LICENSE-DATA.md).

### Tooling build/maintain lexicon

| Script | Mục đích |
|--------|---------|
| [`Tools/build_lexicon.py`](Tools/build_lexicon.py) | Build lexicon-update.json từ scratch (Wiktionary + wordfreq + curated seed). Yêu cầu `pip install wordfreq requests` |
| [`Tools/build_underthesea_package.py`](Tools/build_underthesea_package.py) (v1.6.1+) | Merge thô single-token từ undertheseanlp/dictionary vào package |
| [`Tools/audit_lexicon.py`](Tools/audit_lexicon.py) (v1.6.1+) | Audit cleanup — loại single-char + ASCII-only no-VN-marker noise |
| [`Tools/merge_underthesea_deep.py`](Tools/merge_underthesea_deep.py) (v1.6.3+) | Deep merge từ multi-word phrases với 3-tier classification + phonotactic filter |
| [`Tools/validate_appcast.sh`](Tools/validate_appcast.sh) | Validate XML format của appcast.xml trước khi push release |
| [`Tools/sparkle_sign_update.sh`](Tools/sparkle_sign_update.sh) | Ký Sparkle EdDSA signature cho DMG release |

### Lưu ý về tên gọi

Tên "vkey" được chọn ngắn gọn, **không liên quan** đến các sản phẩm thương mại / dịch vụ đã đăng ký bảo hộ tại Việt Nam (vd các sản phẩm chữ ký số / bảo mật có chữ "VKey"). Đây là phần mềm phi thương mại, không thay thế / cạnh tranh với sản phẩm đăng ký thương hiệu nào.

### Engine xử lý tiếng Việt

vkey **không** sử dụng mã nguồn từ UniKey (Phạm Kim Long), EVKey hay OpenKey. Engine `Engine/TiengViet*.swift` là của Caffee, được viết lại độc lập từ đầu bằng Swift theo lý thuyết âm tiết học tiếng Việt — xem chi tiết trong [app-arch.md](app-arch.md).
