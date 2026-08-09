<h1>
  <img src="images/vkey-icon.png?v=32000" alt="vkey logo" width="56" style="vertical-align: middle;">
  &nbsp;vkey
</h1>

Bộ gõ tiếng Việt native cho macOS — app menu bar nhỏ gọn, Telex & VNI, macOS 14+.

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Data: CC BY-SA 4.0](https://img.shields.io/badge/Data-CC%20BY--SA%204.0-orange.svg)

**Phiên bản hiện tại: [4.22](CHANGELOG.md)** — app & DMG đều Developer ID signed + notarized · 349 test pass · [Tải bản mới nhất](../../releases/latest)

## Mới ở v4.22

- **Hết gãy chữ trong hộp thoại Lưu** — gõ tên thư mục trong hộp thoại Lưu của Safari (và các app sandbox khác), `Haf Nooij` giờ ra `Hà Nội` ngay từ chữ đầu, không phải bỏ ký tự nào.
- **`Nội` không còn thành `Nôị`** — dấu nặng vốn không đặt sai, mà từ bị cắt đôi giữa chừng. Nguyên nhân: hộp thoại Lưu chạy ở tiến trình phụ, hệ thống trả về bundle đổi qua lại từng phím khiến vkey tưởng bạn liên tục chuyển app và xoá từ đang gõ.

Lịch sử đầy đủ các phiên bản trước: [CHANGELOG.md](CHANGELOG.md)

## Hình ảnh

<p align="center">
  <img src="images/menubar-menu.png?v=32000" width="200" alt="Menu bar">
  <img src="images/hud-toggle-vi.png?v=32000" width="300" alt="HUD VI/EN">
  <img src="images/hud-prediction.png?v=32000" width="220" alt="HUD gợi ý cụm">
</p>

<p align="center">
  <img src="images/general-settings.png?v=32000" width="200" alt="Tab Chung">
  <img src="images/smart-switch-settings.png?v=32000" width="200" alt="Tab Smart Switch">
  <img src="images/macro-settings.png?v=32000" width="200" alt="Tab Macro">
  <img src="images/spellcheck-settings.png?v=32000" width="200" alt="Tab Chính tả">
  <img src="images/statistics-settings.png?v=32000" width="200" alt="Tab Thống kê">
  <img src="images/theme-settings.png?v=32000" width="200" alt="Tab Giao diện">
</p>

## Tính năng chính

| Nhóm | Điểm nổi bật |
|------|----------------|
| **Gõ** | Telex & VNI · kiểu đặt dấu mới/cũ (`oà` ↔ `òa`) · **Đặt dấu tự do** (bỏ kiểm tra âm tiết) · tự động sửa lỗi gõ nhầm · viết hoa đầu câu · phụ âm vay mượn z/w/j/f · Unicode UTF-8 · keypad VNI & Caps Lock chuẩn macOS |
| **Song ngữ** | Space Restore · Esc hoàn tác về phím thô · gõ tiếng Anh ổn định trong mode VN · nhớ VI/EN theo từng app |
| **Smart Switch** | 3 trạng thái mỗi app: 🇻🇳 Tiếng Việt · 🇺🇸 Tiếng Anh · ⛔ Không sử dụng vkey · tự học từ Thống kê · thêm nhanh từ danh sách app đang chạy |
| **Chính tả** | Kiểm tra chính tả lúc kết từ, **chính sách khôi phục** chọn được (vd Cân bằng) · tự động sửa khi tin cậy cao · từ điển tham chiếu Anh–Việt · từ điển cá nhân (giữ tiếng Việt / khôi phục tiếng Anh) · cập nhật từ điển từ GitHub |
| **Từ điển** | Nhúng sẵn **7 184 âm tiết tiếng Việt**; sau khi nhận gói cập nhật từ GitHub (app tự tải im lặng lúc khởi động, tối đa 1 lần/24h): **8 928 âm tiết + 9 826 từ tiếng Anh + 3 039 cặp Anh–Việt** |
| **Gợi ý & macro** | Đoán từ 6 tầng (trigram/bigram người dùng + corpus nhúng + cụm nhúng) · gợi ý **1–3 từ**, mặc định 2 · `Tab` để chèn · loại trừ app khỏi đoán từ · macro viết tắt → cụm dài, nhập/xuất JSON |
| **Thống kê** | Top từ/cụm tuần · top cụm 2–3 từ tiếng Việt & ngoài tiếng Việt · top app dùng nhiều · các tuần đã đóng · sao lưu/khôi phục JSON · quản lý & xóa cụm |
| **Giao diện** | Menu bar panel · Cài đặt sidebar 6 tab · 3 theme: **Mặc định** / **Liquid Glass** / **Neural AI** · màu nhấn · phông chữ · độ bo góc · mật độ dòng · Sáng / Tối / Hệ thống |
| **HUD** | Capsule VI/EN giữa màn hình · pill gợi ý `→ cụm · Tab` (chỉnh được cỡ chữ + khoảng cách tới con trỏ) · cảnh báo clipboard amber |
| **Tiện ích** | Lịch sử clipboard (⇧⌘V mở menu, tùy chỉnh phím tắt — **mặc định TẮT**) · tự động cập nhật im lặng qua Sparkle, dialog tiếng Việt · tự khởi động cùng hệ thống · tự tắt khi đổi sang bộ gõ khác · Text Tools ⌃⇧ · VietQR donate |
| **Tương thích** | Chrome omnibox (axDirect) · Electron/Office/terminal · QWERTZ/AZERTY/Dvorak · bypass ô password (secure input) |

Dữ liệu thống kê & từ điển cá nhân **chỉ lưu cục bộ** — không telemetry.

## Cài đặt

1. Tải `vkey-x.y.dmg` từ [Releases](../../releases/latest) → kéo vào `Applications`.
2. **System Settings → Privacy & Security → Accessibility** → bật `vkey`.
3. Tắt rồi mở lại app lần đầu.

> Từ v3.5 app được **ký Developer ID & notarized** — kéo ra `Applications` rồi mở bình thường, không cần chuột phải → Mở. Nâng cấp từ bản ≤3.4 có thể phải cấp lại quyền Trợ năng **một lần**.
>
> Từ **v4.18** chính file `.dmg` cũng được ký + notarize nên mở thẳng được. Với bản **≤ 4.17**, bước mở dmg có thể hiện cảnh báo "Apple could not verify…" — chuột phải → Open, hoặc System Settings → Privacy & Security → Open Anyway.

<details>
<summary>Build từ source</summary>

Yêu cầu macOS 14+, Xcode 15.3+.

```bash
git clone https://github.com/tuanlongsav/vkey.git
cd vkey
xcodebuild -project vkey.xcodeproj -scheme vkey \
  -configuration Release -derivedDataPath /tmp/vkey-release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO clean build
ditto /tmp/vkey-release/Build/Products/Release/vkey.app /Applications/vkey.app
```

</details>

## Sử dụng nhanh

### Menu bar

Click cờ 🇻🇳/🇺🇸 trên menu bar.

| Thao tác | Cách dùng |
|----------|-----------|
| Chuyển VI ↔ EN | Nhấn + nhả **⇧⌥** (mặc định) hoặc segmented **VI \| EN** trên panel |
| Kiểu gõ | **Kiểu Telex** / **Kiểu VNI** |
| Bật/tắt nhanh | Smart Switch · Macro · Lịch sử Clipboard |
| Cài đặt | **Cài đặt** (⌘,) |
| Đổi theme | **Chuyển giao diện** → Mặc định / Liquid Glass / Neural AI |
| Hàng cuối panel | ☕ Ủng hộ tác giả · ℹ️ Thông tin dự án · 🔄 **Kiểm tra cập nhật** (cập nhật thủ công) · số phiên bản |
| Thoát | **Thoát** (⌘Q) |

**Icon menu bar:** 🇻🇳 gõ VN · 🇺🇸 gõ EN · 🔒 ô password · ⚙️ chưa cấp quyền Trợ năng

### Cài đặt — 6 tab

| Tab | Nội dung chính |
|-----|----------------|
| **Chung** | Cập nhật ứng dụng (tự động cập nhật phiên bản mới) · Bộ gõ (bật/tắt gõ tiếng Việt, tự khởi động cùng hệ thống, Telex/VNI, phụ âm z w j f) · Hỗ trợ thông minh (tự động sửa lỗi gõ nhầm, viết hoa đầu câu, tự tắt khi đổi sang bộ gõ khác, thông báo khi chuyển VI/EN) · Cấu hình nâng cao (Đặt dấu tự do, kiểu đặt dấu cũ/mới) · Phím tắt chuyển chế độ (⇧⌥) và mở Text Tools (⌃⇧) · Clipboard tùy chỉnh (⇧⌘V, số mục, loại nội dung, dung lượng mỗi mục, xóa lịch sử) |
| **Smart Switch** | Danh sách ứng dụng với 3 lựa chọn: 🇻🇳 Tiếng Việt · 🇺🇸 Tiếng Anh · Không sử dụng vkey · Tự học từ Thống kê · chọn nhanh từ ứng dụng đang chạy |
| **Macro** | Bật/tắt Macro · viết tắt → cụm dài · danh sách macro · nhập/xuất `vkey-macros.json` · gợi ý từ thường gõ |
| **Chính tả** | Kiểm tra chính tả · gợi ý sửa lỗi chính tả · tự động sửa khi tin cậy cao · từ điển cá nhân + tự động đề xuất hàng tuần · đoán từ tiếp theo (số từ gợi ý, cỡ chữ / độ đậm / khoảng cách HUD tới con trỏ) · loại trừ app khỏi đoán từ · Space Restore + chính sách khôi phục (vd Cân bằng) · dùng từ điển tham chiếu Anh–Việt |
| **Thống kê & Sao lưu** | Ghi nhận thống kê sử dụng · top từ / cụm 2–3 từ tiếng Việt & ngoài tiếng Việt · top app dùng nhiều · Smart Switch kích hoạt · các tuần đã đóng · sao lưu/khôi phục JSON (kèm tự động hỏi sao lưu khi cập nhật app) · đồng bộ hành vi vào từ điển cá nhân + đề xuất bổ sung từ điển · quyền riêng tư & chẩn đoán |
| **Quản lý giao diện** | Theme (Mặc định / Liquid Glass / Neural AI) · màu nhấn · phông chữ · độ bo góc · mật độ dòng menu · cường độ phát sáng (Neural AI) |

Nút **Sáng / Tối / Hệ thống** nằm trên thanh tiêu đề cửa sổ Cài đặt, không nằm trong tab.

### Phím đặc biệt khi gõ

| Phím | Tác dụng |
|------|----------|
| **Space** | Khôi phục từ tiếng Anh bị gõ nhầm (Space Restore) |
| **Esc** | Hoàn tác về phím thô, reset buffer |
| **Tab** | Chấp nhận gợi ý HUD (1–3 từ, mặc định 2). Gợi ý sinh ra sau mỗi lần kết từ bằng Space và còn hiệu lực cả khi bạn đã gõ dở từ kế — lúc đó Tab kết từ đang gõ rồi mới chèn gợi ý. Enter / click / dời con trỏ sẽ huỷ gợi ý, Tab trả về hành vi gốc |
| **ss/ff/rr/xx/jj** | Giữ phím đúp cho từ tiếng Anh (`staff`, `off`…) |

## FAQ

**Có an toàn không?** Mã nguồn mở GPL v3. Không gửi dữ liệu đi đâu.

**Tại sao cần quyền Accessibility?** vkey bắt phím toàn hệ thống (CGEvent tap) để transform ký tự — giống OpenKey/EVKey.

**Khác UniKey/OpenKey?** Engine Swift độc lập (fork [Caffee](https://github.com/khanhicetea/Caffee)), không dùng code UniKey/EVKey. Chỉ Telex + VNI, triết lý tối giản.

**DMG có notarized không?** Có — app bên trong từ v3.5, và chính file DMG từ v4.18. Bản ≤ 4.17 mở DMG có thể gặp cảnh báo Gatekeeper một lần (xem mục [Cài đặt](#cài-đặt)).

## Nguồn gốc & giấy phép

Fork mở rộng từ **[Caffee](https://github.com/khanhicetea/Caffee)**; học hỏi thêm từ **[XKey](https://github.com/xmannv/xkey)** và **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)**. Từ điển: [common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable), [undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary), Wiktionary/wordfreq — chi tiết [LICENSE-DATA.md](LICENSE-DATA.md).

**Giấy phép:** [GPL v3](LICENSE) (code) · CC BY-SA 4.0 (dữ liệu từ điển phái sinh).

Kiến trúc kỹ thuật: [app-arch.md](app-arch.md) · Release: [RELEASE.md](RELEASE.md)
