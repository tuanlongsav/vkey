import XCTest
import Defaults
@testable import vkey

final class EventSimulatorCoreTests: SpellResetTestCase {
  func testTelegramUsesStepByStep() throws {
    guard case .stepByStep = EventSimulator.getStrategy(for: "ru.keepcoder.Telegram") else {
      return XCTFail("Telegram phải dùng .stepByStep để tránh rớt chữ đầu ('gửi'→'ửi')")
    }
    // Đối chứng: app không khai báo vẫn fallback .hybrid (default).
    guard case .hybrid = EventSimulator.getStrategy(for: "com.example.khongkhaibao") else {
      return XCTFail("App không khai báo phải fallback .hybrid")
    }
  }

  /// v4.10 — overlay latch (chống icon menu bar nháy Việt↔Anh khi gõ Spotlight).
  /// Khoá danh sách overlay dùng cho latch: eventTargetUnixProcessID dao động
  /// overlay↔app nền trên macOS 26 → phải nhận diện đúng overlay để ghim.
  func testIsOverlayBundle() throws {
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.Spotlight"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.dock"))
    XCTAssertTrue(EventSimulator.isOverlayBundle("com.apple.systemuiserver"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("com.google.Chrome"))
    XCTAssertFalse(EventSimulator.isOverlayBundle("ru.keepcoder.Telegram"))
    XCTAssertFalse(EventSimulator.isOverlayBundle(""))
  }


  func testSendingStrategyReadsPerAppTableWithHybridFallback() throws {
    guard case .hybrid = EventSimulator.getStrategy(for: "") else {
      return XCTFail("activeApp rỗng phải rơi về fallback .hybrid của getStrategy")
    }
    guard case .hybrid = EventSimulator.getStrategy(for: "com.example.khongkhaibao") else {
      return XCTFail("App không khai báo phải fallback .hybrid")
    }
    guard case .stepByStep = EventSimulator.getStrategy(for: "com.apple.Terminal") else {
      return XCTFail("App có khai báo phải lấy đúng strategy trong bảng")
    }
  }

  func testStepByStepUnicodeUnitsPreserveWholeCharacter() throws {
    XCTAssertEqual(
      EventSimulator.unicodeUnits(for: "ắ"),
      String("ắ").utf16.map { UniChar($0) }
    )
    XCTAssertEqual(EventSimulator.unicodeUnits(for: "😀").count, 2)
    // v4.15: transport KHÔNG tự chuẩn hoá — combining mark NFD giữ nguyên 2
    // unit (base + mark). Chuẩn hoá NFC do sendReplacement quyết định theo
    // field (xem testEmittedCharactersFollowsFieldNormalization).
    XCTAssertEqual(EventSimulator.unicodeUnits(for: Character("a\u{0301}")).count, 2)
  }

}

// MARK: - ===========================================
// MARK: - App Sending Strategy Tests
// MARK: - ===========================================

/// Đảm bảo các app có input model "khó" được map đúng strategy gửi event.
final class AppSendingStrategyTests: XCTestCase {

  private func isStepByStep(_ bundleId: String) -> Bool {
    if case .stepByStep = EventSimulator.getStrategy(for: bundleId) { return true }
    return false
  }

  // Launchpad / Spotlight search field chạy trong tiến trình Dock
  // (com.apple.dock). Phải dùng stepByStep — batch/hybrid khiến gõ tiếng Việt
  // bị loạn (lặp/mất chữ, dấu sai).
  func testLaunchpadDockUsesStepByStep() throws {
    XCTAssertTrue(isStepByStep("com.apple.dock"),
      "Launchpad/Dock search phải dùng stepByStep để gõ tiếng Việt không loạn")
  }

  // Regression: terminal vẫn stepByStep; app thường vẫn dùng default (không stepByStep).
  func testTerminalStepByStepAndDefaultUnaffected() throws {
    XCTAssertTrue(isStepByStep("com.apple.Terminal"))
    XCTAssertFalse(isStepByStep("com.apple.TextEdit"),
      "App native thường KHÔNG nên rơi vào stepByStep")
  }

