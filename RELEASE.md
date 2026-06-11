# Sparkle Release Guide (`vkey`)

Tài liệu này là quy trình đóng gói/release để **không bị lỗi cập nhật qua Sparkle**.

## 0) Tổng quan workflow release (v1.7.1+, hardened v1.7.11+, Developer ID + notarize v3.5+)

Mọi release vkey đều phải đi qua chuỗi bước SAU theo thứ tự. **BƯỚC 11 (README) LÀ BLOCKING** — không được skip, không được push nếu README chưa được rà soát/cập nhật.

```
1.  Implement code changes + test suite pass
2.  Bump version (MARKETING_VERSION + CURRENT_PROJECT_VERSION trong pbxproj) — **chỉ 2 cấp `MAJOR.MINOR`**, xem quy tắc Section 1
3.  Archive Release: xcodebuild archive -allowProvisioningUpdates (Section 2)
4.  Ký Developer ID + nộp notarization: xcodebuild -exportArchive
    (method=developer-id, destination=upload — Tools/ExportOptions-upload.plist)
5.  Poll xcodebuild -exportNotarizedApp (30s/lần, thường 1-5 phút) → app đã
    staple ticket; verify spctl ("Notarized Developer ID") + stapler validate
6.  Package DMG (hdiutil) từ app ĐÃ NOTARIZED (không dùng app trong archive!)
7.  Sign Sparkle (Tools/sparkle_sign_update.sh) → capture edSignature + length
8.  Update appcast.xml — thêm item mới ở ĐẦU danh sách (escape `&` → `&amp;` trong title)
9.  Validate appcast (Tools/validate_appcast.sh) — XML lint pass
10. **CHANGELOG.md** — thêm section `## [x.y] - YYYY-MM-DD — "Title"` đầu file
11. **🚨 README.md — RÀ SOÁT + CHỈNH SỬA (BLOCKING, BẮT BUỘC từ v1.7.1+)** — xem checklist Section 5b bên dưới
12. Verify version + signature + length khớp giữa pbxproj ↔ appcast ↔ DMG file size
13. **Verify README đã update** — `git diff --cached README.md` phải có diff khi version đổi
14. Commit (`git add -A && git commit`) — message tóm tắt + nhắc đã rà soát README
15. **Ask user confirm trước khi push** (release là shared action, không tự push;
    user yêu cầu release/đồng bộ GitHub ngay trong phiên = đã confirm)
