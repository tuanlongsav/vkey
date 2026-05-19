# vkey Changelog

> **Lưu ý về Bản quyền và Đóng góp (Credits & Attribution)**: Kể từ phiên bản v1.3.9, v1.4.0, v1.4.1, v1.4.2, v1.4.3, v1.4.4, v1.4.5 và v1.4.6, vkey đã học tập, cải tiến và tích hợp các ý tưởng thiết kế, giải pháp kỹ thuật xuất sắc từ các dự án mã nguồn mở **[Caffee](https://github.com/khanhicetea/Caffee)** của tác giả KhanhIceTea, **[XKey](https://github.com/xmannv/xkey)** của tác giả Xuan Manh Nguyen (@xmannv), **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)** của tác giả Khaphan, và tích hợp bộ cơ sở dữ liệu từ điển 7.184 âm tiết tiếng Việt chuẩn từ dự án mã nguồn mở **[common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable)** của tác giả Luông Hiếu Thi (@hieuthi) để mang lại trải nghiệm tối ưu nhất cho người dùng.

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