  private func isAxDirect(_ bundleId: String) -> Bool {
    if case .axDirect = EventSimulator.getStrategy(for: bundleId) { return true }
    return false
  }

  // v2.12: Spotlight — synthetic backspace bị inline-autocomplete nuốt/đảo bất
  // kể delay (v2.10 stepByStep vẫn lỗi) → phải ghi thẳng AXValue (axDirect).
  func testSpotlightUsesAxDirect() throws {
    XCTAssertTrue(isAxDirect("com.apple.Spotlight"),
      "Spotlight phải dùng axDirect — mọi strategy event-based đều bị nuốt backspace")
    XCTAssertTrue(isAxDirect("com.apple.systemuiserver"))
  }

  /// v4.23 (F2): bundle ID upstream của Alacritty là "org.alacritty"; entry
  /// "io.alacritty" thừa kế từ lúc fork và chưa ai đối chiếu — cùng lớp lỗi
  /// "com.warp.Warp" (xem `testWarpBundleIdMatchesRealChannels`). Giữ CẢ HAI:
  /// khớp bằng `hasPrefix` nên entry sai chỉ là không bao giờ khớp, còn bỏ đi
  /// mà đoán sai chiều thì Alacritty lại âm thầm rơi về hybrid.
  func testAlacrittyMatchesBothBundleIds() throws {
    XCTAssertTrue(isStepByStep("org.alacritty"), "bundle ID upstream phải khớp")
    XCTAssertTrue(isStepByStep("io.alacritty"), "entry cũ vẫn phải khớp")
  }

  /// v4.23 (F2): "com.termius-dmg.mac" chỉ bao bản DMG; bản Mac App Store mang
  /// ID khác. Prefix rút gọn "com.termius" bao MỌI kênh mà không phá entry cũ
  /// (chuỗi DMG cũng bắt đầu bằng "com.termius").
  func testTermiusMatchesAllChannels() throws {
    XCTAssertTrue(isStepByStep("com.termius-dmg.mac"), "bản DMG (entry cũ)")
    XCTAssertTrue(isStepByStep("com.termius.mac"), "bản Mac App Store")
  }

  /// v4.23 (F3): app CHAT trước đây bị bỏ sót nên rơi hết về `.hybrid(800)`
  /// mặc định — ô soạn tin là contenteditable (Electron) hoặc text engine
  /// riêng (Qt), batch/hybrid gửi cụm backspace + retype async không sync với
  /// composition → rớt/lặp chữ đúng lớp lỗi Claude Desktop ("gửi"→"ửi",
  /// "điêu"→"điều" hụt). Chat là chỗ gõ tiếng Việt nhiều nhất nên đổi
  /// stepByStep (chậm hơn) là đánh đổi có chủ ý.
  func testChatAppsUseStepByStep() throws {
    for bundle in [
      "com.vng.zalo",                 // Electron (đã kiểm trên máy)
      "com.vng.zalo.zalocall",        // helper cùng prefix
      "com.tinyspeck.slackmacgap",    // Slack
      "com.hnc.Discord",              // Discord (bao cả Canary/PTB)
      "com.facebook.archon",          // Messenger
      "com.htl.plume",                // Plume (WKWebView Messenger bubble)
      "desktop.WhatsApp",             // WhatsApp bản Electron tải từ web
      "com.viber.osx",                // Viber (Qt/QML, không phải Electron)
    ] {
      XCTAssertTrue(isStepByStep(bundle), "\(bundle) phải dùng .stepByStep")
    }
  }

