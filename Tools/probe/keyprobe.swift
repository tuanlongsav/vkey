// keyprobe — công cụ ĐO cho tầng gửi phím của vkey. KHÔNG phải mã sản phẩm.
//
// Vì sao cần: ba lỗi tầng transport (T1 đổi app giữa từ, T2 thứ tự phím,
// T3 trục NFC/NFD lật giữa từ) đã bị vá hỏng hai lần, và cả hai lần đều vì
// SỬA TRƯỚC KHI ĐO. Công cụ này làm phép đo rẻ đi tới mức không còn cớ bỏ qua.
//
// Chìa khoá làm nó chạy được: `CGEventSource(stateID: .hidSystemState)` cho
// `eventSourceStateID == 1`, tức event tổng hợp từ đây ĐI QUA được bộ lọc
// self-event của vkey (`EventHook.swift`: bỏ qua mọi event có stateID != 1).
// Nghĩa là vkey xử lý phím do công cụ này bắn ra Y HỆT phím người gõ.
// (`.privateState` cho một ID cấp động, `.combinedSessionState` cho 0 — cả hai
// đều bị vkey bỏ qua, nên KHÔNG dùng được để đo.)
//
// Build:  swiftc -O Tools/probe/keyprobe.swift -o /tmp/keyprobe
// Chạy:   /tmp/keyprobe help

import ApplicationServices
import AppKit
import Foundation

// MARK: - Bàn phím US: ký tự -> virtual keycode

let keyCodes: [Character: CGKeyCode] = [
  "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
  "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
  "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
  "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
  "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
  "`": 50,
]
let kReturn: CGKeyCode = 36
let kTab: CGKeyCode = 48
let kSpace: CGKeyCode = 49
let kDelete: CGKeyCode = 51  // Backspace (xoá lùi), KHÔNG phải forward delete

// MARK: - An toàn

/// Công cụ này bắn phím vào BẤT KỲ thứ gì đang focus. Trong terminal đang chạy
/// vim/less ở normal mode, một ký tự lạc là một LỆNH — có thể xoá dòng, ghi file,
/// thoát không lưu. Chặn cứng, không có cờ để bỏ qua.
let bannedPrefixes = [
  "com.apple.Terminal", "com.googlecode.iterm2", "net.kovidgoyal.kitty",
  "com.mitchellh.ghostty", "dev.warp.Warp", "co.zeit.hyper", "org.tabby",
  "io.alacritty", "org.alacritty", "com.github.wez.wezterm", "com.raphaelamorim.rio",
  "com.termius", "com.apple.Console",
]

