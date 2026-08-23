# Tools/probe — bộ đo tầng gửi phím

Công cụ **ĐO**, không phải mã sản phẩm. Không có gì ở đây được biên dịch vào app.

Lý do tồn tại: ba lỗi tầng transport (T1 đổi app giữa từ, T2 thứ tự phím,
T3 trục NFC/NFD lật giữa từ) đã bị vá hỏng hai lần liên tiếp, và cả hai lần đều
vì **sửa trước khi đo**. Thư mục này làm phép đo rẻ đi tới mức không còn cớ bỏ qua.

---

## Kết quả đã đo — T4: đơn vị xoá của ô nhập

**Câu hỏi treo từ v4.14:** một phím Backspace ăn *một scalar* hay *trọn một cụm
chữ có dấu*? Trục NFC/NFD cho Zalo/Messenger/Chrome web content phụ thuộc câu
trả lời này, và trước đợt đo nó chỉ là **giả định**.

Đo ngày 2026-08-23, macOS 26 (Tahoe), Apple Silicon. Đặt sẵn `x` + `ề` vào ô ở
hai dạng chuẩn hoá, gửi **đúng một** Backspace, đọc lại. **vkey không tham gia
phép đo** — đo chính bản thân ô nhập.

| Engine | Ô | Lưu NFC (`x` `U+1EC1`) | Lưu NFD (`x` `e U+0302 U+0300`) | Kết luận |
|---|---|---|---|---|
| **AppKit** (TextEdit) | NSTextView | → `x` (bớt 1 scalar) | → `x` (**bớt 3 scalar**) | **xoá theo GRAPHEME** |
| **Blink** (Chrome 2026) | `<input type=text>` | → `x` (bớt 1 scalar) | → `x` `e U+0302` (**bớt 1 scalar**) | **xoá theo SCALAR** |
| **Blink** | `contenteditable` | → `x` (bớt 1 scalar) | → `x` `e U+0302` (**bớt 1 scalar**) | **xoá theo SCALAR** |

`contenteditable` là loại ô Zalo / Messenger / Slack / Discord dùng để soạn tin.

### Nghĩa là gì với vkey

**Hai engine xoá theo hai đơn vị khác nhau.** AppKit ăn trọn cụm 3 scalar; Blink
bóc từng scalar một.

Nhưng điều đó **không** biến nhánh nào hiện tại thành sai, vì bất biến v4.15
(*dạng phát ra == dạng dùng để đếm*) làm cả hai nhánh tự nhất quán:

- **Nhánh NFD** (Zalo, Messenger, Slack, Discord — Electron ngoài whitelist):
  vkey phát NFD nên ô giữ NFD; vkey đếm scalar; Blink xoá scalar. **Khớp.**
- **Nhánh NFC** (Chrome web content từ v4.21): vkey phát NFC nên ô giữ NFC; ở
  dạng NFC thì 1 grapheme == 1 scalar, nên đếm grapheme cũng ra đúng số. **Khớp.**

⇒ **Trục hiện tại của Zalo/Messenger là ĐÚNG.** Câu hỏi treo đã đóng, và lỗi
"mất chữ" ở các app đó **không phải** lỗi trục chuẩn hoá. Nên tìm ở T1 (đổi app
giữa từ) và T2 (thứ tự phím) thay vì tiếp tục nghi ngờ NFC/NFD.

⚠️ **Rủi ro còn lại, chưa đo:** cả hai nhánh chỉ đúng khi ô chứa chữ **do chính
vkey phát ra**. Nếu ô đang chứa chữ đến từ nguồn khác ở dạng khác — dán vào, app
tự điền, hoặc chữ gõ trước khi đổi app — thì số đếm lệch. Đây là ca đáng đo tiếp.

---

## keyprobe — robot gõ

```bash
swiftc -O Tools/probe/keyprobe.swift -o /tmp/keyprobe
/tmp/keyprobe help
```

**Vì sao nó lái được vkey.** Chỉ `CGEventSource(stateID: .hidSystemState)` sinh
ra event mang `eventSourceStateID == 1`, tức **đi qua được** bộ lọc self-event của
vkey (`EventHook.swift` bỏ qua mọi event có stateID != 1). Đo tại chỗ:

