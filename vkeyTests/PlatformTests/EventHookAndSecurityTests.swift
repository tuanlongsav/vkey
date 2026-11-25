import XCTest
import AppKit
import Defaults
@testable import vkey

final class EventHookHotkeyAndSecurityTests: SpellResetTestCase {
  func testModifierOnlyHotkeyTogglesAfterPurePressAndFullRelease() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: control, modifierTarget: target)
    )
    XCTAssertTrue(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }

  /// Gõ qua Screen Sharing: phím từ ScreensharingAgent (stateID riêng, khác 1)
  /// phải được xử lý như phím thật; phím vkey tự phát và phím tổng hợp của app
  /// khác vẫn bị bỏ. Số liệu lấy từ lần đo thật trên Mac Studio 2026-11-01.
  func testScreenSharingKeysCountAsUserInputButSyntheticOnesDoNot() throws {
    let agent =
      "/System/Library/CoreServices/RemoteManagement/ScreensharingAgent.bundle/Contents/MacOS/ScreensharingAgent"
    let paths: [pid_t: String] = [
      56629: agent,
      700: "/Applications/Keyboard Maestro.app/Contents/MacOS/Keyboard Maestro Engine",
      800: "/tmp/ScreensharingAgent.bundle/Contents/MacOS/ScreensharingAgent",
    ]
    let own = getpid()
    func check(_ stateID: Int64, _ pid: pid_t) -> Bool {
      EventHook.isUserInputSource(stateID: stateID, sourcePID: pid, ownPID: own) { paths[$0] }
    }

    XCTAssertTrue(check(1, 0), "bàn phím thật (HID)")
    XCTAssertTrue(check(2007905771, 56629), "Screen Sharing")
    XCTAssertFalse(check(0, own), "vkey tự phát (combinedSessionState)")
    XCTAssertFalse(check(123456, own), "vkey tự phát (privateState)")
    XCTAssertFalse(check(123456, 700), "app khác tự phát phím")
    XCTAssertFalse(check(123456, 800), "giả dạng ngoài /System")
    XCTAssertFalse(check(123456, 999), "pid không còn tồn tại")
  }

  /// Ổ khoá kẹt qua Screen Sharing: phím từ ScreensharingAgent có stateID ≠ 1
  /// nên callback tap bỏ trước khi kịp kiểm lại secure input. Watchdog phải
  /// tự gỡ khi cờ hệ thống đã tắt — và KHÔNG được gỡ khi cờ còn bật.
  func testStaleSecureInputIsClearedOnlyWhenSystemFlagIsOff() throws {
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))
    hook.secureInputOwnerPID = 1131

    XCTAssertFalse(hook.reconcileSecureInput(systemFlag: true, lockShown: true))
    XCTAssertEqual(hook.secureInputOwnerPID, 1131)

    XCTAssertFalse(hook.reconcileSecureInput(systemFlag: false, lockShown: false))
    XCTAssertNil(hook.secureInputOwnerPID)

    hook.secureInputOwnerPID = 1131
    XCTAssertTrue(hook.reconcileSecureInput(systemFlag: false, lockShown: true))
    XCTAssertNil(hook.secureInputOwnerPID)
  }

  func testModifierOnlyHotkeyDoesNotToggleWhenExtraModifierIsAdded() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let option = UInt64(NSEvent.ModifierFlags.option.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(
        type: .flagsChanged,
        currentMods: target | option,
        modifierTarget: target
      )
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }

  func testModifierOnlyHotkeyDoesNotToggleAfterInterveningKeyDown() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let target = control | shift
    let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))

    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .keyDown, currentMods: target, modifierTarget: target)
    )
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target)
    )
  }

  /// ⇧⌥-click / ⌃⇧-click là dùng modifier cho chuột, không phải bấm-thả trơn.
  func testModifierOnlyHotkeyDoesNotToggleAfterInterveningClick() throws {
    let control = UInt64(NSEvent.ModifierFlags.control.rawValue)
    let shift = UInt64(NSEvent.ModifierFlags.shift.rawValue)
    let target = control | shift

    for click in [CGEventType.leftMouseDown, .rightMouseDown] {
      let hook = EventHook(inputProcessor: InputProcessor(method: .Telex))
      XCTAssertFalse(
        hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: target, modifierTarget: target)
      )
      XCTAssertFalse(
        hook.handleModifierOnlyHotkey(type: click, currentMods: target, modifierTarget: target)
      )
      XCTAssertFalse(
        hook.handleModifierOnlyHotkey(type: .flagsChanged, currentMods: 0, modifierTarget: target),
        "click \(click.rawValue) while holding the combo must not fire the hotkey"
      )
    }
  }

}