  /// Đối chứng cho F3: WhatsApp bản Mac App Store là Catalyst/AppKit thật nên
  /// CỐ Ý không thêm — nó phải giữ `.hybrid` mặc định. Nếu ai đó "dọn" bằng
  /// cách đổi prefix thành "WhatsApp" hay "net.whatsapp" thì test này vỡ.
  func testMASWhatsAppStaysOnDefaultHybrid() throws {
    XCTAssertFalse(isStepByStep("net.whatsapp.WhatsApp"),
      "bản Catalyst/AppKit không cần stepByStep")
    guard case .hybrid = EventSimulator.getStrategy(for: "net.whatsapp.WhatsApp") else {
      return XCTFail("bản MAS phải rơi về .hybrid mặc định")
    }
  }
}


// MARK: - ===========================================
// MARK: - AX-Direct Delete-Start Tests (v2.14)
// MARK: - ===========================================

/// `axDeleteStart` lùi từ caret theo CỤM grapheme trong không gian UTF-16 —
/// an toàn với app lưu NFD (ô = o + combining ◌̂) như Spotlight.
final class AXDeleteStartTests: XCTestCase {

  /// Omnibox Chrome. Ghi AXValue đi vào `SetUserText(text, update_popup:
  /// true)` nên Chrome chạy lại gợi ý và tự điền phần đuôi, BÔI ĐEN. Đặt lại
  /// con trỏ lúc đó là đổi selection, mà "Modifying the selection accepts any
  /// inline autocompletion" (omnibox_edit_model.cc) → gợi ý trang dính thành chữ
  /// thật, phím sau chèn vào giữa. Field đã tự để caret đúng chỗ thì đừng đụng.
  func testCaretLeftAloneWhenFieldAlreadyPlacedIt() throws {
    // Vừa ghi "photon", Chrome tự điền "icat.com" và bôi đen phần đó.
    XCTAssertFalse(EventSimulator.axShouldPlaceCaret(
      selectionAfterWrite: CFRange(location: 6, length: 8), targetCaret: 6, valueLength: 14))
    // Không có gợi ý, caret đã ở ngay sau chữ vừa ghi.
    XCTAssertFalse(EventSimulator.axShouldPlaceCaret(
      selectionAfterWrite: CFRange(location: 6, length: 0), targetCaret: 6, valueLength: 6))
    // Sửa giữa chuỗi: field đẩy caret về cuối → vẫn phải đặt lại như trước.
    XCTAssertTrue(EventSimulator.axShouldPlaceCaret(
      selectionAfterWrite: CFRange(location: 20, length: 0), targetCaret: 6, valueLength: 20))
    // Bôi đen không nằm ở cuối thì không phải gợi ý tự điền.
    XCTAssertTrue(EventSimulator.axShouldPlaceCaret(
      selectionAfterWrite: CFRange(location: 6, length: 3), targetCaret: 6, valueLength: 14))
    // Không đọc được selection → đặt như trước.
    XCTAssertTrue(EventSimulator.axShouldPlaceCaret(
      selectionAfterWrite: nil, targetCaret: 6, valueLength: 6))
  }

  /// Kiểm tra sau khi ghi. Field đã ĐỔI thì lần ghi đã tới nơi, dù không
  /// khớp từng chữ (Chrome vừa gắn thêm gợi ý). Coi đó là thất bại thì vòng thử
  /// lại ghi CHỒNG lên chữ đã sửa ("photon" + gợi ý → "phototon…") rồi còn rơi
  /// xuống đường gửi phím giả.
  func testWriteLandedWhenFieldChangedEvenIfNotExact() throws {
    XCTAssertTrue(EventSimulator.axWriteLanded(
      oldValue: "phôt", wanted: "photon", got: "photon", hadSuffixSelection: false))
    XCTAssertTrue(EventSimulator.axWriteLanded(
      oldValue: "phôt", wanted: "photon", got: "photonicat.com", hadSuffixSelection: false))
    // So sánh sau chuẩn hoá: field trả NFD vẫn là khớp.
    XCTAssertTrue(EventSimulator.axWriteLanded(
      oldValue: "phot", wanted: "ph\u{00F4}t", got: "pho\u{0302}t", hadSuffixSelection: false))
    // Field y nguyên → lần ghi chưa tới, thử lại mới an toàn.
    XCTAssertFalse(EventSimulator.axWriteLanded(
      oldValue: "phôt", wanted: "photon", got: "phôt", hadSuffixSelection: false))
    // Luật cũ của Spotlight giữ nguyên: đuôi bôi đen sẵn, đọc lại còn đuôi.
    XCTAssertTrue(EventSimulator.axWriteLanded(
      oldValue: "safari", wanted: "sa", got: "safari", hadSuffixSelection: true))
  }

