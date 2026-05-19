# Icon Set Templates — vkey

57 SF Symbol đang dùng trong vkey 1.5.4, export sẵn dạng PNG 3 size để
designer làm bộ icon bitmap thay thế (theme "3D" hoặc theme custom khác).

## Cấu trúc

```
Tools/icon-set-templates/
├── README.md
├── gear/
│   ├── gear-32.png   (64×64 retina)
│   ├── gear-64.png   (128×128 retina)
│   └── gear-96.png   (192×192 retina)
├── keyboard/
│   └── ...
└── (56 thư mục khác)
```

Mỗi thư mục là **1 SF Symbol**, chứa 3 PNG ở 3 kích thước:
- `<name>-32.png` — 32pt @ 2x = **64×64 px** (dùng cho menu bar item, list row)
- `<name>-64.png` — 64pt @ 2x = **128×128 px** (dùng cho Settings UI medium)
- `<name>-96.png` — 96pt @ 2x = **192×192 px** (dùng cho icon to / preview)

PNG đã render bằng SF Symbol API (`NSImage(systemSymbolName:)` + `SymbolConfiguration` weight=.regular, scale=.large). Đây là **bản black-and-white outline gốc**, designer dùng làm template để vẽ phiên bản 3D bóng bẩy hoặc style khác.

## Designer workflow

1. Mở từng PNG trong thư mục, hiểu hình dạng + ý nghĩa (xem comment trong `Tools/export_sf_symbols.swift` để biết icon nào dùng cho context gì).
2. Vẽ lại theo style mong muốn (ví dụ: 3D glossy như macOS Dock, isometric, neumorphism…). **Khuyến nghị**:
   - Output **PDF vector** để asset catalog tự scale mọi DPI.
   - Hoặc xuất PNG 1x / 2x / 3x cho mỗi kích thước cụ thể.
3. Drop vào `vkey/Assets.xcassets/Icons3D/<name>.imageset/`. Cấu trúc 1 imageset:
   ```
   Icons3D/gear.imageset/
   ├── Contents.json
   └── gear.pdf      (hoặc gear@1x.png, gear@2x.png, gear@3x.png)
   ```
4. Build lại app — `ThemedSymbol` sẽ tự ưu tiên asset PDF/PNG thay vì runtime SwiftUI effects.

## Ghi chú

- **Symbol `hat.3`** (dùng cho preset Alfred trong Smart Switch) không tồn tại trong SF Symbols, nên không export được. Nếu designer muốn override Alfred icon, dùng tên bất kỳ và sửa code `SmartSwitchView.swift` line 26.
- **Icon trạng thái menu bar** (`gear.badge.questionmark`, `lock.square`) và **cờ VN/US** (`vn-flag`, `us-flag`) hiện cố ý KHÔNG đi qua `ThemedSymbol` — chúng giữ nguyên bất kể theme. Nếu muốn theme cả 3 status icon này luôn, cần sửa `MenuBarLabel` struct trong `vkeyApp.swift`.
- **App icon** (`Assets.xcassets/AppIcon`) hoàn toàn riêng — không nằm trong scope theme.

## Re-export khi thêm icon mới

Mỗi khi vkey thêm SF Symbol mới trong UI:

1. Thêm tên symbol vào array `symbols` trong `Tools/export_sf_symbols.swift`.
2. Chạy lại: `swift Tools/export_sf_symbols.swift`.
3. Commit PNG mới vào repo.

Designer có thể track diff để biết cần làm thêm icon nào.