// MARK: - Rà soát "mất gõ tiếng Việt" (2026-11-10)

/// Các đường làm vkey thôi bỏ dấu hoặc xoá nhầm chữ mà không liên quan engine:
/// tap bị hệ thống tắt, Smart Switch tra nhầm app, secure input do app nền giữ,
/// và hai bộ gõ cùng biến đổi một chuỗi phím qua Screen Sharing.
final class TypingLossReviewTests: XCTestCase {

  // MARK: Tap bị tắt rồi bật lại

  /// Trong lúc tap tắt, phím đi thẳng vào app nên bộ đệm không còn khớp màn
  /// hình. Bật lại tap phải bắt đầu từ mới, không diff tiếp trên từ cũ.
  func testTapRecoveryStartsANewWord() throws {
    let processor = InputProcessor(method: .Telex)
    for ch in "vie" { processor.push(char: ch) }
    XCTAssertEqual(processor.transformed, "vie")
    processor.hardwareShiftDown = !CGEventSource.flagsState(.hidSystemState).contains(.maskShift)

    let hook = EventHook(inputProcessor: processor)
    hook.resyncAfterTapGap()

    XCTAssertTrue(processor.keys.isEmpty, "từ dở trước lúc tap tắt phải bị bỏ")
    XCTAssertEqual(processor.transformed, "")
    XCTAssertNil(processor.previousWordState, "Backspace sau đó không được dựng lại từ cũ")
    XCTAssertEqual(
      processor.hardwareShiftDown,
      CGEventSource.flagsState(.hidSystemState).contains(.maskShift),
      "Shift phải được đọc lại — watchdog trước đây bỏ sót bước này")

    // Phím gõ tiếp là phím đầu của một từ mới: không backspace nào được phát.
    processor.push(char: "j")
    let (backspaces, _) = EventSimulator.calcKeyStrokes(
      from: processor.lastTransformed, to: processor.transformed, usesNFC: true)
    XCTAssertEqual(backspaces, 0, "không được xoá vào chữ đã lọt qua lúc tap tắt")
  }

  /// `recoverTap()` không có tap để bật thì không làm gì (và không đếm nhầm).
  func testRecoverTapWithoutTapIsNoOp() throws {
    let processor = InputProcessor(method: .Telex)
    for ch in "vie" { processor.push(char: ch) }
    let hook = EventHook(inputProcessor: processor)
    hook.recoverTap()
    XCTAssertEqual(hook.tapRecoveryCount, 0)
    XCTAssertEqual(processor.transformed, "vie")
  }

  // MARK: Smart Switch

  private func config(_ state: AppSmartSwitchState) -> AppSmartSwitchConfig {
    AppSmartSwitchConfig(state: state, source: .autoLearn)
  }

  func testOnlyVietnameseModeEnablesTyping() throws {
    XCTAssertTrue(AppSmartSwitchState.vietnameseMode.enablesVietnamese)
    XCTAssertFalse(AppSmartSwitchState.englishMode.enablesVietnamese)
    XCTAssertFalse(AppSmartSwitchState.disabled.enablesVietnamese)
  }