  func testNFCSimple() throws {
    // "gõ" NFC: g(1) + õ(1) = length 2; xoá 1 → lùi về sau 'g'
    let s = "g\u{00F5}"
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 1, usesNFC: true), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 2, backspaceCount: 2, usesNFC: true), 0)
  }

  func testNFDCombiningMark() throws {
    // "gõ" NFD: g(1) + o(1) + ◌̃(1) = length 3; xoá 1 phải lùi NGUYÊN cụm o+◌̃ → 1
    let s = "go\u{0303}"
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: true), 1)
    XCTAssertEqual(EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: true), 0)
  }

  func testClampsAtZeroAndHandlesEmptyValue() throws {
    XCTAssertEqual(EventSimulator.axDeleteStart("", caretUTF16: 0, backspaceCount: 3, usesNFC: true), 0)
    XCTAssertEqual(EventSimulator.axDeleteStart("ab", caretUTF16: 2, backspaceCount: 99, usesNFC: true), 0)
    XCTAssertEqual(EventSimulator.axDeleteStart("ab", caretUTF16: 2, backspaceCount: 99, usesNFC: false), 0)
  }

  /// `usesNFC: false` phải lùi theo SCALAR, khớp số đếm của `calcKeyStrokesNFD`.
  /// Trước đây luôn lùi theo grapheme, nên khi caller đưa số đếm scalar mà
  /// strategy bị `sendReplacement` ép sang axDirect (overlaySearchIsFocused)
  /// thì mỗi dấu thanh làm lùi dư một cụm → xoá lố sang ký tự đứng trước.
  func testNFDScalarAxisDeletesOneScalarPerUnit() throws {
    // "gõ" NFD: g(1) + o(1) + ◌̃(1) = length 3.
    let s = "go\u{0303}"
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: false), 2,
      "1 scalar = chỉ dấu ◌̃, base 'o' còn lại")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: false), 1,
      "2 scalar = ◌̃ + o, giữ 'g'")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 3, usesNFC: false), 0)

    // Trục scalar khớp đúng số mà calcKeyStrokesNFD sinh ra cho cùng phép thay.
    let (bs, _) = EventSimulator.calcKeyStrokes(from: "gõ", to: "gó", usesNFC: false)
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: bs, usesNFC: false),
      1, "axDirect xoá đúng phần mà calcKeyStrokesNFD đã đếm")
  }

  /// Surrogate pair là MỘT scalar — không được lùi nửa cặp.
  func testNFDScalarAxisKeepsSurrogatePairIntact() throws {
    let s = "a😀"  // 'a'(1) + emoji(2 UTF-16 unit) = length 3
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 1, usesNFC: false), 1,
      "Lùi 1 scalar phải nuốt trọn surrogate pair")
    XCTAssertEqual(
      EventSimulator.axDeleteStart(s, caretUTF16: 3, backspaceCount: 2, usesNFC: false), 0)
  }
}


// MARK: - v4.20: bảng app tương thích + manual accessibility
final class AppCompatV420Tests: XCTestCase {