16. `git push origin main`
17. `gh release create vX.Y vkey-X.Y.dmg --title "..." --notes-file <CHANGELOG section>`
18. Verify release asset uploaded: size khớp `length` trong appcast + URL download trả HTTP 200
```

### 🚨 Gating rule (v1.7.11+): README diff = release pass

**Trước khi `git commit` cho release**, agent/maintainer PHẢI verify:
- `git diff --cached README.md` có ≥ 1 dòng thay đổi.
- Nếu version có UI/feature/data change → README phải có diff tương ứng (ít nhất bump version banner).
- Commit message kèm chuỗi `README rà soát ✓` để track.

**Nếu README chưa có diff** → STOP, quay lại Section 5b checklist, sửa README, rồi mới commit. KHÔNG được push nếu chưa pass gate này.

`Tools/validate_release.sh` (sắp có) sẽ check tự động: `git diff HEAD~1 README.md | wc -l > 0`.

## 1) Nguyên tắc bắt buộc trước khi phát hành

### 🔢 Quy tắc đánh version (BẮT BUỘC từ v2.4+): chỉ 2 cấp `MAJOR.MINOR`

- `MARKETING_VERSION` (= `CFBundleShortVersionString`) **chỉ có 2 cấp**: `MAJOR.MINOR` (ví dụ `2.4`, `2.5`, … rồi `3.1`, `3.2`, …).
- **KHÔNG dùng cấp patch thứ 3** (không `2.4.1`, `2.4.2`, …). Mọi release — kể cả hotfix — đều bump `MINOR` lên 1.
- Khi sang dòng lớn mới thì bump `MAJOR` và reset `MINOR` về 1 (vd `2.x` → `3.1`).
- `CURRENT_PROJECT_VERSION` (= `CFBundleVersion`) tính theo công thức **`MAJOR*10000 + MINOR*100`** (patch luôn `00`) để vẫn tăng dần tuyệt đối và liên tục với các build cũ. Ví dụ:
  - `2.4` → `20400`
  - `2.5` → `20500`
  - `3.1` → `30100`
- Lịch sử trước đây dùng 3 cấp (vd `2.3.22` = build `20322`). Kể từ `2.4` chuyển hẳn sang 2 cấp; build mới (`20400`) vẫn > build cũ (`20322`) nên Sparkle update không bị gãy.

1. `CFBundleVersion` phải **tăng dần tuyệt đối** mỗi release (ví dụ `20322` -> `20400`).
2. `CFBundleShortVersionString` là version hiển thị **2 cấp** (ví dụ `2.4`) và phải khớp với appcast.
3. `SUPublicEDKey` trong `vkey/Info.plist` phải khớp với private key dùng để ký update.
4. File update (`.dmg` hoặc `.zip`) phải có:
   - `sparkle:edSignature` đúng
   - `length` đúng (bytes thực tế)
5. URL trong `<enclosure url="...">` phải là URL tải trực tiếp, ổn định, truy cập được công khai.
6. `appcast.xml` phải public và trỏ đúng từ `SUFeedURL`.

Nếu sai một trong các điều kiện trên, Sparkle sẽ từ chối update.

## 2) Build bản phát hành (v3.5+: Developer ID + notarization)

Từ v3.5, app ký bằng **Developer ID Application: Long Hoang Tuan (U4B264GM2B)**
(cert cloud-managed — private key nằm trên Apple, KHÔNG có trong keychain local;
`-allowProvisioningUpdates` tự fetch khi export). `DEVELOPMENT_TEAM` đã ghi sẵn
trong pbxproj. Yêu cầu: Xcode đang đăng nhập Apple ID của team (Settings →
Accounts) — auth qua session Xcode, KHÔNG cần app-specific password.

```bash
# 1. Archive
xcodebuild -project vkey.xcodeproj -scheme vkey -configuration Release archive \
  -archivePath /tmp/vkey-X.Y.xcarchive \
  -destination 'generic/platform=macOS' \
  -allowProvisioningUpdates

# 2. Ký Developer ID + nộp notarization (destination=upload)
xcodebuild -exportArchive \
  -archivePath /tmp/vkey-X.Y.xcarchive \
  -exportPath /tmp/vkey-X.Y-upload \
  -exportOptionsPlist Tools/ExportOptions-upload.plist \
  -allowProvisioningUpdates
# Lưu ý: bước này thỉnh thoảng fail "The request timed out" — chạy lại là được.

# 3. Poll cho đến khi Apple duyệt (thường 1-5 phút) → export app đã staple ticket
xcodebuild -exportNotarizedApp \
  -archivePath /tmp/vkey-X.Y.xcarchive \
  -exportPath /tmp/vkey-X.Y-notarized
# Lặp lại mỗi 30s nếu chưa xong ("EXPORT FAILED" = chưa duyệt xong)

# 4. Verify trước khi đóng gói
spctl --assess --type exec -vv /tmp/vkey-X.Y-notarized/vkey.app   # "Notarized Developer ID"
xcrun stapler validate /tmp/vkey-X.Y-notarized/vkey.app
```

Sau đó đóng gói `.app` (bản notarized) thành `.dmg`:

```bash
mkdir /tmp/vkey-dmg-staging
cp -R /tmp/vkey-X.Y-notarized/vkey.app /tmp/vkey-dmg-staging/
ln -s /Applications /tmp/vkey-dmg-staging/Applications
hdiutil create -volname "vkey X.Y" -srcfolder /tmp/vkey-dmg-staging -ov -format UDZO vkey-X.Y.dmg
```

DMG không ký Developer ID được bằng `codesign` CLI (key cloud-managed) — chấp
nhận được vì app bên trong đã notarized + stapled, Gatekeeper vẫn pass khi user
kéo app ra. Ký Sparkle (EdDSA) cho DMG vẫn BẮT BUỘC như Section 3.

⚠️ Đổi chữ ký (vd ad-hoc → Developer ID, hoặc đổi team) làm macOS đòi cấp lại
quyền Trợ năng một lần — phải ghi chú trong release notes.

## 3) Ký Sparkle cho file update

Sử dụng script hỗ trợ:

```bash
./Tools/sparkle_sign_update.sh \
  --archive /path/to/vkey-2.4.dmg \
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
  <title>Version 2.4</title>
  <sparkle:version>20400</sparkle:version>
  <sparkle:shortVersionString>2.4</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
  <pubDate>Tue, 19 May 2026 10:00:00 +0700</pubDate>
  <enclosure
    url="https://github.com/tuanlongsav/vkey/releases/download/v2.4/vkey-2.4.dmg"
    sparkle:edSignature="..."
    length="..."
    type="application/octet-stream"
  />
