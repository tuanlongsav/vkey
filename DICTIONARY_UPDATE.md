# Cập nhật từ điển vkey

Tài liệu cho maintainer: cách publish bản từ điển mới mà KHÔNG cần phát hành app DMG mới. Người dùng app từ 1.5.3+ sẽ tự nhận update trong 24h kế tiếp sau khi launch (im lặng, không cần action).

## Tổng quan cơ chế

- Người dùng cài vkey 1.5.x trở lên kèm bản từ điển nhúng (embedded) ở `EmbeddedLexiconData.swift`.
- Khi launch, app tự gọi `LexiconManager.checkAndPromptForDictionaryUpdate()` — request HTTP GET tới GitHub.
- **Endpoint từ v1.6.2+**: `https://raw.githubusercontent.com/tuanlongsav/vkey/main/lexicon-update.json` (CDN, không giới hạn 1 MB, không bị rate-limit anonymous, cache 300s).
- **Endpoint v1.5.x → v1.6.1 (legacy)**: `https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json` với header `Accept: application/vnd.github.v3.raw`. Có giới hạn 1 MB raw + rate-limit 60 req/h.
- Throttle 24h client-side qua `Defaults[.lastDictionaryCheckDate]` để tránh spam GitHub.
- Nếu `package.version > currentVersion` (so sánh Int trực tiếp): tự download + ghi vào `~/Library/Application Support/vkey/lexicon/lexicon-update.json` + reload lexicon — KHÔNG hỏi user, KHÔNG hiển thị alert.
- **Manual override (v1.6.2+)**: nút **"Cập nhật từ điển ngay"** trong Cài đặt → tab Chính tả → Section "Từ điển từ GitHub" → bypass throttle, force check.

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
# v1.6.2+ endpoint (CDN, recommended)
curl -s https://raw.githubusercontent.com/tuanlongsav/vkey/main/lexicon-update.json | jq .version

# Legacy v1.5.x → v1.6.1 endpoint (vẫn hoạt động, fallback)
curl -s -H "Accept: application/vnd.github.v3.raw" \
  https://api.github.com/repos/tuanlongsav/vkey/contents/lexicon-update.json | jq .version
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

- **v1.6.2+ endpoint (`raw.githubusercontent.com`)**: KHÔNG rate-limit anonymous, KHÔNG giới hạn 1 MB, CDN cache 300s. Không lo chạm limit kể cả khi user share NAT.
- **Legacy endpoint (`api.github.com/.../contents`)**: 60 req/giờ/IP cho anonymous, raw bị giới hạn 1 MB.
- App dùng `cachePolicy = .reloadIgnoringLocalCacheData` để bypass URLCache local. Không bị cache stale.
- **Local cache** trên máy user: `~/Library/Application Support/vkey/lexicon/lexicon-update.json`. App tự ghi đè khi có version mới hơn.

## Audit tools (v1.6.1+)

Khi merge data từ nguồn ngoài (vd undertheseanlp/dictionary), DÙNG các script trong `Tools/`:

| Script | Mục đích |
|--------|---------|
| [`Tools/build_underthesea_package.py`](Tools/build_underthesea_package.py) | Merge thô single-token từ undertheseanlp JSONL vào lexicon-update.json |
| [`Tools/audit_lexicon.py`](Tools/audit_lexicon.py) | Loại noise — single-char + ASCII-only no-VN-marker entries (chống false-positive English) |
| [`Tools/merge_underthesea_deep.py`](Tools/merge_underthesea_deep.py) | Deep merge từ multi-word phrases với 3-tier classification (A cross-validated, B single-phrase + phonotactic, C ASCII loanword whitelist) |

Workflow:
```bash
git clone --depth 1 https://github.com/undertheseanlp/dictionary.git /tmp/undertheseanlp-dictionary
python3 Tools/merge_underthesea_deep.py \
  --underthesea /tmp/undertheseanlp-dictionary/dictionary/words.txt \
  --in lexicon-update.json --out lexicon-update.json
# Sau khi merge, optional cleanup:
python3 Tools/audit_lexicon.py
```

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
