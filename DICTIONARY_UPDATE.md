# Cập nhật từ điển vkey

Tài liệu cho maintainer: cách publish bản từ điển mới mà KHÔNG cần phát hành app DMG mới. Người dùng app từ 1.5.3+ sẽ tự nhận update trong 24h kế tiếp sau khi launch (im lặng, không cần action).

## Tổng quan cơ chế

- Người dùng cài vkey 1.5.x kèm bản từ điển nhúng (embedded) ở `EmbeddedLexiconData.swift`.
- Khi launch, app tự gọi `LexiconManager.checkAndPromptForDictionaryUpdate()` — request HTTP GET tới GitHub API.
- Endpoint: `https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json` với header `Accept: application/vnd.github.v3.raw` (returns raw JSON bypass GitHub CDN cache).
- Throttle 24h client-side qua `Defaults[.lastDictionaryCheckDate]` để tránh spam GitHub API.
- Nếu `package.version > currentVersion` (so sánh Int trực tiếp): tự download + ghi vào `~/Library/Application Support/vkey/lexicon/lexicon-update.json` + reload lexicon — KHÔNG hỏi user, KHÔNG hiển thị alert.

## Quy trình maintainer

### 1. Cài Python deps (lần đầu)

```bash
pip3 install wordfreq requests
```

### 2. Cập nhật từ điển

**Option A — Chỉ thêm vài entry** (sửa JSON tay, nhanh nhất):

1. Mở file `lexicon-update.json` ở **root repo** (không phải `lexicon/lexicon-update.json` — file đó là backup/staging, không được app fetch).
2. Thêm/sửa entry vào section tương ứng:
   - `vietnamese[]` — danh sách âm tiết tiếng Việt hợp lệ.
   - `english[]` — top từ tiếng Anh được nhận diện cho Space Restore.
   - `keep[]` — từ tiếng Việt luôn giữ nguyên, không auto-restore.
   - `en_vn_mapping` — dict English → [Vietnamese candidates].
   - `vn_en_mapping` — dict Vietnamese → [English candidates].
3. **Bump `"version"` lên +1** (ví dụ 5 → 6). Bắt buộc, nếu không user sẽ không nhận update.
4. Verify JSON hợp lệ:
   ```bash
   jq . vkey/lexicon/lexicon-update.json > /dev/null && echo OK
   ```

**Option B — Rebuild toàn bộ** (refresh wordfreq + Wiktionary):

```bash
python3 Tools/build_lexicon.py \
  --out lexicon-update.json \
  --kaikki-download
```

Sau khi script chạy xong, **mở file output và bump `"version"` tay** (script không tự bump version).

> Lưu ý: file `lexicon-update.json` ở **root** repo là cái app thực sự fetch. Repo có thêm `lexicon/lexicon-update.json` (path nested) dùng cho staging/backup — bạn có thể sync 2 file hoặc bỏ file nested khi cleanup.

### 3. Commit + push

```bash
git add lexicon-update.json
git commit -m "Lexicon vN: <mô tả thay đổi ngắn>"
git push origin main
```

Không cần push lên branch khác — endpoint của app gọi tới `main` mặc định.

### 4. Verify endpoint

Sau push 30s–1 phút (GitHub propagation), kiểm tra version trả về đúng:

```bash
curl -s -H "Accept: application/vnd.github.v3.raw" \
  https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json \
  | jq .version
```

Output phải là số version mới bạn vừa bump.

### 5. Người dùng nhận update khi nào?

- **Tự động**: lần launch tiếp theo của app sau >24h từ lần check trước (`Defaults[.lastDictionaryCheckDate]`).
- **Force ngay**: user bấm nút **"Cập nhật từ điển ngay"** trong Cài đặt → tab Chính tả → mục "Từ điển GitHub".
- Update apply im lặng — KHÔNG có alert. Lexicon mới có hiệu lực ngay sau khi `reload()` chạy xong (thường <500ms).

## Quy ước version

- **Chỉ tăng**. Không reset, không downgrade.
- **Bump kể cả khi chỉ sửa 1 từ** — app dùng comparison đơn giản `Int >` để biết cần download.
- **Độc lập với version app** (`1.5.2`, `1.5.3`, …). Dictionary version chỉ là Int trong JSON.
- Nếu bạn lỡ commit version cũ trùng/lùi, push commit khác bump version mới — không gãy gì.

## Rate limit & cache

- **GitHub API unauthenticated**: 60 request/giờ/IP. Mỗi user check tối đa 1 lần/24h nên không bao giờ chạm limit thực tế.
- **Cache CDN**: bypass qua header `cachePolicy = .reloadIgnoringLocalCacheData` + `Accept: application/vnd.github.v3.raw`. Không bị cache stale.
- **Local cache** trên máy user: `~/Library/Application Support/vkey/lexicon/lexicon-update.json`. App tự ghi đè khi có version mới hơn.

## Schema (tham khảo)

Top-level JSON shape (schema v5):

```json
{
  "version": 6,
  "generated_at": "2026-05-19",
  "vietnamese": ["a", "à", "á", "ả", ...],
  "english": ["the", "of", "and", ...],
  "keep": ["chì", "chỉ", ...],
  "en_vn_mapping": {
    "computer": ["máy tính"],
    "developer": ["lập trình viên"]
  },
  "vn_en_mapping": {
    "máy tính": ["computer"]
  },
  "_meta": {
    "attribution": "Wiktionary CC BY-SA 4.0, ...",
    "license": "..."
  }
}
```

Code load: `vkey/Lexicon/LexiconUpdatePackage.swift` (Codable struct).

## Troubleshooting

- **Push xong nhưng user không thấy update?** Check `Defaults[.lastDictionaryCheckDate]` — nếu vừa check trong 24h, user phải force qua nút "Cập nhật từ điển ngay" hoặc đợi 24h.
- **JSON parse fail trên app?** Verify lại bằng `jq`. Lỗi decode → app silent skip + giữ embedded data.
- **Endpoint trả 404?** Verify file tồn tại đúng vị trí trên branch `main`: `lexicon-update.json` (root repo). Path trong code: `repos/tuanlongsav/vkey/contents/lexicon-update.json` — KHÔNG có prefix `vkey/lexicon/`.
