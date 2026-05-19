# Sparkle Release Guide (`vkey`)

Tài liệu này là quy trình đóng gói/release để **không bị lỗi cập nhật qua Sparkle**.

## 1) Nguyên tắc bắt buộc trước khi phát hành

1. `CFBundleVersion` phải **tăng dần tuyệt đối** mỗi release (ví dụ `14100` -> `14200`).
2. `CFBundleShortVersionString` là version hiển thị (ví dụ `1.4.2`) và phải khớp với appcast.
3. `SUPublicEDKey` trong `vkey/Info.plist` phải khớp với private key dùng để ký update.
4. File update (`.dmg` hoặc `.zip`) phải có:
   - `sparkle:edSignature` đúng
   - `length` đúng (bytes thực tế)
5. URL trong `<enclosure url="...">` phải là URL tải trực tiếp, ổn định, truy cập được công khai.
6. `appcast.xml` phải public và trỏ đúng từ `SUFeedURL`.

Nếu sai một trong các điều kiện trên, Sparkle sẽ từ chối update.

## 2) Build bản phát hành

Khuyến nghị dùng Archive + Developer ID trong Xcode để đảm bảo helper của Sparkle được ký đúng.

CLI build tham chiếu:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/vkey-derived \
  clean build
```

Sau đó đóng gói `.app` thành `.dmg` để phát hành.

## 3) Ký Sparkle cho file update

Sử dụng script hỗ trợ:

```bash
./Tools/sparkle_sign_update.sh \
  --archive /path/to/vkey-1.4.2.dmg \
  --private-key /Users/longht/Desktop/Claude/vkey/vkey_private_key.key
```

Script sẽ in ra fragment:

```xml
sparkle:edSignature="..." length="..."
```

Copy chính xác fragment này vào thẻ `<enclosure ... />` trong `appcast.xml`.

## 4) Cập nhật appcast đúng thứ tự

Thêm item mới lên **đầu danh sách** trong `appcast.xml`:

- `<sparkle:version>` = `CFBundleVersion`
- `<sparkle:shortVersionString>` = `CFBundleShortVersionString`
- `url` = link file phát hành đúng version
- `sparkle:edSignature` + `length` từ bước ký
- `pubDate` theo RFC822

Ví dụ:

```xml
<item>
  <title>Version 1.4.2</title>
  <sparkle:version>14200</sparkle:version>
  <sparkle:shortVersionString>1.4.2</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
  <pubDate>Tue, 19 May 2026 10:00:00 +0700</pubDate>
  <enclosure
    url="https://github.com/tuanlongsav/vkey/releases/download/v1.4.2/vkey-1.4.2.dmg"
    sparkle:edSignature="..."
    length="..."
    type="application/octet-stream"
  />
</item>
```

## 5) Checklist chống lỗi Sparkle (quan trọng)

Trước khi publish appcast/release, bắt buộc check:

1. Mở app hiện tại -> “Check for Updates...”:
   - Không được báo “latest” nếu build local thấp hơn appcast mới.
2. So sánh cặp version:
   - `Info.plist` (`CFBundleVersion`, `CFBundleShortVersionString`)
   - `appcast.xml` item đầu.
3. So sánh `length` trong appcast với:
   - `stat -f%z /path/to/dmg`
4. So sánh `sparkle:edSignature` với output mới từ `sparkle_sign_update.sh`.
5. Đảm bảo `SUFeedURL` trỏ đúng appcast public.
6. Đảm bảo release asset đã tồn tại thật (không 404).

## 6) Các lỗi hay gặp và cách tránh

1. **Lỗi “public key doesn’t match signature”**
   - Nguyên nhân: dùng nhầm private key.
   - Cách tránh: luôn ký bằng đúng key cặp với `SUPublicEDKey` trong app.

2. **Lỗi “signature missing/invalid”**
   - Nguyên nhân: quên cập nhật `sparkle:edSignature` hoặc ký nhầm file.
   - Cách tránh: ký lại đúng file dmg cuối cùng, rồi paste lại fragment mới.

3. **Lỗi không thấy update dù có bản mới**
   - Nguyên nhân: `sparkle:version` không tăng, hoặc item mới không nằm đầu feed.
   - Cách tránh: tăng build number nghiêm ngặt và thêm item mới lên đầu.

4. **Lỗi download/update fail do URL**
   - Nguyên nhân: URL release đổi, private, hoặc chưa publish asset.
   - Cách tránh: verify URL truy cập trực tiếp trước khi publish appcast.

## 7) Bảo mật key

- Không commit private key lên git.
- Nên lưu private key trong nơi an toàn và backup.
- File gợi ý dùng local: `/Users/longht/Desktop/Claude/vkey/vkey_private_key.key`
- Nếu đổi key, cần kế hoạch key rotation theo tài liệu Sparkle.