func frontmostBundleId() -> String? {
  NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

func assertSafeTarget() {
  guard let bid = frontmostBundleId() else {
    fail("Không xác định được app đang focus. Dừng cho chắc.")
  }
  for p in bannedPrefixes where bid.hasPrefix(p) {
    fail("""
      TỪ CHỐI: app đang focus là \(bid) — một terminal.
      Gõ thử vào terminal có thể chạy nhầm lệnh (vim normal mode, shell prompt).
      Chuyển focus sang ô nhập cần đo rồi chạy lại.
      """)
  }
}

func fail(_ msg: String) -> Never {
  FileHandle.standardError.write(("keyprobe: " + msg + "\n").data(using: .utf8)!)
  exit(2)
}

// MARK: - Bắn phím

/// Nguồn event DUY NHẤT dùng được: chỉ `.hidSystemState` mới cho stateID == 1.
func makeSource() -> CGEventSource {
  guard let src = CGEventSource(stateID: .hidSystemState) else {
    fail("Không tạo được CGEventSource(.hidSystemState).")
  }
  // Kiểm trên chính EVENT, không trên source: `eventSourceStateID` là trường của
  // CGEvent, và đó đúng là trường mà bộ lọc self-event của vkey đọc.
  guard let probe = CGEvent(keyboardEventSource: src, virtualKey: kSpace, keyDown: true) else {
    fail("Không tạo được CGEvent thử từ source.")
  }
  let sid = probe.getIntegerValueField(.eventSourceStateID)
  if sid != 1 {
    fail("""
      Event từ source này mang stateID=\(sid), không phải 1 — vkey sẽ BỎ QUA nó
      và phép đo trở thành vô nghĩa (đo bàn phím trần, không có vkey ở giữa).
      """)
  }
  return src
}

func tap(_ code: CGKeyCode, shift: Bool = false, source: CGEventSource, delayMs: UInt32) {
  guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
    let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
  else { fail("Không tạo được CGEvent cho keycode \(code).") }
  if shift {
    down.flags = .maskShift
    up.flags = .maskShift
  }
  down.post(tap: .cgSessionEventTap)
  up.post(tap: .cgSessionEventTap)
  usleep(delayMs * 1000)
}

/// Gõ một chuỗi ký tự. Chữ hoa được gửi kèm Shift đúng như người gõ.
func typeString(_ s: String, source: CGEventSource, delayMs: UInt32) {
  for ch in s {
    if ch == " " { tap(kSpace, source: source, delayMs: delayMs); continue }
    if ch == "\n" { tap(kReturn, source: source, delayMs: delayMs); continue }
    if ch == "\t" { tap(kTab, source: source, delayMs: delayMs); continue }
    let lower = Character(ch.lowercased())
    guard let code = keyCodes[lower] else {
      fail("Chưa map keycode cho ký tự '\(ch)'. Thêm vào bảng keyCodes.")
    }
    tap(code, shift: ch.isUppercase, source: source, delayMs: delayMs)
  }
}

func backspace(_ n: Int, source: CGEventSource, delayMs: UInt32) {
  for _ in 0..<n { tap(kDelete, source: source, delayMs: delayMs) }
}

// MARK: - Đọc ngược bằng Accessibility

func axFocusedElement() -> AXUIElement? {
  let sw = AXUIElementCreateSystemWide()
  AXUIElementSetMessagingTimeout(sw, 1.0)
  var ref: CFTypeRef?
  guard AXUIElementCopyAttributeValue(sw, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
    let r = ref, CFGetTypeID(r) == AXUIElementGetTypeID()
  else { return nil }
  return (r as! AXUIElement)
}

func axString(_ el: AXUIElement, _ attr: String) -> String? {
  var ref: CFTypeRef?
  guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success else { return nil }
  return ref as? String
}

/// In ra dạng CHẨN ĐOÁN ĐƯỢC: vừa scalar (phân biệt NFC/NFD) vừa số UTF-16 unit
/// (thứ mà `String ==` của Swift KHÔNG phân biệt, vì nó so theo tương đương
/// chuẩn tắc — "ề" dạng NFC == "ề" dạng NFD trả về true).
func describe(_ s: String) -> String {
  let scalars = s.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
  return """
      text      : "\(s)"
      scalars   : [\(scalars)]  (\(s.unicodeScalars.count) scalar)
      graphemes : \(s.count)
      utf16     : \(s.utf16.count)
    """
}

func readFocusedValue() -> String? {
  guard let el = axFocusedElement() else { return nil }
  return axString(el, kAXValueAttribute as String)
}

func countdown(_ seconds: Int) {
  guard seconds > 0 else { return }
  for i in stride(from: seconds, to: 0, by: -1) {
    print("  … \(i)s — hãy đưa con trỏ vào ô cần đo", terminator: "\r")
    fflush(stdout)
    sleep(1)
  }
  print("  … bắt đầu                                   ")
}

// MARK: - Lệnh

func cmdFocus() {
  let bid = frontmostBundleId() ?? "(không rõ)"
  print("frontmost : \(bid)")
  guard let el = axFocusedElement() else {
    print("AX focused: (không đọc được — app có thể không phơi AX)")
    return
  }
  print("AX role   : \(axString(el, kAXRoleAttribute as String) ?? "(không đọc được)")")
  print("AX subrole: \(axString(el, kAXSubroleAttribute as String) ?? "-")")
  if let v = axString(el, kAXValueAttribute as String) {
    print("AX value  :")
    print(describe(v))
  } else {
    print("AX value  : (không đọc được)")
  }
}

/// PHÉP ĐO T4 — câu hỏi treo từ lâu: ô nhập nền Chromium xoá backspace theo
/// SCALAR hay theo GRAPHEME? Trục NFC/NFD cho Zalo/Messenger/Chrome web content
/// đang là GIẢ ĐỊNH dựa trên câu trả lời này.
///
/// Cách đo: để vkey tự dựng "ề" (gõ `eef` telex), đọc trạng thái, gửi ĐÚNG MỘT
/// backspace, đọc lại. Đo theo HÀNH VI (còn lại gì) chứ không theo biểu diễn
/// (chuỗi trông thế nào) — vì AX có thể chuẩn hoá trên đường ra, làm phép đo
/// theo biểu diễn nói dối.
func cmdMeasureT4(delayMs: UInt32, wait: Int) {
  assertSafeTarget()
  let bid = frontmostBundleId() ?? "?"
  print("=== ĐO T4: đơn vị xoá của ô nhập ===")
  print("app đích  : \(bid)")
  print("cách đo   : gõ `eef` (telex → ề), gửi 1 Backspace, xem còn lại gì")
  print("YÊU CẦU   : vkey phải ĐANG BẬT và ở chế độ tiếng Việt, kiểu Telex.")
  print("")
  countdown(wait)

  let src = makeSource()

  let before = readFocusedValue()
  if let b = before, !b.isEmpty {
    print("⚠️  Ô không rỗng trước khi đo — kết quả có thể lẫn. Nội dung hiện có:")
    print(describe(b))
    print("")
  }

  typeString("eef", source: src, delayMs: delayMs)
  usleep(300_000)
  guard let afterType = readFocusedValue() else {
    print("KHÔNG ĐỌC ĐƯỢC AXValue sau khi gõ.")
    print("→ App này không phơi giá trị ô nhập qua AX (Chrome web content là ca đã biết).")
    print("→ Dùng Tools/probe/probe.html + đọc bằng JS trong console thay cho đường này.")
    return
  }
  print("SAU KHI GÕ `eef`:")
  print(describe(afterType))

  // Nếu vkey không chạy hoặc không ở chế độ VI thì sẽ ra "eef" thay vì "ề".
  let typed = afterType.hasPrefix(before ?? "") ? String(afterType.dropFirst((before ?? "").count)) : afterType
  if !typed.contains("ề") {
    print("")
    print("⚠️  Không thấy chữ 'ề'. Nhiều khả năng vkey đang TẮT, đang ở chế độ EN,")
    print("    hoặc kiểu gõ không phải Telex. Sửa rồi đo lại — số đo hiện tại vô nghĩa.")
    return
  }

  backspace(1, source: src, delayMs: delayMs)
  usleep(300_000)
  guard let afterBS = readFocusedValue() else {
    print("KHÔNG ĐỌC ĐƯỢC AXValue sau backspace.")
    return
  }
  print("")
  print("SAU 1 BACKSPACE:")
  print(describe(afterBS))

  // Phán quyết theo hành vi.
  let base = before ?? ""
  let tail = afterBS.hasPrefix(base) ? String(afterBS.dropFirst(base.count)) : afterBS
  print("")
  print("=== PHÁN QUYẾT ===")
  if tail.isEmpty {
    print("XOÁ THEO GRAPHEME — một Backspace ăn trọn cụm 'ề'.")
    print("→ Trục NFC là đúng cho ô nhập này.")
  } else if tail.unicodeScalars.count >= 1 && !tail.contains("ề") {
    print("XOÁ THEO SCALAR — một Backspace chỉ bóc một scalar, còn lại:")
    print(describe(tail))
    print("→ Trục NFD là đúng cho ô nhập này.")
  } else if tail.contains("ề") {
    print("KHÔNG ĐỔI — ô nhập NUỐT LUÔN synthetic backspace.")
    print("→ Đây là khả năng thứ BA, và nếu đúng thì cả cuộc tranh cãi NFC/NFD là")
    print("  lạc đề: lỗi 'gửi'→'ửi' không phải lỗi trục mà là lỗi backspace bị nuốt,")
    print("  và cách vá đúng là đổi CHIẾN LƯỢC GỬI (axDirect) chứ không phải đổi cách đếm.")
  } else {
    print("KHÔNG PHÂN LOẠI ĐƯỢC. Còn lại:")
    print(describe(tail))
  }
}

/// Đếm số backspace cần để xoá sạch một cụm — chặt chẽ hơn cmdMeasureT4 một bậc
/// vì nó không phụ thuộc việc đọc đúng phần đuôi.
func cmdCountBackspaces(delayMs: UInt32, wait: Int, maxBS: Int) {
  assertSafeTarget()
  print("=== ĐẾM BACKSPACE: cần mấy phím để xoá hết 'ề' ===")
  print("app đích  : \(frontmostBundleId() ?? "?")")
  countdown(wait)

  let src = makeSource()
  let base = readFocusedValue() ?? ""
  typeString("eef", source: src, delayMs: delayMs)
  usleep(300_000)
  guard let afterType = readFocusedValue(), afterType != base else {
    print("Không đọc được thay đổi qua AX — dùng probe.html cho app này.")
    return
  }
  print("sau khi gõ: \(afterType.unicodeScalars.count) scalar / \(afterType.count) grapheme")

  for n in 1...maxBS {
    backspace(1, source: src, delayMs: delayMs)
    usleep(250_000)
    let now = readFocusedValue() ?? ""
    print("  backspace #\(n) → \(now.unicodeScalars.count) scalar / \(now.count) grapheme")
    if now == base {
      print("")
      print("=== PHÁN QUYẾT ===")
      print("Cần \(n) backspace để xoá 'ề'.")
      if n == 1 {
        print("→ XOÁ THEO GRAPHEME. Trục NFC đúng cho ô này.")
      } else {
        print("→ XOÁ THEO SCALAR (\(n) scalar). Trục NFD đúng cho ô này.")
      }
      return
    }
  }
  print("")
  print("Sau \(maxBS) backspace vẫn chưa về trạng thái ban đầu — ô có thể đang nuốt backspace.")
}

/// Đo T2: gõ một chuỗi rồi kiểm xem app nhận có ĐÚNG THỨ TỰ không.
/// Đây là ca "push" → "pussh" trong docstring effectiveTypingStrategy.
func cmdOrder(text: String, reps: Int, delayMs: UInt32, wait: Int) {
  assertSafeTarget()
  print("=== ĐO T2: thứ tự phím ===")
  print("app đích  : \(frontmostBundleId() ?? "?")")
  print("gõ        : \"\(text)\" × \(reps), nhịp \(delayMs)ms/phím")
  countdown(wait)

  let src = makeSource()
  var mismatches = 0
  var samples: [String] = []
  for i in 1...reps {
    let base = readFocusedValue() ?? ""
    typeString(text, source: src, delayMs: delayMs)
    usleep(400_000)
    let now = readFocusedValue() ?? ""
    let got = now.hasPrefix(base) ? String(now.dropFirst(base.count)) : now
    if got.unicodeScalars.count != text.unicodeScalars.count || samples.first.map({ $0 != got }) == true {
      mismatches += 1
      if samples.count < 8 { samples.append(got) }
    }
    if samples.isEmpty { samples.append(got) }
    // dọn: xoá đúng số grapheme vừa thêm
    backspace(got.count, source: src, delayMs: delayMs)
    usleep(200_000)
    if i % 10 == 0 { print("  … \(i)/\(reps), lệch: \(mismatches)") }
  }
  print("")
  print("=== KẾT QUẢ ===")
  print("lệch \(mismatches)/\(reps) = \(String(format: "%.1f", Double(mismatches) * 100 / Double(reps)))%")
  if !samples.isEmpty {
    print("mẫu nhận được: \(samples.map { "\"\($0)\"" }.joined(separator: ", "))")
  }
  print("")
  print("Ngưỡng quyết định: dưới 0,5% thì KHÔNG đáng làm nhánh T2 — ghi số này lại")
  print("rồi bỏ qua, đừng sửa. Trên ngưỡng thì mới tính tới hàng đợi/barrier.")
}

func usage() {
  print("""
    keyprobe — đo tầng gửi phím của vkey (công cụ đo, không phải mã sản phẩm)

    LỆNH
      focus                  In app + AX role + AXValue của ô đang focus (không gõ gì)
      t4    [--delay N] [--wait N]
                             ĐO T4: ô nhập xoá backspace theo scalar hay grapheme
      count [--delay N] [--wait N] [--max N]
                             Đếm số backspace cần để xoá 'ề' (chặt hơn t4 một bậc)
      order --text S [--reps N] [--delay N] [--wait N]
                             ĐO T2: gõ S nhiều lần, đếm số lần app nhận sai thứ tự
      type  --text S [--delay N] [--wait N]
                             Chỉ gõ, không đo (để thử tay)

    THAM SỐ
      --delay N   ms giữa hai phím (mặc định 50; 30 = gõ nhanh, 80 = thong thả)
      --wait N    giây đếm ngược trước khi bắt đầu (mặc định 5)
      --reps N    số lần lặp cho `order` (mặc định 50)
      --max N     trần backspace cho `count` (mặc định 6)

    ĐIỀU KIỆN
      - Cần quyền Accessibility cho terminal đang chạy công cụ này.
      - vkey phải ĐANG BẬT, chế độ tiếng Việt, kiểu Telex (cho t4/count).
      - Từ chối chạy khi app đang focus là terminal — gõ nhầm vào vim là mất dữ liệu.

    VÌ SAO NÓ CHẠY ĐƯỢC
      Chỉ `CGEventSource(stateID: .hidSystemState)` cho eventSourceStateID == 1,
      tức đi qua được bộ lọc self-event của vkey. vkey xử lý phím từ đây y hệt
      phím người gõ. `.privateState` và `.combinedSessionState` đều bị bỏ qua.
    """)
}

// MARK: - Vào lệnh

var args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else {
  usage()
  exit(1)
}
args = Array(args.dropFirst())

func intArg(_ name: String, _ def: Int) -> Int {
  guard let i = args.firstIndex(of: name), i + 1 < args.count, let v = Int(args[i + 1]) else { return def }
  return v
}
func strArg(_ name: String, _ def: String) -> String {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return def }
  return args[i + 1]
}

