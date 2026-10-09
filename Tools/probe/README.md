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

## Kết quả đã đo — bộ nhớ phình khi dựng lại HUD (v4.28 → v4.29)

**Trên máy thật** — v4.28 chạy liên tục 9 ngày, footprint 551 MB. Đo bằng
`vmmap --summary` + `heap` trên tiến trình đang chạy:

| Loại | Số lượng | Chia cho số vùng 16 KB |
|---|---|---|
| Vùng `shared memory` 16 KB | 27.808 (435 MB, 92% đã bị nén/swap) | 1 |
| `NSKeyValueDependencyContext` (AppKit) | 56.065 | 2,02 |
| `NSKeyValueDependency` (AppKit) | 112.290 | 4,04 |

Heap chỉ còn 2–3 view HUD đang sống, tức view cũ **được** giải phóng; thứ còn
lại là dữ liệu nội bộ của AppKit kèm trang shared memory. Tỉ lệ cố định cho thấy
cả ba sinh ra từ cùng một sự kiện, khoảng 28.000 lần ≈ 3.100 lần/ngày — đúng cỡ
số lần HUD đoán từ hiện (v4.28 dựng `NSHostingController` mới mỗi lần hiện).

> ⚠️ **Đính chính (26/09/2026, đo trên v4.29):** kết luận "cả ba cùng một sự
> kiện" **sai cho cột shared memory**. ctx/dep đúng là của HUD; còn 27.808 vùng
> 16 KB là của **event source** — xem mục kế tiếp. Tỉ lệ 1 : 2 : 4 trùng hợp vì
> cả số lần hiện HUD lẫn số lần thay chữ đều tỉ lệ với số từ đã gõ.

**`hudleak` trên GitHub Actions** (macOS 15.7, Xcode 16.4, máy ảo), 300 lần mỗi kiểu:

| Kiểu | shared memory | `…Context` | `NSKeyValueDependency` |
|---|---|---|---|
| `rebuild` (cách v4.28) | +2 | +600 | +6.000 |
| `hosting` (dựng lại, view không blur) | +2 | +600 | +5.400 |
| `blur` (chỉ gắn/gỡ NSVisualEffectView) | 0 | 0 | +300 |
| `reuse` (cách v4.29) | 0 | 0 | 0 |
| `reuse-hide` (v4.29 + ẩn/hiện mỗi lần) | 0 | 0 | 0 |

⇒ **Thủ phạm là tạo NSHostingController/NSHostingView mới** trong panel sống
lâu: +2 context mỗi lần, đúng tỉ lệ trên máy thật, kể cả khi view không có lớp
blur. Dùng lại khung thì không tăng, kể cả khi ẩn/hiện. Rò nằm trong framework
nên chỉ tránh được bằng cách **không dựng lại** — xem comment ở
`PredictionHUDWindow.show`.

⚠️ Trên máy ảo macOS 15.7, vùng shared memory **không** tăng theo — vì nó vốn
không đến từ HUD (xem mục kế tiếp). Thước đo rò HUD là ctx/dep, không phải shm.

```bash
swiftc -parse-as-library -O Tools/probe/hudleak.swift -o /tmp/hudleak
/tmp/hudleak rebuild 300     # rebuild | reuse | reuse-hide | hosting | blur
```

---

## Kết quả đã đo — shared memory 16 KB là event source, không phải HUD (v4.29)

**Triệu chứng** — cài 4.29 (HUD đã dùng lại khung), đo 22 phút gõ trên máy thật:
ctx/dep đứng yên (47/242), nhưng `shared memory` tăng 17 → 110.

**Ai giữ vùng đó** — `leaks <pid> --outputGraph=x.memgraph` rồi
`leaks --trace=<địa chỉ vùng> x.memgraph`: mọi vùng tăng thêm chỉ có một root,
`SkyLight get_cache()::cache` → khối 768 B → nút 16 B → vùng 16 KB `r--/r--`.
`get_cache()` nằm cạnh `server_create_event_source_state`,
`CGSEventSourceShmemCreateFromMemoryEntry`,
`CGSEventSourceCache::server_get_event_source_state_for_id` trong bảng symbol
của SkyLight (tra bằng `lldb` → `image dump symtab SkyLight` trên một tiến trình
AppKit bất kỳ) — tức là **cache trạng thái `CGEventSource`**.

**Cơ chế** (tái hiện ngoài vkey, chỉ tạo rồi huỷ source, không post phím nào):

| Tạo 50 lần | shm trước → sau | stateID khác nhau |
|---|---|---|
| `CGEventSource(stateID: .combinedSessionState)` | 1 → 1 | 1 |
| `CGEventSource(stateID: .privateState)` | 1 → **52** | 50 |