  /// Danh sách "tắt VN" đời cũ được chuyển sang cấu hình 3 trạng thái: app
  /// chưa có cấu hình thành `englishMode`, app đã có cấu hình giữ nguyên.
  func testLegacySmartSwitchListMergesIntoConfigsWithoutOverwriting() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let existing = ["com.google.Chrome": config(.vietnameseMode)]
    let merged = AppState.mergingLegacySmartSwitchApps(
      ["com.google.Chrome", "com.apple.Terminal"], into: existing, now: now)

    XCTAssertEqual(merged["com.google.Chrome"], existing["com.google.Chrome"], "cấu hình đã có thắng")
    XCTAssertEqual(merged["com.apple.Terminal"]?.state, .englishMode)
    XCTAssertEqual(merged["com.apple.Terminal"]?.source, .user)
    XCTAssertEqual(merged["com.apple.Terminal"]?.lastModified, now)
    XCTAssertEqual(merged.count, 2)
    XCTAssertEqual(
      AppState.mergingLegacySmartSwitchApps([], into: existing, now: now), existing)
  }

  /// Hộp thoại Lưu chạy ở tiến trình ngoài; AX trả bundle của nó chứ không phải
  /// app cha. Tra cấu hình bằng bundle thô ra "không có cấu hình" → Smart Switch
  /// tự gỡ giữa lúc gõ tên file. Phải tra bằng app đã quy chuẩn.
  func testSmartSwitchLooksUpTheCanonicalAppNotTheHelperProcess() throws {
    let configs = ["com.google.Chrome": config(.vietnameseMode)]
    func desired(focused: String) -> Bool? {
      let app = InputProcessor.canonicalAppBundle(focused: focused, frontmost: "com.google.Chrome")
      return configs[app]?.state.enablesVietnamese
    }

    XCTAssertEqual(desired(focused: "com.google.Chrome"), true)
    XCTAssertEqual(desired(focused: "com.apple.appkit.xpc.openAndSavePanelService"), true)
    XCTAssertEqual(desired(focused: "com.google.Chrome.helper"), true)
    XCTAssertNil(desired(focused: "com.apple.Spotlight"), "overlay là app khác thật")
  }

  // MARK: Secure input

  /// Chỉ coi là "app nền giữ" khi CHẮC: app thường, không phải app đang trước
  /// hay tiến trình phụ của nó. Mọi ca mơ hồ phải rơi về cách hiểu an toàn (app
  /// đang trước giữ) để vkey không bỏ dấu vào ô mật khẩu.
  func testBackgroundSecureInputHolderIsOnlyAClearlyDifferentRegularApp() throws {
    func isBackground(
      owner: pid_t?, bundle: String? = "com.google.Chrome", regular: Bool = true,
      front: pid_t? = 34995, frontBundle: String? = "com.anthropic.claudefordesktop"
    ) -> Bool {
      EventHook.isBackgroundSecureInputHolder(
        ownerPID: owner, ownerBundle: bundle, ownerIsRegularApp: regular,
        frontmostPID: front, frontmostBundle: frontBundle, ownPID: 77)
    }

    XCTAssertTrue(isBackground(owner: 3788), "Chrome nền, Claude đang trước")
    XCTAssertFalse(isBackground(owner: nil), "không đọc được chủ")
    XCTAssertFalse(isBackground(owner: 34995), "chủ chính là app đang trước")
    XCTAssertFalse(isBackground(owner: 77), "vkey không bao giờ là thủ phạm")
    XCTAssertFalse(
      isBackground(owner: 3788, bundle: nil, regular: false),
      "agent hệ thống (SecurityAgent) hiện hộp mật khẩu trên app đang trước")
    XCTAssertFalse(
      isBackground(
        owner: 3788, bundle: "com.apple.Safari.SandboxBroker", front: 900,
        frontBundle: "com.apple.Safari"),
      "tiến trình phụ của app đang trước")
  }

  // MARK: Screen Sharing — bộ gõ ở cả hai đầu

  func testPrecomposedRemoteTextIsNotReadAsARawKey() throws {
    // Chữ do bộ gõ ở máy điều khiển soạn sẵn.
    XCTAssertTrue(EventHook.isPrecomposedRemoteText("ê"))
    XCTAssertTrue(EventHook.isPrecomposedRemoteText("ệt"))
    XCTAssertTrue(EventHook.isPrecomposedRemoteText("đ"))
    XCTAssertTrue(EventHook.isPrecomposedRemoteText("e\u{0302}"), "dạng NFD")
    XCTAssertTrue(EventHook.isPrecomposedRemoteText("text "), "khôi phục từ tiếng Anh")

    // Phím thô: tối đa một ký tự ASCII, hoặc mã phím chức năng của AppKit.
    XCTAssertFalse(EventHook.isPrecomposedRemoteText(""))
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("a"))
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("A"))
    XCTAssertFalse(EventHook.isPrecomposedRemoteText(" "))
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("\u{7F}"), "Backspace")
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("\r"), "Enter")
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("\u{F702}"), "mũi tên trái")
    XCTAssertFalse(EventHook.isPrecomposedRemoteText("\u{F729}"), "Home")
  }

  /// Event chỉ-mang-Unicode do vkey tự dựng (mã phím 0 = phím A) phải đọc lại
  /// được đúng chuỗi đã gắn — đó là thứ máy được điều khiển dựa vào.
  func testUnicodePayloadRoundTripsThroughAnEvent() throws {
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: EventSimulator.KeyCode.unicodeOnly, keyDown: true))
    EventSimulator.applyUnicodePayload(event, units: Array("ệt".utf16))
    let payload = EventHook.unicodePayload(of: event)
    XCTAssertEqual(payload, "ệt")
    XCTAssertTrue(EventHook.isPrecomposedRemoteText(payload))
  }
}


