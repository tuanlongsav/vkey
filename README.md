<h1>
  <img src="images/vkey-icon.png?v=32100" alt="vkey logo" width="56" style="vertical-align: middle;">
  &nbsp;vkey
</h1>

Bộ gõ tiếng Việt native cho macOS — app menu bar nhỏ gọn, Telex & VNI, macOS 14+.

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Data: CC BY-SA 4.0](https://img.shields.io/badge/Data-CC%20BY--SA%204.0-orange.svg)

**Phiên bản hiện tại: [3.21](CHANGELOG.md)** — Developer ID signed & notarized · 263 test pass · [Tải bản mới nhất](../../releases/latest)

## Mới ở v3.21

- **Đoán từ — loại trừ app** — tab Chính tả: chọn app không chạy HUD gợi ý (IDE, terminal, v.v.).
- **Lịch sử Clipboard trên menu bar** — bật/tắt nhanh cùng Smart Switch / Chính tả / Macro.

## Mới ở v3.20

- **Quản lý & xóa cụm thống kê** — sheet chi tiết cho top cụm VN / ngoài VN; xóa đúng bucket phrase; xóa từ EN thêm deny list.
- **Icon cài đặt sắc nét** — sidebar/nav không còn mờ trên theme Glass & Neural.

Lịch sử đầy đủ các phiên bản trước: [CHANGELOG.md](CHANGELOG.md)

## Hình ảnh

<p align="center">
  <img src="images/menubar-menu.png?v=32100" width="200" alt="Menu bar">
  <img src="images/hud-toggle-vi.png?v=32100" width="300" alt="HUD VI/EN">
  <img src="images/hud-prediction.png?v=32100" width="220" alt="HUD gợi ý cụm">
</p>

<p align="center">
  <img src="images/general-settings.png?v=32100" width="200" alt="Tab Chung">
  <img src="images/smart-switch-settings.png?v=32100" width="200" alt="Tab Smart Switch">
  <img src="images/macro-settings.png?v=32100" width="200" alt="Tab Macro">
  <img src="images/spellcheck-settings.png?v=32100" width="200" alt="Tab Chính tả">
  <img src="images/statistics-settings.png?v=32100" width="200" alt="Tab Thống kê">
  <img src="images/theme-settings.png?v=32100" width="200" alt="Tab Giao diện">
</p>

## Tính năng chính

| Nhóm | Điểm nổi bật |
|------|----------------|
| **Gõ** | Telex & VNI · kiểu đặt dấu mới/cũ · auto sửa gõ nhầm · Unicode UTF-8 · keypad VNI & Caps Lock chuẩn macOS |
| **Song ngữ** | Space Restore · ESC hoàn tác · gõ tiếng Anh ổn định trong mode VN · nhớ VI/EN theo từng app |
| **Smart Switch** | 3 trạng thái/app: 🇻🇳 VN · 🇺🇸 EN · ⛔ tắt · tự học từ thống kê · Spotlight/Raycast/Alfred |
| **Chính tả** | Kiểm tra 6 bước · từ điển VN 8 960 âm tiết + EN 9 826 từ · từ điển cá nhân · cập nhật từ GitHub |
| **Gợi ý & macro** | HUD gợi ý cụm 2–3 từ (`Tab` chèn) · macro viết tắt · đề xuất từ thống kê |
| **Thống kê** | Top từ/cụm tuần này · sao lưu/khôi phục JSON · quản lý & xóa cụm (v3.20) |
| **Giao diện** | Menu bar panel · Cài đặt sidebar 6 tab · 3 theme: **Tonal** / **Liquid Glass** / **Neural AI** |
| **HUD** | Capsule VI/EN giữa màn hình · pill gợi ý `→ cụm · Tab` · cảnh báo clipboard amber |
| **Tiện ích** | Lịch sử clipboard (toggle menu bar) · Text Tools ⌃⇧ · cập nhật Sparkle · VietQR donate |
| **Tương thích** | Chrome omnibox (axDirect) · Electron/Office/terminal · QWERTZ/AZERTY/Dvorak · bypass ô password |

Dữ liệu thống kê & từ điển cá nhân **chỉ lưu cục bộ** — không telemetry.

## Cài đặt

1. Tải `vkey-x.y.dmg` từ [Releases](../../releases/latest) → kéo vào `Applications`.
2. **System Settings → Privacy & Security → Accessibility** → bật `vkey`.
3. Tắt rồi mở lại app lần đầu.

> Từ v3.5 app được **ký Developer ID & notarized** — mở bình thường, không cần chuột phải → Mở. Nâng cấp từ bản ≤3.4 có thể phải cấp lại quyền Trợ năng **một lần**.

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
| Bật/tắt nhanh | Smart Switch · Sửa lỗi chính tả · Macro · Lịch sử Clipboard |
| Cài đặt | **Cài đặt** (⌘,) |
| Đổi theme | **Chuyển giao diện** → Tonal / Liquid Glass / Neural AI |
| Thoát | **Thoát** (⌘Q) |

**Icon menu bar:** 🇻🇳 gõ VN · 🇺🇸 gõ EN · 🔒 ô password · ⚙️ chưa cấp quyền Trợ năng

### Cài đặt — 6 tab

| Tab | Nội dung chính |
|-----|----------------|
| **Chung** | Bật/tắt gõ VN · Telex/VNI · auto sửa lỗi · HUD · phím tắt · clipboard |
| **Smart Switch** | Cấu hình VI/EN/tắt theo app · thêm app đang chạy · tự học từ thống kê |
| **Macro** | Viết tắt → cụm dài · nhập/xuất JSON · gợi ý từ thống kê |
| **Chính tả** | Spell check · từ điển cá nhân · đoán từ (loại trừ app) · Space Restore · cập nhật lexicon GitHub |
| **Thống kê & Sao lưu** | Top từ/cụm tuần · xuất/nhập JSON · quản lý/xóa cụm |
| **Quản lý giao diện** | Theme · màu nhấn · font · bo góc · sáng/tối |

### Phím đặc biệt khi gõ

| Phím | Tác dụng |
|------|----------|
| **Space** | Khôi phục từ tiếng Anh bị gõ nhầm (Space Restore) |
| **Esc** | Hoàn tác về phím thô, reset buffer |
| **Tab** | Chấp nhận gợi ý HUD (từ hoặc cụm 2–3 từ) |
| **ss/ff/rr/xx/jj** | Giữ phím đúp cho từ tiếng Anh (`staff`, `off`…) |

## FAQ

**Có an toàn không?** Mã nguồn mở GPL v3. Không gửi dữ liệu đi đâu.

**Tại sao cần quyền Accessibility?** vkey bắt phím toàn hệ thống (CGEvent tap) để transform ký tự — giống OpenKey/EVKey.

**Khác UniKey/OpenKey?** Engine Swift độc lập (fork [Caffee](https://github.com/khanhicetea/Caffee)), không dùng code UniKey/EVKey. Chỉ Telex + VNI, triết lý tối giản.

**DMG có notarized không?** Có — từ v3.5 trở đi.

## Nguồn gốc & giấy phép

Fork mở rộng từ **[Caffee](https://github.com/khanhicetea/Caffee)**; học hỏi thêm từ **[XKey](https://github.com/xmannv/xkey)** và **[GoNhanh.org](https://github.com/khaphanspace/gonhanh.org)**. Từ điển: [common-vietnamese-syllables](https://github.com/vietnameselanguage/syllable), [undertheseanlp/dictionary](https://github.com/undertheseanlp/dictionary), Wiktionary/wordfreq — chi tiết [LICENSE-DATA.md](LICENSE-DATA.md).

**Giấy phép:** [GPL v3](LICENSE) (code) · CC BY-SA 4.0 (dữ liệu từ điển phái sinh).

Kiến trúc kỹ thuật: [app-arch.md](app-arch.md) · Release: [RELEASE.md](RELEASE.md)
