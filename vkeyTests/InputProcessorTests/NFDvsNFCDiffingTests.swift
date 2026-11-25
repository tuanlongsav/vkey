import XCTest
import Defaults
@testable import vkey

// MARK: - ===========================================
// MARK: - NFD vs NFC Diffing Tests
// MARK: - ===========================================

final class NFDvsNFCDiffingTests: XCTestCase {
  func testPopBehaviorNFCvsNFD() throws {
    // 1. NFC app (default for Apple Notes)
    let nfcProcessor = InputProcessor(method: .Telex)
    nfcProcessor.changeActiveApp("com.apple.Notes")
    nfcProcessor.push(char: "g")
    nfcProcessor.push(char: "o")
    nfcProcessor.push(char: "o")  // "gô"
    XCTAssertEqual(nfcProcessor.transformed, "gô")
    
    // Pop (delete last 'o' to get "go")
    let (nfcBs, nfcDiff) = nfcProcessor.pop(usesNFC: nfcProcessor.usesNFCForFocusedField())
    XCTAssertEqual(nfcBs, 1) // deletes "ô"
    XCTAssertEqual(nfcDiff, ["o"]) // re-types "o"
    
    // 2. NFD app (Electron). 4.21: Chrome KHÔNG còn dùng được làm ví dụ NFD —
    // web content của trình duyệt đã chuyển sang NFC. Electron vẫn giữ NFD.
    let nfdProcessor = InputProcessor(method: .Telex)
    nfdProcessor.changeActiveApp("com.tinyspeck.slackmacgap")
    nfdProcessor.push(char: "g")
    nfdProcessor.push(char: "o")
    nfdProcessor.push(char: "o")  // "gô"
    XCTAssertEqual(nfdProcessor.transformed, "gô")
    
    // Pop (delete last 'o' to get "go")
    let (nfdBs, nfdDiff) = nfdProcessor.pop(usesNFC: nfdProcessor.usesNFCForFocusedField())
    XCTAssertEqual(nfdBs, 0, "NFD should let the OS handle backspace (numBackspaces = 0)")
    XCTAssertEqual(nfdDiff, [], "NFD should not need to retype any character")
  }

  func testGeminiAppUsesNFC() throws {
    // v3.6: bundle ID THẬT của Gemini app là com.google.GeminiMacOS
    // (v3.4 ghi nhầm com.google.gemini → rơi về NFD → "nhập" → "nḥ̂p").
    // Check lowercased prefix nên cả hai biến thể đều phải pass.
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.GeminiMacOS"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.gemini"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.Chrome"))

    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.google.GeminiMacOS")

    // Type "nhân"
    processor.push(char: "n")
    processor.push(char: "h")
    processor.push(char: "a")
    processor.push(char: "a")
    processor.push(char: "n")
    XCTAssertEqual(processor.transformed, "nhân")
  }