Mỗi source private có một state riêng kèm một trang 16 KB; SkyLight giữ trang
đó tới khi tiến trình thoát, **kể cả khi source đã được giải phóng**.

**Trong vkey** — mỗi lần thay chữ (batch / stepByStep / hybrid / fallback
axDirect / Option+Backspace) tạo một `.privateState` mới. `keyprobe type` 20 lần
`cas ` vào TextEdit: 4.29 → **+20** vùng; bản dùng chung một source
(`EventSimulator.privateEventSource()`) → +2 (lần tạo source đầu tiên), rồi thêm
5×`text ` (đường Option+Backspace) + `tieengs vieetj abc` → **+0**, chữ ra đúng,
Option không kẹt.

Khoá bằng ba test `PrivateEventSourceTests`: source phải là một object dùng lại
và vẫn private (stateID ≠ 1); 40 lần lấy source không được thêm quá 4 vùng shm
(đếm bằng `vmmap` trên chính tiến trình test); và cả cây `vkey/` chỉ có một chỗ
viết `CGEventSource(stateID: .privateState)`.

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

## Kết quả đã đo — mã phím của event chỉ mang Unicode (v4.32 → v4.33)

**Lỗi:** v4.32 "không gõ được tiếng Việt": dấu không ra, mất chữ giữa/cuối, mất
cả cụm — ở **mọi** app (native, Electron, terminal). 441/441 test vẫn pass, vì
test không chạm tầng gửi event thật.

**Nguyên nhân:** v4.32 đổi `EventSimulator.KeyCode.unicodeOnly` từ `0` sang
`0xFF` theo suy diễn "mã này không sinh ký tự". `0xFF` không phải mã phím ảo hợp
lệ (virtual keycode chỉ 7 bit) → app bỏ im lặng **cả event**, nên chuỗi Unicode
đi kèm không bao giờ tới. Backspace (`0x33`) vẫn hợp lệ nên vẫn xoá chữ cũ: vkey
xoá rồi không chèn lại được gì.

**Phép đo** (`kcsweep.swift` cho TextEdit/AppKit, `kcpost.swift` + `cdp.mjs` cho
ô `<input>` trong Chrome; event `.privateState` — đúng loại vkey tự phát):

| virtualKey | TextEdit (AppKit) | Chrome (Blink) | ghi chú |
|---|---|---|---|
| **0** (phím A) | chữ tới đúng | chữ tới đúng | mã dùng tới v4.31, đã trả lại ở v4.33 |
| 10 (ISO §) | chữ tới đúng | chữ tới đúng | sinh "§" trên bàn phím ISO nếu app chèn ký tự của mã phím |
| 90 (F20) | chữ tới đúng | chữ tới đúng | chưa đo rủi ro app bind F20 |
| 110 (Menu) | chữ tới đúng | chữ tới đúng | chưa đo rủi ro app mở context menu |
| 64, 79, 80, 106 (F17–F19, F16) | **mất trắng** | — | AppKit gắn cờ `.function`, `NSEvent.characters` rỗng |
| 126 (Up) | **mất trắng** | — | cùng lý do |
| **255 (0xFF)** | **mất trắng** | **mất trắng** | ngoài dải 7 bit |

**Giả thuyết của v4.32 KHÔNG tái hiện được.** v4.32 ghi "Chromium, Electron và
Claude Desktop chèn cả ký tự của mã phím lẫn chuỗi Unicode (`google` →
`gooogle`)". Đo lại với mã `0` vào ô `<input>` Chrome: gửi `google` nhận đúng
`google`, gửi `Việt` nhận đúng `Việt`, gửi `ề` nhận đúng `ề` — không ký tự ký
sinh nào. Chú ý chính triệu chứng đã tự tố: `gooogle` thừa chữ **o**, không phải
chữ **a** — mã phím A không giải thích được nó. Nếu lỗi thừa chữ còn gặp thì đo
lại bằng hai probe trên, **đừng đổi hằng số theo suy diễn**.

**Chốt lại:** hằng số đó là điểm thắt cổ chai của cả 5 đường gửi chữ. Trước khi
đổi nó, chạy `kcsweep` trên app native **và** `kcpost` + `cdp.mjs` trên Blink.
Hai test `UnicodeOnlyKeyCodeTests` chặn sẵn hai nhóm mã xấu đã biết (ngoài 7 bit,
và phím chức năng), nhưng test không thay được phép đo trên app thật.

---

## Kết quả đã đo — cờ "Shift thật" và phạm vi gỡ cờ Shift (v4.32 → v4.33)