  /// Bundle ID thật của Warp là "dev.warp.Warp-Stable" (và -Preview). Entry cũ
  /// "com.warp.Warp" không khớp gì nên Warp âm thầm chạy đường batch mặc định.
  func testWarpBundleIdMatchesRealChannels() {
    for bundle in ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview", "dev.warp.Warp"] {
      guard case .stepByStep = EventSimulator.getStrategy(for: bundle) else {
        return XCTFail("\(bundle) phải dùng .stepByStep")
      }
    }
    // Bundle ID SAI cũ không được vô tình vẫn khớp.
    guard case .hybrid = EventSimulator.getStrategy(for: "com.warp.Warp") else {
      return XCTFail("bundle ID cũ (sai) không nên khớp entry nào")
    }
  }

  /// Terminal bổ sung — đều là app dựng cây text riêng, cần gửi từng phím.
  func testAdditionalTerminalsUseStepByStep() {
    for bundle in ["com.github.wez.wezterm", "com.raphaelamorim.rio", "com.termius-dmg.mac"] {
      guard case .stepByStep = EventSimulator.getStrategy(for: bundle) else {
        return XCTFail("\(bundle) phải dùng .stepByStep")
      }
    }
  }

}


// MARK: - Nguồn phím .privateState dùng chung (rò 16 KB mỗi lần thay chữ)

/// Mỗi `CGEventSource(stateID: .privateState)` mới được WindowServer cấp một
/// state riêng kèm một trang shared memory 16 KB; SkyLight giữ trang đó trong
/// `CGSEventSourceCache` tới khi tiến trình thoát, KỂ CẢ khi source đã được giải
/// phóng. Đo trên máy thật (v4.29, 26/09/2026): 20 lần thay chữ → đúng +20 vùng
/// `shared memory`. Tạo source mới cho mỗi lần gửi = rò không giới hạn.
final class PrivateEventSourceTests: XCTestCase {
  /// Số vùng `shared memory` của chính tiến trình test, đọc qua `vmmap`.
  private func sharedMemoryRegionCount() -> Int? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/vmmap")
    process.arguments = ["--summary", "\(getpid())"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0,
          let text = String(data: data, encoding: .utf8),
          let row = text.split(separator: "\n").first(where: { $0.hasPrefix("shared memory") }),
          let last = row.split(separator: " ").last
    else { return nil }
    return Int(last)
  }

  func testPrivateEventSourceIsCreatedOnceAndReused() throws {
    guard let first = EventSimulator.privateEventSource() else {
      throw XCTSkip("CGEventSource(.privateState) trả nil trên máy này")
    }
    let second = try XCTUnwrap(EventSimulator.privateEventSource())
    XCTAssertTrue(first === second,
      "mỗi lần gửi phải dùng LẠI một source; source mới = một trang 16 KB SkyLight giữ mãi")
    XCTAssertEqual(first.sourceStateID.rawValue, second.sourceStateID.rawValue)
    // Bộ lọc self-event ở EventHook bỏ qua mọi event có stateID != 1 (hidSystemState).
    XCTAssertNotEqual(first.sourceStateID.rawValue, CGEventSourceStateID.hidSystemState.rawValue,
      "source dùng chung vẫn phải là private — stateID 1 thì vkey tự xử lý lại phím của chính nó")
  }

  func testRepeatedSendsDoNotMapNewSharedMemory() throws {
    guard let before = sharedMemoryRegionCount() else {
      throw XCTSkip("không chạy được vmmap để đếm shared memory")
    }
    for _ in 0..<40 { _ = EventSimulator.privateEventSource() }
    guard let after = sharedMemoryRegionCount() else {
      throw XCTSkip("không chạy được vmmap để đếm shared memory")
    }
    XCTAssertLessThan(after - before, 5,
      "40 lần lấy nguồn phím làm tăng \(after - before) vùng shared memory — "
        + "đang tạo `.privateState` mới mỗi lần (rò 16 KB/lần, xem CGSEventSourceCache)")
  }