</item>
```

## 5) Checklist chống lỗi Sparkle (quan trọng)

Trước khi publish appcast/release, bắt buộc check:

1. Mở app hiện tại -> "Check for Updates...":
   - Không được báo "latest" nếu build local thấp hơn appcast mới.
2. So sánh cặp version:
   - `Info.plist` (`CFBundleVersion`, `CFBundleShortVersionString`)
   - `appcast.xml` item đầu.
3. So sánh `length` trong appcast với:
   - `stat -f%z /path/to/dmg`
4. So sánh `sparkle:edSignature` với output mới từ `sparkle_sign_update.sh`.
5. Đảm bảo `SUFeedURL` trỏ đúng appcast public.
6. Đảm bảo release asset đã tồn tại thật (không 404).
7. **(v3.5+)** App trong DMG phải là bản NOTARIZED:
   - `spctl --assess --type exec -vv <app>` → `source=Notarized Developer ID`
   - `xcrun stapler validate <app>` → "The validate action worked!"
   - `codesign -dvv <app>` → `Authority=Developer ID Application: Long Hoang Tuan (U4B264GM2B)` + `flags=0x10000(runtime)`
8. **(v3.5+)** Nếu release này ĐỔI chữ ký so với bản trước (đổi cert/team) →
   release notes + appcast PHẢI có cảnh báo "cấp lại quyền Trợ năng một lần".

## 5b) 🚨 Checklist README rà soát (v1.7.1+, hardened v1.7.11+)

**BẮT BUỘC** — bất kỳ release nào bump version đều phải pass checklist này TRƯỚC khi commit. Không có ngoại lệ, kể cả hotfix.

### Workflow chuẩn

```bash
# 1. Sau khi xong code + CHANGELOG, chưa commit:
git diff README.md   # Phải có thay đổi nếu version đổi/UI đổi

# 2. Tick từng item dưới, sửa README cho mỗi item fail
# 3. Re-run check:
git diff --stat README.md   # Phải có ≥1 dòng

# 4. Commit (message kèm marker "README rà soát ✓"):
git add -A
git commit -m "vX.Y ... | README rà soát ✓"