**Cơ chế:** `InputProcessor.hardwareShiftDown` phân biệt Shift THẬT với "Shift
chỉ dính trên event" bằng cách nghe `flagsChanged`; khi cờ là `false`,
`passThrough` gỡ `.maskShift` khỏi event trả về app.

**Phép đo** (`shifttest.swift` dựng hai ca, `evlog.swift` đọc chuỗi event,
`arrowtest.swift` đo thiệt hại; tất cả post vào `.cghidEventTap`):

| ca | chuỗi event vkey nhận | kết quả |
|---|---|---|
| Shift thật | `flagsChg kc=56 SHIFT` → `keyDown SHIFT` | `xin Chao` |
| Shift kẹt | chỉ `keyDown SHIFT` | `xin chao` |

Cơ chế chạy đúng như thiết kế. Nhưng hai ca này là **cùng một thứ** dưới mắt
vkey khi `flagsChanged` bị mất — dòng cập nhật cờ nằm sau hai early-return của
`handleTapEvent`, nên Shift nhấn/thả trong lúc hệ thống vô hiệu tap, lúc tap
gắn lại, hoặc lúc quyền Trợ năng mất rồi được cấp lại, đều không tới.

**Thiệt hại khi cờ mắc sai** — v4.32 gỡ cờ Shift trên MỌI phím:

| phép đo | v4.32 | sau khi thu phạm vi |
|---|---|---|
| `"abc"` + Shift+Left + `"x"` | **`abxc`** (chỉ dời con trỏ) | `abx` (chọn rồi ghi đè) |
| Shift+Enter trong app chat | mất Shift → **gửi tin dở** | giữ Shift → xuống dòng |
| Shift kẹt trên phím chữ | `chao` | `chao` (không đổi) |
| Shift thật trên phím chữ | `Chao` | `Chao` (không đổi) |

**Hai nguồn sự thật đã thử và loại:**

- `CGEventSource.flagsState(.hidSystemState)` báo `true` ở **cả hai** ca (event
  đi qua HID tap cũng cập nhật trạng thái modifier của WindowServer), nên KHÔNG
  phân biệt được Shift kẹt. Chỉ dùng được để **đồng bộ lại** cờ sau khi tap
  gián đoạn — đó là cách đang dùng.
- `NSEvent.modifierFlags` trễ một event: ở `flagsChanged` Shift-down nó còn báo
  `false`, ở Shift-up nó còn báo `true`. Đừng dùng cho quyết định theo từng phím.

**Còn treo — lỗi GỐC chưa tái hiện được.** v4.32 vá "chữ cái thứ hai đầu câu bị
viết hoa" (`Việt` → `VIệt`). Với event tổng hợp thì không dựng lại được: `evlog`
cho thấy event HID ngay sau chữ hoa tổng hợp **không** mang Shift, và gõ
`ok. vieetj` ra đúng `ok. Việt`. Nghĩa là chẩn đoán "macOS giữ Shift trên phím
kế tiếp" chưa được kiểm trên **bàn phím thật**. Ai muốn gỡ `hardwareShiftDown`:
chạy `evlog` rồi gõ tay một câu bắt đầu bằng chữ thường sau dấu `.`, xem event
thật có `SHIFT` hay không. Đừng gỡ theo suy diễn, và cũng đừng mở rộng phạm vi
gỡ cờ theo suy diễn.

---

## Còn phải đo

- **T2 (thứ tự phím)** — `keyprobe order --text push --reps 50` vào từng app
  `.stepByStep`. Ngưỡng quyết định: **dưới 0,5% ở nhịp 80cps thì KHÔNG đáng làm**
  nhánh T2 — ghi số lại rồi bỏ qua.
- **Ô chứa chữ không do vkey phát ra** (dán vào / app tự điền) — ca duy nhất mà
  bất biến v4.15 không phủ.
- **Chữ cái thứ hai đầu câu có thật bị viết hoa trên BÀN PHÍM THẬT hay không** —
  lỗi gốc mà `hardwareShiftDown` đi vá, chưa tái hiện được bằng event tổng hợp.
  Phép đo: `/tmp/evlog com.apple.TextEdit 10`, rồi gõ TAY `ok. viet` vào
  TextEdit, xem event HID sau chữ hoa tổng hợp có `SHIFT` không. Có → cờ đang
  giữ đúng việc; không → cờ vá một thứ không tồn tại và nên gỡ.
- **Zalo và Messenger thật**, không chỉ Blink nói chung. Cả hai là Electron nên
  dự kiến giống `contenteditable` ở trên, nhưng dự kiến không phải phép đo.