  /// Lưới ở mức NGUỒN: mọi đường gửi phải lấy source qua `privateEventSource()`.
  /// Một `CGEventSource(stateID: .privateState)` viết thẳng ở chỗ khác là mở lại
  /// đúng lỗ rò này.
  func testNoSendPathCreatesItsOwnPrivateSource() throws {
    let appRoot = vkeyRepoRootURL().appendingPathComponent("vkey")
    guard let walker = FileManager.default.enumerator(atPath: appRoot.path) else {
      throw XCTSkip("không đọc được \(appRoot.path) — lưới bổ sung, bỏ qua")
    }
    var sites: [String] = []
    for case let rel as String in walker where rel.hasSuffix(".swift") {
      guard let text = try? String(contentsOf: appRoot.appendingPathComponent(rel), encoding: .utf8)
      else { continue }
      for (n, line) in text.components(separatedBy: "\n").enumerated() {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("//") || t.hasPrefix("*") { continue }
        if line.contains("CGEventSource(stateID: .privateState)") { sites.append("\(rel):\(n + 1)") }
      }
    }
    XCTAssertEqual(sites.count, 1,
      "chỉ `EventSimulator.privateEventSource()` được tạo nguồn `.privateState`. Thấy: \(sites)")
    XCTAssertTrue(sites.first?.hasPrefix("Platform/EventSimulator.swift:") ?? false,
      "…và chỗ đó phải nằm trong Platform/EventSimulator.swift. Thấy: \(sites)")
  }
}


// MARK: - Mã phím của event CHỈ mang chuỗi Unicode

/// v4.32 đổi `KeyCode.unicodeOnly` từ 0 sang 0xFF để "không sinh ký tự", nhưng
/// 0xFF không phải mã phím ảo hợp lệ: app bỏ im lặng CẢ event, nên mọi chữ vkey
/// gửi biến mất. Backspace (0x33) vẫn hợp lệ nên vẫn xoá chữ cũ → dấu không ra,
/// mất chữ giữa/cuối, mất cả cụm, ở MỌI app.
///
/// Đo 09/10/2026 bằng `Tools/probe/kcsweep.swift` (event `.privateState`, đúng
/// loại vkey tự phát), gửi vào TextEdit (AppKit) và ô `<input>` trong Chrome
/// (Blink, đọc lại bằng `Tools/probe/cdp.mjs`):
///   - tới được cả hai: 0, 10, 90, 110
///   - mất trắng: 64 (F17), 79 (F18), 80 (F19), 106 (F16), 126 (Up) — AppKit
///     dịch thành phím chức năng, `characters` rỗng
///   - mất trắng: 255 (0xFF) — ngoài dải 7 bit của virtual keycode
///
/// Hai test dưới chặn đúng hai nhóm đó mà không cần allowlist cứng.
final class UnicodeOnlyKeyCodeTests: XCTestCase {
  func testUnicodeOnlyKeyCodeFitsSevenBits() {
    XCTAssertLessThanOrEqual(
      EventSimulator.KeyCode.unicodeOnly, 0x7F,
      "mã phím ảo chỉ 7 bit; mã lớn hơn (0xFF ở v4.32) làm app bỏ cả event → mất chữ")
  }

  func testUnicodeOnlyEventCarriesTheStringAndIsNotAFunctionKey() throws {
    guard let source = EventSimulator.privateEventSource() else {
      throw XCTSkip("CGEventSource(.privateState) trả nil trên máy này")
    }
    let event = try XCTUnwrap(
      CGEvent(
        keyboardEventSource: source, virtualKey: EventSimulator.KeyCode.unicodeOnly,
        keyDown: true),
      "không dựng được event với mã phím \(EventSimulator.KeyCode.unicodeOnly)")
    EventSimulator.applyUnicodePayload(event, units: Array("ề".utf16).map { UniChar($0) })

    let translated = try XCTUnwrap(
      NSEvent(cgEvent: event), "AppKit không dịch được event chỉ mang Unicode")
    XCTAssertEqual(
      translated.characters, "ề",
      "chuỗi Unicode phải đi qua được tầng AppKit; rỗng = app sẽ không chèn gì")
    XCTAssertFalse(
      translated.modifierFlags.contains(.function),
      "mã phím chức năng (F16–F20, mũi tên) bị NSTextView nuốt, chữ không vào ô nhập")
  }
}