// MARK: - Chỉ khoá tiếng Việt khi đang ở ô mật khẩu (4.35)

/// Cờ secure input của hệ thống bật không có nghĩa người dùng đang nhập mật
/// khẩu: một tiến trình có thể giữ kẹt. vkey chỉ đứng ngoài khi ô đang focus
/// đúng là ô mật khẩu, hoặc khi không có bằng chứng rằng nó là ô chữ thường.
final class SecureInputLockScopeTests: XCTestCase {
  private let chrome: pid_t = 3788
  private let claude: pid_t = 34995

  private func verdict(
    flag: Bool = true, known: pid_t? = nil, background: pid_t? = nil, front: pid_t?,
    field: Focused.SecureFieldState, terminal: Bool = false
  ) -> (isSecure: Bool, owner: pid_t?) {
    EventHook.resolveSecureInput(
      systemFlag: flag, knownOwner: known, backgroundHolder: background, frontmostPID: front,
      frontField: field, frontmostHidesPasswordPrompts: terminal)
  }

  /// Lỗi cần sửa: Chrome giữ kẹt secure input, người dùng gõ ở một ô chữ thường
  /// NGAY TRONG Chrome. Trước đây khoá vì Chrome vừa là chủ vừa là app đang trước.
  func testStuckHolderInFrontDoesNotLockAPlainTextField() throws {
    let v = verdict(known: chrome, front: chrome, field: .plainText)
    XCTAssertFalse(v.isSecure, "không ở ô mật khẩu thì không khoá tiếng Việt")
    XCTAssertEqual(v.owner, chrome)

    // Cùng ca, chưa từng ghi chủ (mốc cờ vừa bật): vẫn không khoá.
    XCTAssertFalse(verdict(front: chrome, field: .plainText).isSecure)
  }

  func testRealPasswordFieldAlwaysLocks() throws {
    XCTAssertTrue(verdict(known: chrome, front: chrome, field: .secure).isSecure)
    // Chủ là app khác, nhưng app đang trước tự mở ô mật khẩu: quyền chủ chuyển sang nó.
    let moved = verdict(known: chrome, front: claude, field: .secure)
    XCTAssertTrue(moved.isSecure)
    XCTAssertEqual(moved.owner, claude)
  }