if !AXIsProcessTrusted() {
  fail("""
    Chưa có quyền Accessibility cho tiến trình đang chạy công cụ này.
    Cấp trong System Settings → Privacy & Security → Accessibility cho terminal của bạn,
    rồi chạy lại. (Không có quyền thì đọc ngược AXValue luôn trả nil.)
    """)
}

let delay = UInt32(intArg("--delay", 50))
let wait = intArg("--wait", 5)

switch cmd {
case "focus": cmdFocus()
case "t4": cmdMeasureT4(delayMs: delay, wait: wait)
case "count": cmdCountBackspaces(delayMs: delay, wait: wait, maxBS: intArg("--max", 6))
case "order":
  cmdOrder(text: strArg("--text", "push"), reps: intArg("--reps", 50), delayMs: delay, wait: wait)
case "type":
  // `--bs N` gửi N phím Backspace SAU phần text. Phải nằm trong CÙNG một binary
  // với phần gõ: macOS cấp quyền Accessibility theo từng executable, nên một
  // binary phụ vừa biên dịch sẽ post event vào hư không mà không báo lỗi gì.
  assertSafeTarget()
  countdown(wait)
  let src = makeSource()
  let text = strArg("--text", "")
  if !text.isEmpty { typeString(text, source: src, delayMs: delay) }
  let nbs = intArg("--bs", 0)
  if nbs > 0 {
    usleep(300_000)
    backspace(nbs, source: src, delayMs: delay)
  }
case "help", "-h", "--help": usage()
default:
  usage()
  exit(1)
}