```
hidSystemState         eventSourceStateID = 1           → vkey XỬ LÝ
combinedSessionState   eventSourceStateID = 0           → vkey BỎ QUA
privateState           eventSourceStateID = 371959864   → vkey BỎ QUA
```

Đã xác nhận end-to-end: `/tmp/keyprobe type --text "eef"` vào TextEdit cho ra
`ề` — vkey xử lý phím robot **y hệt** phím người gõ. Nghĩa là **gõ thử tự động
hoá được ngay hôm nay**, không cần thêm cửa debug nào vào app.

(Cũng xác nhận bộ lọc self-event đang đúng: vkey phát bằng `.privateState` /
`.combinedSessionState`, cả hai đều không quay lại engine. **Đừng "sửa" nó.**)

### Hai cạm bẫy đã đâm phải, ghi lại để khỏi mất thời gian lần sau

1. **Tiến trình shell KHÔNG đọc được Accessibility.** `AXIsProcessTrusted()` trả
   `true` nhưng mọi `AXUIElementCopyAttributeValue` đều thất bại (-25204). Nên
   `keyprobe focus` / `t4` / `count` — vốn đọc ngược bằng AX — **không dùng được
   từ terminal**. Đọc ngược phải đi đường khác: AppleScript (app scriptable) hoặc
   CDP (trang web). Đây đúng là lý do trước đây phải làm file-diag *bên trong* vkey.
2. **macOS cấp quyền Accessibility theo từng executable.** Một binary phụ vừa
   biên dịch sẽ `post()` event vào hư không, **không báo lỗi gì cả**. Bắn phím và
   bắn backspace phải nằm trong **cùng một** binary — đó là lý do `--bs N` là cờ
   của `type` chứ không phải công cụ riêng.

### An toàn

`keyprobe` **từ chối chạy** khi app đang focus là terminal (Terminal, iTerm2,
Ghostty, Warp, Alacritty, WezTerm, kitty, Termius, Console…). Gõ nhầm vào `vim`
ở normal mode là mất dữ liệu. Không có cờ để bỏ qua chốt này.

---

## probe.html + cdp.mjs — đo phía Blink

```bash
# Chrome RIÊNG, hồ sơ tách rời — không đụng hồ sơ hay thiết lập của bạn
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 --user-data-dir=/tmp/vkey-probe-profile \
  --no-first-run --new-window "file://$PWD/Tools/probe/probe.html" &

node Tools/probe/cdp.mjs '(() => document.title)()'
```

**Vì sao đọc bằng JS chứ không bằng AX:** Chrome không phơi web content ra AX
theo cách vkey đọc được, và ngay cả khi đọc được thì AX có thể chuẩn hoá chuỗi
trên đường ra — phép đo "đọc lại rồi so" sẽ **nói dối** về dạng lưu thật.

**Vì sao dùng CDP chứ không dùng AppleScript:** Chrome mặc định tắt "Allow
JavaScript from Apple Events". Đó là thiết lập của người dùng; bật nó là việc
của họ, không phải của công cụ. Chrome riêng + CDP không đụng gì tới hồ sơ thật.

⚠️ **Dựng chuỗi NFC/NFD THẲNG TRONG JS** (`'ề'`), đừng truyền chuỗi
Unicode qua shell — lần đo đầu chuỗi NFD bị chuẩn hoá trên đường đi và cho ra số
liệu mâu thuẫn (cột "trước" giống nhau nhưng cột "sau" khác nhau). Dấu hiệu nhận
biết: hai dạng chuẩn hoá lại hiện cùng một dãy code point.

---

## Còn phải đo

- **T2 (thứ tự phím)** — `keyprobe order --text push --reps 50` vào từng app
  `.stepByStep`. Ngưỡng quyết định: **dưới 0,5% ở nhịp 80cps thì KHÔNG đáng làm**
  nhánh T2 — ghi số lại rồi bỏ qua.
- **Ô chứa chữ không do vkey phát ra** (dán vào / app tự điền) — ca duy nhất mà
  bất biến v4.15 không phủ.
- **Zalo và Messenger thật**, không chỉ Blink nói chung. Cả hai là Electron nên
  dự kiến giống `contenteditable` ở trên, nhưng dự kiến không phải phép đo.