  /// Số liệu đo 2026-11-10: Chrome (nền) giữ, đang gõ ở Claude.
  func testBackgroundHolderNeverLocksTheFrontApp() throws {
    for field in [Focused.SecureFieldState.plainText, .unknown] {
      let v = verdict(background: chrome, front: claude, field: field)
      XCTAssertFalse(v.isSecure, "\(field)")
      XCTAssertEqual(v.owner, chrome)
    }
  }

  /// Không có bằng chứng rằng đây là ô chữ thường (AX không trả lời, giao diện
  /// tự vẽ) và app đang trước là chủ: giữ cách xử lý an toàn cũ — đứng ngoài.
  func testUnknownFieldInTheOwningAppStillLocks() throws {
    XCTAssertTrue(verdict(known: chrome, front: chrome, field: .unknown).isSecure)
    XCTAssertTrue(verdict(front: chrome, field: .unknown).isSecure, "chưa biết chủ: coi app đang trước là chủ")
  }

  /// Terminal: lời nhắc mật khẩu của `sudo` là một vùng chữ thường với AX, nên
  /// "ô chữ thường" không phải bằng chứng là không nhập mật khẩu.
  func testTerminalOwningSecureInputStaysLocked() throws {
    XCTAssertTrue(verdict(known: 900, front: 900, field: .plainText, terminal: true).isSecure)
    // Nhưng terminal KHÔNG phải chủ (app nền giữ) thì gõ bình thường.
    XCTAssertFalse(verdict(known: chrome, front: 900, field: .plainText, terminal: true).isSecure)
  }

  func testSystemFlagOffNeverLocksAndForgetsTheOwner() throws {
    var asked = 0
    func field() -> Focused.SecureFieldState { asked += 1; return .secure }
    let v = EventHook.resolveSecureInput(
      systemFlag: false, knownOwner: chrome, backgroundHolder: chrome, frontmostPID: chrome,
      frontField: field(), frontmostHidesPasswordPrompts: true)
    XCTAssertFalse(v.isSecure)
    XCTAssertNil(v.owner)
    XCTAssertEqual(asked, 0, "cờ tắt thì không hỏi AX")
  }

  /// Đã có chủ thì không đọc lại IORegistry ở mỗi event.
  func testKnownOwnerIsNotLookedUpAgain() throws {
    var lookups = 0
    func holder() -> pid_t? { lookups += 1; return chrome }
    _ = EventHook.resolveSecureInput(
      systemFlag: true, knownOwner: chrome, backgroundHolder: holder(), frontmostPID: claude,
      frontField: .plainText, frontmostHidesPasswordPrompts: false)
    XCTAssertEqual(lookups, 0)
    _ = EventHook.resolveSecureInput(
      systemFlag: true, knownOwner: nil, backgroundHolder: holder(), frontmostPID: claude,
      frontField: .plainText, frontmostHidesPasswordPrompts: false)
    XCTAssertEqual(lookups, 1)
  }

  // MARK: Phân loại ô đang focus