  func testNativeTextEditorsUseNFCGraphemeStorage() throws {
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.sublimetext.4"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.sublimetext.3"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.barebones.bbedit"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.macromates.TextMate"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "org.vim.MacVim"))
    XCTAssertTrue(InputProcessor.usesNFCGraphemeStorage(bundleId: "net.nemetschek.vectorworks.2024"))
    XCTAssertFalse(InputProcessor.usesNFCGraphemeStorage(bundleId: "com.google.Chrome"))
  }

  /// v4.2: Sublime/BBEdit lưu grapheme NFC — pop phải giống Notes (bs=1),
  /// không phải NFD (bs=0) vì NFD diff gây backspace thừa / nuốt newline.
  func testSublimeTextPopUsesNFCGraphemeBackspace() throws {
    let sublime = InputProcessor(method: .Telex)
    sublime.changeActiveApp("com.sublimetext.4")
    sublime.push(char: "g")
    sublime.push(char: "o")
    sublime.push(char: "o")
    XCTAssertEqual(sublime.transformed, "gô")
    let (sublimeBs, sublimeDiff) = sublime.pop(usesNFC: sublime.usesNFCForFocusedField())
    XCTAssertEqual(sublimeBs, 1, "Sublime must NFC-pop like Notes")
    XCTAssertEqual(sublimeDiff, ["o"])

    // Đối chứng NFD. 4.21: dùng Electron thay Chrome — trình duyệt đã sang NFC.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp("com.tinyspeck.slackmacgap")
    electron.push(char: "g")
    electron.push(char: "o")
    electron.push(char: "o")
    let (electronBs, electronDiff) = electron.pop(usesNFC: electron.usesNFCForFocusedField())
    XCTAssertEqual(electronBs, 0, "Electron vẫn NFD-pop")
    XCTAssertEqual(electronDiff, [])
  }

  /// v4.15: emit-form phải khớp field-form. `emittedCharacters` precompose khi
  /// field NFC (ô tìm kiếm khớp text precomposed) và GIỮ NGUYÊN combining mark
  /// khi field NFD — ép NFC vào field NFD là gốc bug "gửi"→"ửi" (mất chữ đầu).
  func testEmittedCharactersFollowsFieldNormalization() throws {
    let nfd = Array("e\u{0301}o\u{0300}")  // "é" + "ò" dạng NFD (base + combining)
    XCTAssertNotEqual(
      Array(String(nfd).utf16),
      Array("éò".utf16),
      "Sanity: NFD và NFC khác nhau trước khi chuẩn hoá"
    )

    // Field NFC → precompose: "éò" mỗi ký tự 1 UTF-16 unit, không còn combining.
    let nfc = EventSimulator.emittedCharacters(nfd, normalizeToNFC: true)
    XCTAssertEqual(String(nfc), "éò")
    XCTAssertEqual(String(nfc).utf16.count, 2)
    XCTAssertFalse(
      String(nfc).unicodeScalars.contains { $0.value == 0x0301 || $0.value == 0x0300 },
      "Field NFC không được phát combining mark"
    )

    // Field NFD → giữ NGUYÊN combining mark (số scalar không đổi → khớp backspace).
    let raw = EventSimulator.emittedCharacters(nfd, normalizeToNFC: false)
    XCTAssertEqual(raw, nfd)
    XCTAssertTrue(
      String(raw).unicodeScalars.contains { $0.value == 0x0301 },
      "Field NFD phải giữ combining mark như calcKeyStrokesNFD đã tính"
    )
  }


  func testNFDDiffNeverStartsWithBareCombiningMark() throws {
    // "nhâ" → "nhậ": NFD to = [n,h,a,◌̣,◌̂] — diff thô là [◌̣,◌̂] (dấu trần).
    // Phải snap về đầu cụm: xoá 2 scalar (◌̂, a), retype "ậ" hoàn chỉnh.
    let (bs1, diff1) = EventSimulator.calcKeyStrokesNFD(from: "nhâ", to: "nhậ")
    XCTAssertEqual(bs1, 2)
    XCTAssertEqual(diff1, ["ậ"])

    // Chiều ngược (xoá dấu nặng): cũng phải retype nguyên cụm "â".
    let (bs2, diff2) = EventSimulator.calcKeyStrokesNFD(from: "nhậ", to: "nhâ")
    XCTAssertEqual(bs2, 3)
    XCTAssertEqual(diff2, ["â"])

    // Thêm dấu vào chữ không dấu: "đi" → "đị" — retype "ị" hoàn chỉnh.
    let (bs3, diff3) = EventSimulator.calcKeyStrokesNFD(from: "đi", to: "đị")
    XCTAssertEqual(bs3, 1)
    XCTAssertEqual(diff3, ["ị"])

    // Diff RỖNG (chỉ xoá) giữ nguyên — không snap, pop vẫn nhường OS xử lý.
    let (bs4, diff4) = EventSimulator.calcKeyStrokesNFD(from: "gô", to: "go")
    XCTAssertEqual(bs4, 1)
    XCTAssertEqual(diff4, [])
  }

  /// v3.9: kiểu diff theo FieldKind trong app nhóm NFD.
  /// - webContent → NFD (pop "gô"→"go" nhường OS = (0, []))
  /// - nativePanel (NSSavePanel) → NFC = (1, ["o"])
  /// - windowField → NFC = (1, ["o"]) — dùng kèm axDirect ở runtime
  ///
  /// 4.21: đổi ví dụ từ Chrome sang Electron. Trình duyệt giờ NFC ở MỌI
  /// fieldKind nên không còn phân biệt được ba nhánh này; Electron thì còn.
  func testFieldKindDiffSelectionInNFDGroupApp() throws {
    let processor = InputProcessor(method: .Telex)
    processor.changeActiveApp("com.tinyspeck.slackmacgap")

    // Web content: NFD — pop "gô"→"go" nhường OS (0, []).
    processor.focusedFieldKind = .webContent
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (webBs, webDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(webBs, 0)
    XCTAssertEqual(webDiff, [])

    // Save panel (hộp thoại modal native): NFC — pop "gô"→"go" = (1, ["o"]).
    processor.newWord()
    processor.focusedFieldKind = .nativePanel
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (panelBs, panelDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(panelBs, 1)
    XCTAssertEqual(panelDiff, ["o"])

    // Omnibox (windowField của app NFD): NFC grapheme = (1, ["o"]) — vì
    // axDeleteStart của axDirect đếm theo grapheme. Cũng là browser-chrome.
    processor.newWord()
    processor.focusedFieldKind = .windowField
    XCTAssertTrue(processor.focusedFieldIsBrowserChrome())
    processor.push(char: "g")
    processor.push(char: "o")
    processor.push(char: "o")
    XCTAssertEqual(processor.transformed, "gô")
    let (omniBs, omniDiff) = processor.pop(usesNFC: processor.usesNFCForFocusedField())
    XCTAssertEqual(omniBs, 1)
    XCTAssertEqual(omniDiff, ["o"])

    // windowField trong app NFC-whitelist (vd Notes) KHÔNG phải browser-chrome
    // → không ép axDirect.
    processor.changeActiveApp("com.apple.Notes")
    processor.focusedFieldKind = .windowField
    XCTAssertFalse(processor.focusedFieldIsBrowserChrome())
  }

  /// Regression (Telegram/ChatGPT "điều"→"đều", mất chữ "i"): app native NFC
  /// grapheme-delete mà AX phân loại field thành .unknown (cảnh AX thật lỗi)
  /// PHẢI được định tuyến NFC — nếu không, NFD scalar-diff backspace thừa ở phím
  /// dấu của cụm nguyên âm mở → xóa nhầm chữ giữa. Khóa TẦNG EMIT (không chỉ
  /// engine): (1) số học diff thật, (2) predicate định tuyến, (3) gõ trọn từ.
  /// Nếu ai đó gỡ whitelist mà giữ nguyên test engine, test này vẫn phải FAIL.
  func testTelegramChatGPTRouteThroughNFC() throws {
    // (1) Số học tầng emit — chính là chỗ lỗi: điêu→điều.
    //     NFC (grapheme) xóa 2 grapheme (u, ê); NFD (scalar) đếm THỪA thành 3 →
    //     app xóa-grapheme sẽ xóa nhầm cả "i" → "đều".
    let (nfcBs, _) = EventSimulator.calcKeyStrokes(from: "điêu", to: "điều")
    XCTAssertEqual(nfcBs, 2, "NFC grapheme diff: backspace 2 (u, ê)")
    let (nfdBs, _) = EventSimulator.calcKeyStrokesNFD(from: "điêu", to: "điều")
    XCTAssertEqual(nfdBs, 3, "NFD scalar diff đếm thừa (3) → phá app grapheme")

    // (2)+(3) Telegram & ChatGPT với field .unknown vẫn PHẢI dùng NFC (nhờ
    //     whitelist short-circuit) và gõ ra "điều" nguyên vẹn.
    for app in ["ru.keepcoder.Telegram", "com.openai.chat"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(app)
      p.focusedFieldKind = .unknown
      XCTAssertTrue(p.usesNFCForFocusedField(), "\(app): field .unknown vẫn phải NFC")
      for c in "ddieeuf" { p.push(char: c) }
      XCTAssertEqual(p.transformed, "điều", "\(app): gõ ddieeuf phải ra điều")
    }

    // Đối chứng: app NFD thật KHÔNG bị kéo sang NFC. 4.21: dùng Electron —
    // Chrome đã sang NFC nên không còn là ví dụ NFD hợp lệ.
    let electron = InputProcessor(method: .Telex)
    electron.changeActiveApp("com.tinyspeck.slackmacgap")
    electron.focusedFieldKind = .webContent
    XCTAssertFalse(electron.usesNFCForFocusedField(), "Electron web content giữ NFD")
  }

  /// 4.21: bỏ công tắc thủ công của 4.16 — web content của TRÌNH DUYỆT dùng
  /// NFC tự động. Cơ sở là phép đo thật: Chrome giữ nguyên NFC ở <input>,
  /// <input type=search> và contenteditable; Google Docs LƯU NFC (copy ra đếm
  /// 22 scalar precomposed, NFD sẽ là 29) chứ không phải NFD như 4.16 phỏng đoán.
  func testBrowserWebContentUsesNFC() throws {
    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp("com.google.Chrome")
    chrome.focusedFieldKind = .webContent
    XCTAssertTrue(chrome.usesNFCForFocusedField(), "web content của Chrome phải NFC")
    chrome.focusedFieldKind = .windowField
    XCTAssertTrue(chrome.usesNFCForFocusedField(), "thanh địa chỉ Chrome vẫn NFC")

    // Kênh beta/canary khớp theo prefix.
    for bundle in ["com.google.Chrome.beta", "com.google.Chrome.canary",
                   "com.brave.Browser.nightly", "com.microsoft.edgemac.Dev"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(bundle)
      p.focusedFieldKind = .webContent
      XCTAssertTrue(p.usesNFCForFocusedField(), "\(bundle) phải NFC")
    }
  }

  /// `.unknown` phải ĐI CÙNG trục với `.webContent` trong cùng một app: AX
  /// timeout làm fieldKind rơi về .unknown giữa chừng, hai case khác trục thì
  /// một từ đang gõ bị đổi trục giữa dòng — đúng lớp lỗi 4.14.
  func testUnknownFieldKindMatchesWebContentAxisPerApp() throws {
    let chrome = InputProcessor(method: .Telex)
    chrome.changeActiveApp("com.google.Chrome")
    chrome.focusedFieldKind = .webContent
    let web = chrome.usesNFCForFocusedField()
    chrome.focusedFieldKind = .unknown
    XCTAssertEqual(chrome.usesNFCForFocusedField(), web, "Chrome: .unknown phải cùng trục .webContent")

    let slack = InputProcessor(method: .Telex)
    slack.changeActiveApp("com.tinyspeck.slackmacgap")
    slack.focusedFieldKind = .webContent
    let slackWeb = slack.usesNFCForFocusedField()
    slack.focusedFieldKind = .unknown
    XCTAssertEqual(slack.usesNFCForFocusedField(), slackWeb, "Slack: .unknown phải cùng trục .webContent")
  }

  /// Phạm vi hẹp có chủ đích: Electron cũng là web content nhưng CHƯA đo, nên
  /// giữ NFD như trước. Đây đúng là chỗ công tắc 4.16 phóng quá tay — nó bật
  /// NFC cho mọi app ngoài whitelist, kể cả Slack/Zalo/Telegram.
  func testNonBrowserWebViewsStayNFD() throws {
    for bundle in ["com.tinyspeck.slackmacgap", "com.hnc.Discord",
                   "com.anthropic.claudefordesktop", "com.vng.zalo"] {
      let p = InputProcessor(method: .Telex)
      p.changeActiveApp(bundle)
      p.focusedFieldKind = .webContent
      XCTAssertFalse(p.usesNFCForFocusedField(), "\(bundle) (Electron) giữ NFD")
    }
  }

  /// Đối chứng: app Apple vẫn NFC nhờ whitelist grapheme-storage, không liên
  /// quan gì tới luật trình duyệt mới.
  func testAppleAppsStillNFCViaWhitelist() throws {
    let notes = InputProcessor(method: .Telex)
    notes.changeActiveApp("com.apple.Notes")
    notes.focusedFieldKind = .webContent
    XCTAssertTrue(notes.usesNFCForFocusedField(), "Notes NFC nhờ whitelist")
  }
}