# 5. Push chỉ sau khi user confirm
```

### Checklist (tick từng dòng)

- [ ] **Version banner** — line ~8: `**Phiên bản hiện tại: X.Y — "Title"**` ↔ MARKETING_VERSION trong pbxproj.
- [ ] **Lexicon stats** — câu "Bộ từ điển hiện tại (vN — vX.Y+): ... syllables VN + ... từ EN" còn đúng?
- [ ] **Features list** (section "Chức năng") — tính năng mới của release này đã thêm bullet? Bullet outdated đã sửa/xoá? Version annotation `(vX.Y+)` chính xác?
- [ ] **Tab descriptions** — mỗi tab Settings (Chung / Smart Switch / Macro / Chính tả / Thống kê) có khớp UI thực tế? Section reorder/rename đã reflect?
- [ ] **Button/label rename** — vd "Quản lý từ điển cá nhân" → "Sửa từ điển cá nhân" (v1.7.11), tab labels rút gọn/restore (v1.7.7/v1.7.8). Search README cho tên cũ.
- [ ] **Menu bar table** — item menu mới? Description khớp wording trong app?
- [ ] **Phím gõ đặc biệt** — phím tắt mới (vd Tab smart-detect cho prediction v1.7.7) đã add?
- [ ] **Credits section** — nguồn data/lib mới đã credit đầy đủ với license?
- [ ] **Tools list** — script mới (`audit_lexicon.py`, `merge_underthesea_deep.py`, `build_lexicon.py` ...) đã list?
- [ ] **LICENSE-DATA.md** — dataset thay đổi (size, source) đã sync số liệu?
- [ ] **Screenshots (`images/`)** — UI thay đổi nhiều → re-capture ảnh tab tương ứng (xem section [Hình ảnh minh hoạ](README.md#hình-ảnh-minh-hoạ)). Đảm bảo các tham chiếu `images/*.png` trong README vẫn tồn tại.
- [ ] **Outdated wording sweep** — search README các cụm từ deprecated:
  - "auto-promote", "luôn dùng tiếng Anh", "5 lần tự động" (cũ trước v1.6.0).
  - "Quản lý từ điển cá nhân" (đổi thành "Sửa từ điển cá nhân" ở v1.7.11).
  - "180×720" / "270×720" / "minimalist tối đa" (cũ trước v1.7.6 windowResizability fix).
  - "126 từ EN" / "wordfreq top 2000" (cũ trước v1.7.9 expansion).
  - "Personal Dict Editor có button Gửi" (cũ trước v1.7.11 — nút đã ra ngoài tab Chính tả).

### Gating rule

**Quy tắc cứng (v1.7.11+):**

1. **Mỗi release commit PHẢI có README diff ≥ 1 dòng** (ít nhất là bump version banner). Nếu không có → STOP, mở README cập nhật.
2. **Commit message của release** phải kèm chuỗi `README rà soát ✓` để track. Ví dụ:
   ```
   vX.Y "Title" — short summary

   ... details ...

   README rà soát ✓ | N/M tests pass
   ```
3. **`gh release create` chỉ được chạy SAU commit pass cả 2 điều kiện trên.**

**README là API contract với user.** Outdated README = user confused → bug report giả + complaint. Phòng tránh bằng workflow chặt thay vì sửa post-hoc.

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

5. **(v3.5+) `exportArchive` fail "The request timed out" / "No signing certificate Developer ID Application found"**
   - Nguyên nhân: request lên dịch vụ cloud signing của Apple bị timeout (cert
     Developer ID là cloud-managed, mỗi lần export đều gọi Apple).
   - Cách tránh: chạy lại y nguyên lệnh — thường lần 2 là được. Nếu fail dai
     dẳng: mở Xcode → Settings → Accounts kiểm tra session Apple ID còn đăng
     nhập (session hết hạn thì đăng nhập lại) rồi retry.

6. **(v3.5+) `exportNotarizedApp` báo EXPORT FAILED**
   - Nguyên nhân: Apple CHƯA duyệt xong notarization — đây không phải lỗi.
   - Cách tránh: poll lại mỗi 30s (thường 1-5 phút). Nếu >30 phút vẫn fail,
     kiểm tra log distribution trong `/var/folders/.../xcdistributionlogs` —
     có thể bị reject thật (entitlement/binary issue).

7. **(v3.5+) User báo app đòi cấp lại quyền Trợ năng sau update**
   - Nguyên nhân: chữ ký app đổi so với bản trước (vd ad-hoc → Developer ID
     ở v3.5, hoặc tương lai đổi cert/team) → TCC reset entry.
   - Cách tránh: GIỮ NGUYÊN cert Developer ID hiện tại cho mọi release sau.
     Nếu buộc phải đổi → cảnh báo rõ trong release notes + appcast.

## 7) Bảo mật key

### Sparkle EdDSA key (ký update)

- Không commit private key lên git.
- Nên lưu private key trong nơi an toàn và backup.
- File gợi ý dùng local: `/Users/longht/Desktop/Claude/vkey/vkey_private_key.key`
- Nếu đổi key, cần kế hoạch key rotation theo tài liệu Sparkle.

### Developer ID key (ký app, v3.5+)

- Cert **Developer ID Application: Long Hoang Tuan (U4B264GM2B)** là
  **cloud-managed**: private key nằm trong HSM của Apple, KHÔNG có file key
  local nào để backup/lộ. Keychain local chỉ có cert Apple Development /
  Apple Distribution (Xcode tự quản).
- Điều kiện dùng: Xcode đăng nhập Apple ID của Account Holder. Mất máy không
  mất key — máy mới chỉ cần đăng nhập Xcode là ký tiếp được.
- KHÔNG tự tạo thêm Developer ID cert qua portal trừ khi có lý do — đổi cert
  = đổi chữ ký = user phải cấp lại quyền Trợ năng (xem Section 6.7).