  func testSecureFieldClassification() throws {
    let secure = kAXSecureTextFieldSubrole as String
    XCTAssertEqual(Focused.classifySecureField(subrole: secure, role: "AXTextField"), .secure)
    XCTAssertEqual(Focused.classifySecureField(subrole: secure, role: nil), .secure)
    for role in ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"] {
      XCTAssertEqual(Focused.classifySecureField(subrole: nil, role: role), .plainText, role)
    }
    XCTAssertEqual(
      Focused.classifySecureField(subrole: "AXSearchField", role: "AXTextField"), .plainText)
    XCTAssertEqual(
      Focused.classifySecureField(subrole: nil, role: nil), .unknown, "AX không trả lời")
    XCTAssertEqual(
      Focused.classifySecureField(subrole: nil, role: "AXGroup"), .unknown,
      "giao diện tự vẽ: có thể là ô mật khẩu không khai subrole")
    XCTAssertEqual(Focused.classifySecureField(subrole: nil, role: "AXWindow"), .unknown)
  }

  /// Danh sách terminal ở đây phải khớp nhóm terminal trong bảng chiến lược gửi.
  func testTerminalListMatchesTheSendingStrategyTable() throws {
    for prefix in EventSimulator.terminalBundlePrefixes {
      guard case .stepByStep = EventSimulator.builtInStrategy(for: prefix) else {
        return XCTFail("\(prefix) không phải .stepByStep trong appStrategies")
      }
      XCTAssertTrue(EventSimulator.isTerminalApp(prefix))
    }
    XCTAssertTrue(EventSimulator.isTerminalApp("dev.warp.Warp-Stable"))
    XCTAssertFalse(EventSimulator.isTerminalApp("com.google.Chrome"))
    XCTAssertFalse(EventSimulator.isTerminalApp("com.vng.zalo"), "stepByStep nhưng không phải terminal")
    XCTAssertFalse(EventSimulator.isTerminalApp(nil))
  }

  // MARK: Cảnh báo

  /// Báo mỗi khi secure input bật mà vkey KHÔNG đang đứng ngoài cho một lần
  /// nhập mật khẩu — kể cả khi kẻ giữ chính là app đang trước.
  func testWarningWheneverSecureInputIsOnWithoutPasswordEntry() throws {
    func warn(owner: pid_t?, locked: Bool = false, standingAside: Bool = false) -> Bool {
      EventHook.shouldWarnAboutSecureInputHolder(
        ownerPID: owner, ownPID: 77, screenLocked: locked,
        standingAsideForPasswordEntry: standingAside)
    }
    XCTAssertTrue(warn(owner: chrome), "app nền giữ, hoặc app đang trước giữ kẹt ở ô chữ thường")
    XCTAssertTrue(warn(owner: 142), "loginwindow sau khi ngủ dậy")
    XCTAssertFalse(warn(owner: chrome, standingAside: true), "đang nhập mật khẩu thật: ổ khoá lo")
    XCTAssertFalse(warn(owner: chrome, locked: true), "màn hình khoá")
    XCTAssertFalse(warn(owner: nil), "không ai giữ")
    XCTAssertFalse(warn(owner: 77), "vkey không cảnh báo về chính mình")
  }

  func testWarningDoesNotQueryAXWhenThereIsNoHolder() throws {
    var asked = 0
    func aside() -> Bool { asked += 1; return false }
    _ = EventHook.shouldWarnAboutSecureInputHolder(
      ownerPID: nil, ownPID: 77, screenLocked: false, standingAsideForPasswordEntry: aside())
    _ = EventHook.shouldWarnAboutSecureInputHolder(
      ownerPID: 3788, ownPID: 77, screenLocked: true, standingAsideForPasswordEntry: aside())
    XCTAssertEqual(asked, 0)
  }
}


// MARK: - Screen Sharing khi cả hai máy đều có vkey (sau 4.35)

/// Máy điều khiển phải trong suốt hoàn toàn; máy được điều khiển phải đọc đúng
/// Shift của người gõ từ xa.
final class ScreenSharingBothEndsTests: XCTestCase {

  private func makeHook() -> (EventHook, InputProcessor) {
    let processor = InputProcessor(method: .Telex)
    return (EventHook(inputProcessor: processor), processor)
  }

  // MARK: Máy điều khiển