// MARK: - Đợt 2 sau 4.34: điều khiển máy từ xa, cách gửi phím theo app

final class RemoteDesktopAndSendingModeTests: XCTestCase {

  // MARK: Đứng ngoài trong app điều khiển máy từ xa

  func testStandsAsideInRemoteDesktopViewersUnlessUserAsksForVietnamese() throws {
    func aside(_ bundle: String?, _ state: AppSmartSwitchState? = nil) -> Bool {
      EventHook.standsAsideForRemoteDesktop(frontmostBundle: bundle, userState: state)
    }
    XCTAssertTrue(aside("com.apple.ScreenSharing"))
    XCTAssertTrue(aside("com.apple.ScreenContinuity"), "iPhone Mirroring")
    XCTAssertTrue(aside("com.philandro.anydesk"))
    XCTAssertTrue(aside("com.carriez.rustdesk"))
    XCTAssertTrue(aside("com.apple.ScreenSharing", .englishMode), "EN/Tắt: vẫn đứng ngoài")
    XCTAssertTrue(aside("com.apple.ScreenSharing", .disabled))
    XCTAssertFalse(
      aside("com.apple.ScreenSharing", .vietnameseMode),
      "người dùng muốn gõ dấu từ máy này (máy kia không có bộ gõ)")

    XCTAssertFalse(aside("com.google.Chrome"))
    XCTAssertFalse(aside("com.parallels.desktop.console"), "máy ảo cố ý không nằm trong danh sách")
    XCTAssertFalse(aside("com.apple.ScreenSharingAgent"), "khớp chính xác, không theo tiền tố")
    XCTAssertFalse(aside(nil))
  }

  /// Không tra cấu hình Smart Switch cho app thường — hàm này chạy ở mỗi event.
  func testStandAsideCheckDoesNotLookUpConfigForOrdinaryApps() throws {
    var lookups = 0
    func state() -> AppSmartSwitchState? { lookups += 1; return nil }
    _ = EventHook.standsAsideForRemoteDesktop(frontmostBundle: "com.google.Chrome", userState: state())
    _ = EventHook.standsAsideForRemoteDesktop(frontmostBundle: nil, userState: state())
    XCTAssertEqual(lookups, 0)
    _ = EventHook.standsAsideForRemoteDesktop(frontmostBundle: "com.apple.ScreenSharing", userState: state())
    XCTAssertEqual(lookups, 1)
  }

  // MARK: Cách gửi phím theo app

  private func name(_ strategy: SendingStrategy) -> String {
    switch strategy {
    case .batch: return "batch"
    case .stepByStep: return "stepByStep"
    case .hybrid(let delay): return "hybrid(\(delay))"
    case .axDirect: return "axDirect"
    }
  }

  func testUserSendingModeOverridesTheBuiltInTable() throws {
    func resolved(_ bundle: String, _ mode: AppSendingMode?) -> String {
      name(EventSimulator.resolveStrategy(for: bundle, userMode: mode))
    }
    // Không chọn gì: bảng dựng sẵn.
    XCTAssertEqual(resolved("com.example.unknown", nil), "hybrid(800)")
    XCTAssertEqual(resolved("com.vng.zalo", nil), "stepByStep")
    XCTAssertEqual(resolved("com.microsoft.Word", nil), "hybrid(1000)")

    // Người dùng chọn: thắng bảng, cả hai chiều.
    XCTAssertEqual(resolved("com.example.unknown", .stepByStep), "stepByStep")
    XCTAssertEqual(resolved("com.example.unknown", .paced), "hybrid(2000)")
    XCTAssertEqual(resolved("com.vng.zalo", .fast), "batch")

    // Spotlight đi AX: lựa chọn của người dùng không được kéo nó về event.
    XCTAssertEqual(resolved("com.apple.Spotlight", nil), "axDirect")
    XCTAssertEqual(resolved("com.apple.Spotlight", .stepByStep), "axDirect")
  }