  func testEnteringAViewerDropsTheWordAndReportsStandAside() throws {
    let (hook, processor) = makeHook()
    for ch in "vie" { processor.push(char: ch) }

    XCTAssertFalse(hook.updateRemoteDesktopStandAside(frontmostBundle: "com.google.Chrome"))
    XCTAssertEqual(processor.transformed, "vie", "app thường: không đụng bộ đệm")

    XCTAssertTrue(hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.ScreenSharing"))
    XCTAssertTrue(hook.lastStandsAsideForRemoteDesktop)
    XCTAssertEqual(processor.transformed, "", "từ dở thuộc về app trước, không mang sang máy kia")
  }

  /// Ở lại trong cửa sổ điều khiển thì không làm lại việc của mốc vào/ra — nếu
  /// không mỗi phím lại xoá bộ đệm và reset tổ hợp modifier.
  func testStayingInTheViewerDoesNotRepeatTheTransition() throws {
    let (hook, _) = makeHook()
    XCTAssertTrue(hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.ScreenSharing"))
    hook.modifierArmedMask = 42
    XCTAssertTrue(hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.ScreenSharing"))
    XCTAssertEqual(hook.modifierArmedMask, 42)
  }

  /// Tổ hợp ⇧⌥ đang giữ dở lúc vào/ra cửa sổ điều khiển không được tính cho bên
  /// nào: nó thuộc về máy kia lúc ở trong, và về máy này lúc ở ngoài.
  func testAHalfPressedHotkeyIsForgottenAcrossTheBoundary() throws {
    let (hook, _) = makeHook()
    let shiftOption =
      UInt64(NSEvent.ModifierFlags.shift.rawValue) | UInt64(NSEvent.ModifierFlags.option.rawValue)
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(
        type: .flagsChanged, currentMods: shiftOption, modifierTarget: shiftOption))
    XCTAssertEqual(hook.modifierArmedMask, shiftOption, "đang giữ ⇧⌥ ở app thường")

    hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.ScreenSharing")
    XCTAssertEqual(hook.modifierArmedMask, 0)
    XCTAssertFalse(
      hook.handleModifierOnlyHotkey(
        type: .flagsChanged, currentMods: 0, modifierTarget: shiftOption),
      "thả phím sau khi đã vào cửa sổ điều khiển không được đổi V/E của máy này")
  }

  func testLeavingTheViewerRestoresNormalHandling() throws {
    let (hook, _) = makeHook()
    hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.ScreenSharing")
    XCTAssertFalse(hook.updateRemoteDesktopStandAside(frontmostBundle: "com.apple.TextEdit"))
    XCTAssertFalse(hook.lastStandsAsideForRemoteDesktop)
    XCTAssertFalse(hook.updateRemoteDesktopStandAside(frontmostBundle: nil))
  }

  func testRemoteDesktopSymbolExists() throws {
    XCTAssertNotNil(
      NSImage(systemSymbolName: VKMenuBarLabel.remoteDesktopSymbol, accessibilityDescription: nil))
  }

  // MARK: Máy được điều khiển

  /// Shift của người gõ từ xa không nằm trong trạng thái HID của máy này. Sau
  /// một lần tap gián đoạn, đọc HID sẽ luôn ra "không giữ Shift" và làm chữ hoa
  /// thành chữ thường — nên trả cờ về "chưa theo dõi".
  func testShiftResyncDoesNotTrustLocalHardwareDuringRemoteTyping() throws {
    XCTAssertNil(EventHook.resyncedShiftState(lastInputWasRemote: true, hidShiftDown: false))
    XCTAssertNil(EventHook.resyncedShiftState(lastInputWasRemote: true, hidShiftDown: true))
    XCTAssertEqual(EventHook.resyncedShiftState(lastInputWasRemote: false, hidShiftDown: true), true)
    XCTAssertEqual(EventHook.resyncedShiftState(lastInputWasRemote: false, hidShiftDown: false), false)
  }

  /// Hook mới tạo chưa thấy phím từ xa nào: vẫn đọc HID như trước.
  func testFreshHookTreatsInputAsLocal() throws {
    let (hook, _) = makeHook()
    XCTAssertFalse(hook.lastUserInputWasRemote)
  }

  /// "Chưa theo dõi" nghĩa là tin cờ Shift trên chính event: chữ hoa gõ từ xa
  /// vẫn ra chữ hoa.
  func testUntrackedShiftKeepsRemoteCapitals() throws {
    let processor = InputProcessor(method: .Telex)
    processor.hardwareShiftDown = nil
    let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true))  // v
    event.flags = .maskShift
    _ = processor.handleEvent(event: event)
    XCTAssertEqual(processor.transformed, "V")
    XCTAssertTrue(event.flags.contains(.maskShift), "không gỡ Shift khỏi phím trả về app")
  }
}