  /// "Có nhịp nghỉ" / "Từng phím" do người dùng chọn phải giữ nhịp nghỉ cả ở
  /// transform 1 ký tự — nhóm phím phổ biến nhất; nếu không lựa chọn gần như
  /// vô tác dụng. "Nhanh" và app không chọn gì giữ hành vi cũ.
  func testUserChosenPacingKeepsItsCushionOnSmallDiffs() throws {
    func keeps(_ bundle: String, _ mode: AppSendingMode?) -> Bool {
      InputProcessor.keepsCushionOnSmallDiffs(bundleId: bundle, userMode: mode)
    }
    XCTAssertFalse(keeps("com.example.app", nil))
    XCTAssertTrue(keeps("com.htl.plume", nil), "ngoại lệ dựng sẵn giữ nguyên")
    XCTAssertTrue(keeps("com.example.app", .paced))
    XCTAssertTrue(keeps("com.example.app", .stepByStep))
    XCTAssertFalse(keeps("com.example.app", .fast))
    XCTAssertFalse(keeps("com.htl.plume", .fast), "người dùng chọn Nhanh thì theo người dùng")
  }

  func testSendingModesSurviveABackupRoundTripAndIgnoreUnknownValues() throws {
    Defaults[.appSendingModes] = ["com.example.app": .stepByStep]
    defer { Defaults.reset(.appSendingModes) }

    let export = UserDataMigration.currentExport(includeStatistics: false)
    XCTAssertEqual(export.appSendingModes, ["com.example.app": "stepByStep"])
    let data = try JSONEncoder().encode(export)
    let decoded = try JSONDecoder().decode(UserDataExport.self, from: data)
    XCTAssertEqual(decoded.appSendingModes, ["com.example.app": "stepByStep"])

    // Tệp mang một giá trị lạ (bản mới hơn ghi): bỏ qua mục đó, giữ mục hợp lệ.
    Defaults[.appSendingModes] = ["com.kept.app": .fast]
    let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    var patched = object
    patched["appSendingModes"] = ["com.example.app": "paced", "com.other.app": "warp-speed"]
    let imported = try JSONDecoder().decode(
      UserDataExport.self, from: JSONSerialization.data(withJSONObject: patched))
    UserDataMigration.importExport(imported, replaceLists: false)
    XCTAssertEqual(
      Defaults[.appSendingModes], ["com.kept.app": .fast, "com.example.app": .paced],
      "gộp: giữ mục đang có, nhận mục hợp lệ từ tệp, bỏ giá trị lạ")
  }

  func testOldBackupWithoutSendingModesStillImports() throws {
    Defaults[.appSendingModes] = ["com.kept.app": .paced]
    defer { Defaults.reset(.appSendingModes) }
    let data = try JSONEncoder().encode(UserDataMigration.currentExport(includeStatistics: false))
    var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "appSendingModes")
    // Mục của tính năng đã gỡ trong tệp từ 4.34 trở về trước phải bị bỏ qua êm.
    object["clipboardHistoryEnabled"] = true
    object["wordPredictionEnabled"] = true
    object["windowTitleRules"] = [["name": "Docs"]]
    object["modifierOnlyTextToolsHotkey"] = 123
    let old = try JSONDecoder().decode(
      UserDataExport.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(old.appSendingModes)
    UserDataMigration.importExport(old, replaceLists: true)
    XCTAssertEqual(Defaults[.appSendingModes], ["com.kept.app": .paced], "tệp không có mục này thì không đụng")
  }
}
