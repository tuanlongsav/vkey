import ApplicationServices
import Cocoa
import Defaults
import Foundation
import IOKit
import KeyboardShortcuts
import os.log

/// v2.14: log chẩn đoán nhận diện app đích (xem qua `log stream`).
private let hookLog = OSLog(subsystem: "dev.longht.vkey", category: "EventHook")

// Private macOS API to detect secure input mode (password fields)
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

/// Bit mask of the modifier flags we care about (matches both
/// `CGEventFlags` and `NSEvent.ModifierFlags` bit layouts on macOS).
private let kModifierMask: UInt64 =
  UInt64(NSEvent.ModifierFlags.command.rawValue) |
  UInt64(NSEvent.ModifierFlags.option.rawValue) |
  UInt64(NSEvent.ModifierFlags.control.rawValue) |
  UInt64(NSEvent.ModifierFlags.shift.rawValue)

// EventHook manages keyboard events and interacts with the Telex engine.
class EventHook {

  var eventTap: CFMachPort?
  /// Run-loop source paired with `eventTap`. Stored so `destroy()` and
  /// `unregisterEventTap` can remove the exact source that was added,
  /// instead of creating a fresh (and never-actually-attached) one.
  private var runLoopSource: CFRunLoopSource?
  var keyLayout: KeyboardUS
  var inputProcessor: InputProcessor
  var processing = false
  var appState: AppState?

  /// Tracks how many times the tap has been auto-recovered
  var tapRecoveryCount = 0

  /// v3.2: cache trạng thái quyền Accessibility — GHI từ main thread
  /// (watchdog AppDelegate + handler tapDisabled), ĐỌC trong callback.
  /// Khi false → callback passthrough ngay, KHÔNG xử lý phím / KHÔNG gọi AX
  /// (AX call sau khi quyền bị thu hồi sẽ block XPC → tap .defaultTap giữ
  /// toàn bộ input của session → treo macOS, phải reset cứng).
  var trustedCache = true

  /// v2.10: số lần retry tạo tap khi `tapCreate` fail dù app tưởng có quyền
  /// (TCC mismatch sau update đổi chữ ký). Trước đây fail im lặng → user thấy
  /// "bật V" mà không gõ được ở mọi app.
  private var tapSetupRetries = 0
  /// v2.10: callback khi tap vẫn fail sau khi retry — AppDelegate hiện alert
  /// hướng dẫn re-grant Accessibility (tái dùng `showAccessibilityHelpAlert`).
  var onTapSetupFailed: (() -> Void)?

  /// v2.11: PID đích của event gần nhất — đọc trực tiếp từ event
  /// (`.eventTargetUnixProcessID`, WindowServer điền sẵn). Cache bundleId
  /// để chỉ lookup NSRunningApplication khi PID đổi (rẻ, không AX).
  var lastEventTargetPID: pid_t = 0
  var lastEventTargetBundleId: String?

  /// State for modifier-only hotkey detection (e.g. press Shift+Control then
  /// release without any key in between → toggle Vi/En). Tracking is done
  /// inside the event tap so it works while another app has focus and
  /// even while secure input is *not* active (it bypasses during secure input
  /// just like the normal IME path).
  var modifierArmedMask: UInt64 = 0  // current latched target, 0 = not armed
  var modifierKeyUsedDuringArm = false

  /// PID of the app that owns the currently active system-wide secure input,
  /// recorded at the off→on transition. `CGSIsSecureEventInputSet` is global,
  /// so when a background app keeps a focused password field the flag stays on
  /// even after the user switches apps. We scope private mode to this owner so
  /// vkey resumes normal typing in other apps. `nil` while secure input is off.
  var secureInputOwnerPID: pid_t?

  /// Trạng thái secure input chỉ được đánh giá lại trong callback tap, SAU bộ
  /// lọc "chỉ phím phần cứng" (stateID == 1). Qua Screen Sharing mọi phím/chuột
  /// đến từ ScreensharingAgent với stateID khác 1 nên bị bỏ trước khi tới đó:
  /// ổ khoá bật lúc có ô mật khẩu sẽ kẹt mãi sau khi ô đã đóng. Watchdog gọi hàm
  /// này định kỳ để gỡ khi cờ hệ thống đã tắt. Chỉ GỠ, không bao giờ BẬT — việc
  /// bật vẫn thuộc về callback (cần xét chủ sở hữu theo app đang trước).
  /// Trả `true` khi ổ khoá đang hiện phải được tắt.
  func reconcileSecureInput(systemFlag: Bool, lockShown: Bool) -> Bool {
    guard !systemFlag else { return false }
    secureInputOwnerPID = nil
    return lockShown
  }

  /// PID của tiến trình đang giữ secure input, theo WindowServer; `nil` khi
  /// không ai giữ hoặc không đọc được.
  ///
  /// Đọc `IOConsoleUsers[].kCGSSessionSecureInputPID` ở gốc IORegistry — cùng
  /// nguồn với `ioreg -l | grep SecureInput`. KHÔNG dùng
  /// `CGSessionCopyCurrentDictionary()` dù nó có đúng khoá đó: đo 2026-11-10 trên
  /// MacBook, lúc Chrome (app nền) giữ secure input thì IORegistry báo đúng pid
  /// Chrome và về rỗng ngay khi Chrome nhả, còn dictionary của session báo pid
  /// của app ĐANG TRƯỚC (Claude, rồi Zalo) — tức không cho biết ai giữ.
  static func systemSecureInputOwnerPID() -> pid_t? {
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    guard root != 0 else { return nil }
    defer { IOObjectRelease(root) }
    guard
      let users = IORegistryEntryCreateCFProperty(
        root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [[String: Any]]
    else { return nil }
    let uid = Int(getuid())
    // Nhiều phiên đăng nhập (fast user switching): ưu tiên phiên của chính mình.
    let mine = users.filter { ($0["kCGSSessionUserIDKey"] as? NSNumber)?.intValue == uid }
    for user in mine.isEmpty ? users : mine {
      if let pid = (user["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value, pid > 0 {
        return pid
      }
    }
    return nil
  }

  /// Chủ secure input có CHẮC CHẮN là một app nền không.
  ///
  /// Chỉ `true` khi chủ là app thường (có Dock), không phải app đang trước,
  /// không phải tiến trình phụ của app đang trước, không phải vkey. Mọi ca khác
  /// — agent hệ thống (SecurityAgent hiện hộp mật khẩu), tiến trình phụ, không
  /// tra được — trả `false` để phía gọi giữ cách hiểu cũ là "app đang trước
  /// giữ": thà đứng ngoài nhầm còn hơn bỏ dấu vào một ô mật khẩu.
  static func isBackgroundSecureInputHolder(
    ownerPID: pid_t?, ownerBundle: String?, ownerIsRegularApp: Bool,
    frontmostPID: pid_t?, frontmostBundle: String?, ownPID: pid_t
  ) -> Bool {
    guard let ownerPID, ownerPID > 0, ownerPID != ownPID, ownerPID != frontmostPID,
      ownerIsRegularApp
    else { return false }
    if let ownerBundle, let frontmostBundle, !frontmostBundle.isEmpty,
      ownerBundle == frontmostBundle || ownerBundle.hasPrefix(frontmostBundle + ".")
    {
      return false
    }
    return true
  }

  /// App nền đang giữ secure input (xem `isBackgroundSecureInputHolder`), hoặc
  /// `nil`. Một lần đọc IORegistry + một lần tra `NSRunningApplication`: chỉ gọi
  /// ở mốc secure input vừa bật (callback) và ở nhịp watchdog 2 giây.
  static func backgroundSecureInputHolderApp(
    frontmost: NSRunningApplication?
  ) -> NSRunningApplication? {
    guard let pid = systemSecureInputOwnerPID(),
      let owner = NSRunningApplication(processIdentifier: pid),
      isBackgroundSecureInputHolder(
        ownerPID: pid, ownerBundle: owner.bundleIdentifier,
        ownerIsRegularApp: owner.activationPolicy == .regular,
        frontmostPID: frontmost?.processIdentifier,
        frontmostBundle: frontmost?.bundleIdentifier, ownPID: getpid())
    else { return nil }
    return owner
  }

  /// Gọi từ watchdog khi cờ secure input đang bật: ghi lại chủ là app nền (sửa
  /// phép đoán "app đang trước" nếu callback đã đoán nhầm) và trả tên app để
  /// menu hiển thị. `nil` khi chủ không phải app nền.
  func refreshBackgroundSecureInputHolder() -> String? {
    guard
      let app = Self.backgroundSecureInputHolderApp(
        frontmost: NSWorkspace.shared.frontmostApplication)
    else { return nil }
    secureInputOwnerPID = app.processIdentifier
    return app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)"
  }

  /// Quyết định "vkey có phải đứng ngoài vì secure input không" cho MỘT event.
  ///
  /// `CGSIsSecureEventInputSet` là cờ toàn hệ thống: nó bật chừng nào còn BẤT KỲ
  /// app nào (kể cả app nền) giữ một ô mật khẩu. Nên đứng ngoài chỉ khi chủ là
  /// app đang trước, hoặc ô đang focus của app đang trước tự nó là ô mật khẩu
  /// (khi đó quyền chủ chuyển sang app đang trước).
  ///
  /// - Parameter backgroundHolder: chủ là app nền nếu xác định được (xem
  ///   `backgroundSecureInputHolderApp`). Chỉ được hỏi ở mốc cờ vừa bật, khi
  ///   chưa có `knownOwner`. Trước đây mốc đó luôn gán chủ = app đang trước, nên
  ///   khi Chrome nền giữ ô mật khẩu thì ổ khoá hiện ở app đang gõ, và tắt đi
  ///   đúng lúc quay lại Chrome.
  /// - Returns: `owner` là giá trị mới của `secureInputOwnerPID`.
  static func resolveSecureInput(
    systemFlag: Bool, knownOwner: pid_t?,
    backgroundHolder: @autoclosure () -> pid_t?,
    frontmostPID: pid_t?,
    frontFieldIsSecure: @autoclosure () -> Bool
  ) -> (isSecure: Bool, owner: pid_t?) {
    guard systemFlag else { return (false, nil) }
    let owner = knownOwner ?? backgroundHolder() ?? frontmostPID
    if owner == frontmostPID { return (true, owner) }
    // Front app has its own password field focused — ownership moves to it.
    if frontFieldIsSecure() { return (true, frontmostPID) }
    // Secure input belongs to a background app; keep typing here.
    return (false, owner)
  }

  /// Chế độ mà Smart Switch muốn áp cho `bundleId`: `true` = tiếng Việt,
  /// `false` = tiếng Anh/tắt, `nil` = app không có cấu hình.
  ///
  /// Thứ tự: rule tiêu đề cửa sổ của đúng app đó → cấu hình 3 trạng thái →
  /// danh sách "tắt VN" đời cũ.
  static func smartSwitchDesiredEnabled(
    bundleId: String,
    ruleBundleId: String?, ruleState: AppSmartSwitchState?,
    config: AppSmartSwitchConfig?,
    isLegacyEnglishApp: @autoclosure () -> Bool
  ) -> Bool? {
    func enabled(for state: AppSmartSwitchState) -> Bool {
      switch state {
      case .disabled, .englishMode: return false
      case .vietnameseMode: return true
      }
    }
    if ruleBundleId == bundleId, let ruleState { return enabled(for: ruleState) }
    if let config { return enabled(for: config.state) }
    if isLegacyEnglishApp() { return false }
    return nil
  }

  /// keyDown đến qua Screen Sharing mang CHỮ ĐÃ SOẠN SẴN chứ không phải một
  /// phím thô.
  ///
  /// Khi máy ĐIỀU KHIỂN cũng chạy bộ gõ, nó gửi sang backspace + event chỉ mang
  /// chuỗi Unicode ("ê", "ệt", hoặc cả từ "text "). Đọc event đó theo mã phím
  /// (vkey gắn mã 0 = phím A cho event Unicode) thì máy này tưởng người dùng gõ
  /// `a`, đẩy vào bộ đệm trong khi app nhận "ê" — bộ đệm lệch màn hình và lần
  /// thay chữ kế tiếp xoá nhầm. Phím thô thì chỉ mang tối đa MỘT ký tự ASCII.
  ///
  /// ⚠️ CHƯA ĐO trên hai máy thật (cần MacBook + Mac Studio cùng bật vkey):
  /// chưa biết Screen Sharing có giữ nguyên chuỗi Unicode của event gốc không.
  /// Ca còn hở kể cả khi có: event Unicode mang đúng một ký tự ASCII (chữ hoa
  /// đầu câu do bộ gõ đầu kia phát) trông y như phím thô.
  static func isPrecomposedRemoteText(_ payload: String) -> Bool {
    if payload.utf16.count > 1 { return true }
    // U+F700…U+F8FF: mã riêng AppKit gắn cho phím chức năng (mũi tên, Home,
    // F1…) — đó là phím thô, phải tới `handleEvent` như thường.
    return payload.unicodeScalars.contains {
      !$0.isASCII && !(0xF700...0xF8FF).contains($0.value)
    }
  }

  /// Chuỗi Unicode gắn trên một event phím ("" nếu không có).
  static func unicodePayload(of event: CGEvent) -> String {
    var length = 0
    var units = [UniChar](repeating: 0, count: 32)
    event.keyboardGetUnicodeString(
      maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
    return length > 0 ? String(utf16CodeUnits: units, count: min(length, units.count)) : ""
  }

  /// Đường dẫn file chạy của tiến trình nhận phím Screen Sharing trên máy được
  /// điều khiển. Phải nằm dưới `/System/` (SIP bảo vệ) để app khác không giả
  /// dạng được bằng cách đặt tên trùng.
  static let screenSharingAgentPath =
    "/System/Library/CoreServices/RemoteManagement/ScreensharingAgent.bundle/Contents/MacOS/ScreensharingAgent"

  /// Phím/chuột có phải do NGƯỜI DÙNG gõ không — bàn phím thật (HID, stateID 1)
  /// hoặc gõ từ máy khác qua Screen Sharing. Mọi event tổng hợp khác (của chính
  /// vkey, của app tự động hoá) vẫn bị bỏ như trước.
  ///
  /// Đo 2026-11-01 trên Mac Studio: phím qua Screen Sharing đến từ
  /// ScreensharingAgent, `eventSourceStateID` là một state riêng (2007905771),
  /// mang mã phím US bình thường, Shift gửi qua `flagsChanged` riêng. Bộ lọc
  /// cũ (`stateID != 1` → bỏ) làm vkey không bao giờ gõ được tiếng Việt và ổ
  /// khoá secure input kẹt mãi khi điều khiển máy từ xa.
  static func isUserInputSource(
    stateID: Int64, sourcePID: pid_t, ownPID: pid_t,
    pathForPID: (pid_t) -> String?
  ) -> Bool {
    if stateID == 1 { return true }
    guard sourcePID > 0, sourcePID != ownPID else { return false }
    return pathForPID(sourcePID) == screenSharingAgentPath
  }

  static func executablePath(of pid: pid_t) -> String? {
    var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
    guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
    return String(cString: buf)
  }

  /// Đệm kết quả theo pid nguồn: `proc_pidpath` là syscall, không nên gọi trên
  /// đường nóng cho mỗi phím. Chỉ chạy trên main run loop (cùng callback tap).
  private var sourcePIDCache: (pid: pid_t, isScreenSharing: Bool)?
  private let ownPID = getpid()

  func isUserInput(_ event: CGEvent) -> Bool {
    let stateID = event.getIntegerValueField(.eventSourceStateID)
    if stateID == 1 { return true }
    let pid = pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventSourceUnixProcessID))
    // Event vkey tự phát: trả lời ngay, KHÔNG ghi vào đệm. Đệm chỉ có một ô, mà
    // gõ tiếng Việt qua Screen Sharing thì phím của agent và backspace/chữ thay
    // của vkey đi xen kẽ qua cùng tap — để event của chính mình chiếm ô thì
    // phím nào của agent cũng trượt đệm và gọi lại `proc_pidpath`.
    guard pid > 0, pid != ownPID else { return false }
    if let cached = sourcePIDCache, cached.pid == pid { return cached.isScreenSharing }
    let result = Self.isUserInputSource(
      stateID: stateID, sourcePID: pid, ownPID: ownPID, pathForPID: Self.executablePath(of:))
    sourcePIDCache = (pid, result)
    return result
  }

  init(inputProcessor: InputProcessor) {
    self.keyLayout = KeyboardUS()
    self.inputProcessor = inputProcessor
    syncHardwareShiftFromSystem()
  }

  /// Đọc lại trạng thái Shift của phần cứng vào `inputProcessor.hardwareShiftDown`.
  ///
  /// Cờ đó bình thường được nuôi bằng `flagsChanged` trong `handleTapEvent`,
  /// nhưng dòng cập nhật nằm SAU hai early-return: `flagsChanged` xảy ra trong
  /// lúc hệ thống vô hiệu tap, hoặc trong lúc mất quyền Trợ năng, không bao giờ
  /// tới. Cờ mắc `false` trong khi ngón tay đang giữ Shift thì chữ hoa ra chữ
  /// thường và `passThrough` gỡ cờ Shift khỏi phím trả về app. Gọi hàm này ở
  /// mọi mốc mà tap có thể vừa bỏ lỡ một `flagsChanged`.
  ///
  /// `CGEventSource.flagsState` chứ KHÔNG phải `NSEvent.modifierFlags`: đo
  /// 09/10/2026 (`Tools/probe/evlog.swift`) thấy `NSEvent.modifierFlags` trễ
  /// một event — ở `flagsChanged` Shift-down nó còn báo `false`, ở Shift-up nó
  /// còn báo `true`.
  func syncHardwareShiftFromSystem() {
    inputProcessor.hardwareShiftDown =
      CGEventSource.flagsState(.hidSystemState).contains(.maskShift)
  }

  /// Bật lại tap sau khi hệ thống vô hiệu nó, rồi đưa trạng thái gõ về chỗ an
  /// toàn. Dùng chung cho handler `tapDisabledBy*` trong callback và watchdog ở
  /// `AppDelegate` — trước đây hai nơi tự bật riêng và watchdog quên đồng bộ Shift.
  func recoverTap() {
    guard let eventTap else { return }
    CGEvent.tapEnable(tap: eventTap, enable: true)
    resyncAfterTapGap()
    tapRecoveryCount += 1
  }

  /// Trong lúc tap tắt, phím đi THẲNG vào app mà vkey không thấy: bộ đệm từ
  /// không còn khớp màn hình, và mọi `flagsChanged` đã mất.
  ///
  /// Giữ bộ đệm cũ thì phím đầu tiên sau khi tap sống lại sẽ diff trên chữ đã
  /// lệch: bộ đệm "vie", lọt qua "et" (màn hình "vieet"), gõ `j` → backspace
  /// đếm theo "vie" ăn vào hai chữ vừa lọt. Bắt đầu từ mới thì cùng lắm từ dở
  /// đó không ra dấu, không xoá nhầm chữ nào.
  func resyncAfterTapGap() {
    inputProcessor.newWord()
    inputProcessor.resetSentenceCapitalizeState()
    syncHardwareShiftFromSystem()
  }

  @discardableResult
  func handleModifierOnlyHotkey(
    type: CGEventType,
    currentMods: UInt64,
    modifierTarget: UInt64
  ) -> Bool {
    return processModifierTargets(type: type, currentMods: currentMods, targets: [modifierTarget])
      == modifierTarget
  }

  /// 2.0.2 (J3): support nhiều modifier-only targets cùng lúc (vd VI/EN
  /// + Text Tools). Logic: armed theo target khớp currentMods. Khi release
  /// (currentMods == 0) trả về target đã armed (nếu key chưa được dùng).
  /// Return 0 = không trigger; non-zero = mask của target vừa fire.
  @discardableResult
  func processModifierTargets(
    type: CGEventType,
    currentMods: UInt64,
    targets: [UInt64]
  ) -> UInt64 {
    // Bỏ targets = 0 và duplicate.
    let validTargets = Array(Set(targets.filter { $0 != 0 }))
    guard !validTargets.isEmpty else { return 0 }

    if type == .flagsChanged {
      // Khi chưa armed, check xem currentMods có match target nào không.
      if modifierArmedMask == 0 {
        if validTargets.contains(currentMods) {
          modifierArmedMask = currentMods
          modifierKeyUsedDuringArm = false
        }
        return 0
      }

      // Đang armed. Check extra modifier ngoài armedMask → cancel.
      let armedMask = modifierArmedMask
      let hasExtraModifier = (currentMods & ~armedMask) != 0
      if hasExtraModifier {
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return 0
      }

      if currentMods == 0 {
        let fire = !modifierKeyUsedDuringArm
        modifierArmedMask = 0
        modifierKeyUsedDuringArm = false
        return fire ? armedMask : 0
      }

      // Một phần của combo được thả — đợi tất cả modifiers up.
      return 0
    }

    // Click chuột trong lúc giữ tổ hợp (⇧⌥-click mở rộng vùng chọn…) cũng là
    // DÙNG modifier, không phải bấm-thả tổ hợp trơn — không được bật phím tắt.
    let usesHeldModifiers =
      type == .keyDown || type == .leftMouseDown || type == .rightMouseDown
    if usesHeldModifiers && modifierArmedMask != 0 {
      modifierKeyUsedDuringArm = true
    }

    return 0
  }

  func setEnabled(_ value: Bool) {
    // v4.22: chỉ reset khi trạng thái THẬT SỰ đổi. `AppState.enabled` là
    // @Published nên `didSet` bắn cả khi gán lại đúng giá trị cũ, và Smart
    // Switch áp lại chế độ ở mỗi lần chuyển app — kể cả chuyển app "giả" do
    // AX nhảy giữa app cha và tiến trình phụ của nó. Reset vô điều kiện ở đây
    // biến mỗi lần áp lại thành một lần xoá từ đang gõ.
    let changed = self.processing != value
    self.processing = value
    if changed { self.inputProcessor.newWord() }
  }

  // Checks if the application has accessibility permissions.
  func isTrusted(prompt: Bool = true) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }

  // Removes the event tap before the application terminates.
  func destroy() {
    if let eventTap = eventTap {
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  /// v3.2: quyền Accessibility bị thu hồi khi đang chạy — tháo tap hoàn toàn
  /// (disable + invalidate) để không còn gì chặn dòng event của hệ thống.
  /// Khi user cấp lại quyền, AppDelegate watchdog sẽ `setupEventTap` tap MỚI.
  func suspendAfterRevocation() {
    trustedCache = false
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  deinit {
    destroy()
  }

  // Sets up the event tap to listen for keyboard and mouse events.
  func setupEventTap(give appState: AppState) {
    if eventTap != nil {
      self.appState = appState
      return
    }

    let eventMask =
      (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventTapCallback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )
    else {
      os_log("Failed to create event tap", log: hookLog, type: .error)
      // v2.10: tap fail dù `isTrusted()` có thể vẫn true (TCC entry cũ sau khi
      // update đổi chữ ký). Retry vài lần (TCC có thể đang settle) rồi báo user
      // thay vì chết im lặng với toggle "bật".
      if tapSetupRetries < 3 {
        tapSetupRetries += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
          self?.setupEventTap(give: appState)
        }
      } else {
        tapSetupRetries = 0
        onTapSetupFailed?()
      }
      return
    }

    tapSetupRetries = 0
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    self.appState = appState
    self.trustedCache = true
    // Tap vừa được gắn (lần đầu, hoặc gắn lại sau khi watchdog tháo vì mất
    // quyền): mọi `flagsChanged` trước đó đã mất, kể cả Shift đang giữ.
    syncHardwareShiftFromSystem()
  }

  /// Unregisters the event tap from the run loop. Uses the run-loop source
  /// captured in `setupEventTap`; creating a fresh source here (the previous
  /// behaviour) would leak the original and remove a source that was never
  /// actually added.
  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let source = self.runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }
    self.runLoopSource = nil
    self.eventTap = nil
  }
}

// Callback function for the event tap.
//
// Bọc TOÀN BỘ xử lý trong `autoreleasepool`. Callback này chạy như một source
// của main run loop, và mỗi phím sinh ra hàng chục object autorelease
// (`frontmostApplication`, `NSRunningApplication`, NSString bắc cầu từ AX và
// từ ~20 lần đọc UserDefaults…). Pool của AppKit chỉ được xả khi app lấy ra
// một NSEvent — mà vkey là app menu bar, có khi cả giờ không nhận NSEvent nào
// trong lúc người dùng gõ ở app khác — nên không có pool riêng thì các object
// đó dồn lại theo số phím đã gõ. Không đổi hành vi: mọi nhánh trả
// `passUnretained` của chính `event` (tap sở hữu) hoặc `nil`.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  autoreleasepool {
    handleTapEvent(type: type, event: event, refcon: refcon)
  }
}

private func handleTapEvent(
  type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()

  // Auto-recover when macOS disables the event tap
  // This happens when the tap callback takes too long or the system is under load
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    // v3.2: hệ thống cũng disable tap khi quyền Accessibility BỊ THU HỒI.
    // Re-enable vô điều kiện như trước = giằng co với TCC → kẹt input toàn
    // hệ thống. Chỉ recover khi quyền còn; mất quyền → đánh dấu cache để
    // mọi event sau passthrough, watchdog ở AppDelegate sẽ tháo tap.
    let stillTrusted = AXIsProcessTrusted()
    eventHook.trustedCache = stillTrusted
    if stillTrusted, eventHook.eventTap != nil {
      // Bật lại + bỏ từ đang gõ dở + đọc lại Shift từ phần cứng: phím và
      // `flagsChanged` trong lúc tap bị vô hiệu đều đã đi qua mà vkey không
      // thấy (xem `resyncAfterTapGap`).
      eventHook.recoverTap()
      #if DEBUG
      print("[vkey] Event tap was disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), auto-recovered (count: \(eventHook.tapRecoveryCount))")
      #endif
    }
    return Unmanaged.passUnretained(event)
  }

  // v3.2: quyền Accessibility đã mất → passthrough NGAY, không xử lý phím,
  // không gọi AX (AX call lúc này block XPC → treo toàn bộ input macOS).
  if !eventHook.trustedCache {
    return Unmanaged.passUnretained(event)
  }

  // Chỉ xử lý phím người dùng gõ: bàn phím thật (HID) hoặc Screen Sharing.
  // Event vkey tự phát và event tổng hợp của app khác đi thẳng.
  if !eventHook.isUserInput(event) {
    return Unmanaged.passUnretained(event)
  }

  // Shift thật: chỉ `flagsChanged` người dùng gõ (HID hoặc Screen Sharing — nơi
  // Shift đến bằng `flagsChanged` riêng). Event chữ do vkey tự phát đã bị bỏ
  // phía trên, nên chữ hoa tổng hợp không tự bật cờ này.
  if type == .flagsChanged {
    eventHook.inputProcessor.hardwareShiftDown = event.flags.contains(.maskShift)
  }

  // IME Switcher button on keyboard
  //    if let appState = eventHook.appState,
  //      type == .flagsChanged && (event.flags.contains(.maskSecondaryFn))  // Left Fn
  //    {
  //      appState.setEnabled(set: !appState.enabled)
  //      return nil
  //    }

  let input = eventHook.inputProcessor

  // Check for secure input mode (password fields, Terminal sudo prompts, 1Password, …)
  // When active, macOS forbids reading raw key data — vkey must completely step aside
  // so the user can type their password normally and the app doesn't appear to "eat"
  // keystrokes. We also reset the word buffer at the false→true transition so we don't
  // resume processing with stale state when secure input ends.
  // `CGSIsSecureEventInputSet` is a *system-wide* flag: it stays on while ANY
  // app (even a background one) keeps a focused password field. Treating that
  // raw flag as "be private" left vkey stuck in private mode after the user
  // switched away from the app holding the password window. Instead we scope
  // private mode to whoever actually owns the secure input right now:
  //   • record the owning app at the off→on transition;
  //   • stay private only while that owner is frontmost, OR the frontmost app's
  //     focused element is itself a secure field (front app opened its own
  //     password box, so ownership moves to it).
  // This keeps Terminal `sudo` working (owner == Terminal, exposes no secure
  // subrole) while following the active app everywhere else.
  let rawSecureInput = CGSIsSecureEventInputSet()
  let frontmostApp = NSWorkspace.shared.frontmostApplication
  let frontmostPID = frontmostApp?.processIdentifier
  let frontmostBundle = frontmostApp?.bundleIdentifier

  // Ở mốc cờ vừa bật (chưa có chủ) hỏi WindowServer xem có phải một app NỀN
  // đang giữ không; không xác định được thì coi app đang trước là chủ như cũ.
  let secureVerdict = EventHook.resolveSecureInput(
    systemFlag: rawSecureInput,
    knownOwner: eventHook.secureInputOwnerPID,
    backgroundHolder: EventHook.backgroundSecureInputHolderApp(frontmost: frontmostApp)?
      .processIdentifier,
    frontmostPID: frontmostPID,
    frontFieldIsSecure: Focused.isSecureField())
  eventHook.secureInputOwnerPID = secureVerdict.owner
  let isSecureInput = secureVerdict.isSecure

  if let appState = eventHook.appState, appState.secureInputActive != isSecureInput {
    if isSecureInput {
      // Entering secure input: drop any in-progress Vietnamese word so the next
      // resumed session starts clean.
      input.newWord()
    }
    DispatchQueue.main.async {
      appState.secureInputActive = isSecureInput
    }
  }

  // Hard bypass: no Vietnamese processing while secure input is active, regardless
  // of enabled state. The hotkey (Option+Z) is registered via Carbon hotkey through
  // the KeyboardShortcuts library and operates independently of this event tap, so
  // toggling Vi/En still works while the password field is focused.
  if isSecureInput {
    return Unmanaged.passUnretained(event)
  }

  // ── Clipboard history: ⌘C lưu; phím tắt cấu hình mở menu chọn (mặc định ⇧⌘V) ──
  if type == .keyDown, Defaults[.clipboardHistoryEnabled] {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let mods = event.flags
    let commandOnly = mods.contains(.maskCommand)
      && !mods.contains(.maskControl)
      && !mods.contains(.maskAlternate)
      && !mods.contains(.maskShift)
    if commandOnly, keyCode == 8 {
      let beforeCount = NSPasteboard.general.changeCount
      DispatchQueue.main.async {
        ClipboardHistoryService.shared.scheduleCaptureAfterCopy(since: beforeCount)
      }
    } else if ClipboardHistoryHotkey.matchesKeyDown(event),
              ClipboardHistoryService.shared.hasEntriesForEventTap
    {
      DispatchQueue.main.async {
        ClipboardHistoryService.shared.showPickerAndPaste()
      }
      return nil
    }
  }

  // ── Modifier-only hotkey detection ────────────────────────────────────────
  // The user can configure pure-modifier combos (e.g. ⇧⌥ for Vi/En toggle,
  // ⌃⇧ for Text Tools menu). Carbon's RegisterEventHotKey can't bind to
  // modifiers alone, so we watch .flagsChanged events directly and trigger
  // on press→release without an intervening keyDown.
  // 2.0.2 (J3): support 2 modifier-only targets song song.
  let toggleTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  let textToolsTarget = UInt64(Defaults[.modifierOnlyTextToolsHotkey])
  let clipboardTarget = ClipboardHistoryHotkey.modifierOnlyMask
  if toggleTarget != 0 || textToolsTarget != 0 || clipboardTarget != 0 {
    let currentMods = event.flags.rawValue & kModifierMask
    let firedMask = eventHook.processModifierTargets(
      type: type,
      currentMods: currentMods,
      targets: [toggleTarget, textToolsTarget, clipboardTarget]
    )
    if firedMask != 0 {
      if firedMask == toggleTarget, let appState = eventHook.appState {
        DispatchQueue.main.async {
          appState.setEnabledByUser(!appState.enabled)
        }
      } else if firedMask == textToolsTarget {
        DispatchQueue.main.async {
          TextConversionService.shared.openMenu(near: nil)
        }
      } else if firedMask == clipboardTarget,
                Defaults[.clipboardHistoryEnabled],
                ClipboardHistoryService.shared.hasEntriesForEventTap
      {
        DispatchQueue.main.async {
          ClipboardHistoryService.shared.showPickerAndPaste()
        }
      }
    }
  }

  // ── Focus Tracking & Smart Switch Overlay Probing ──────────────────────────
  // 1.7.x: KHÔNG gọi AX đồng bộ trong callback… — đã đổi ở v4.28: chụp AX mỗi
  // keyDown TRƯỚC khi chọn activeApp (cùng snapshot nuôi fieldKind).
  //
  // ⚠️ v4.28 — THỨ TỰ KHỐI DƯỚI LÀ CÓ CHỦ Ý. Đọc trước khi "dọn":
  //
  // Trước đây (v4.23 quyết định giữ hai khối): (1) event-target PID →
  // changeActiveApp, (2) cache `currentFocusedBundleId` (AX của PHÍM TRƯỚC) →
  // changeActiveApp lại, (3) `syncFocusedContextForKeystroke` cập nhật cache
  // cho phím SAU. Panel `.nonactivatingPanel` (Plume chat bubble) không kích
  // hoạt app → frontmost + cache AX đọng ở app nền trong khi ô gõ thuộc Plume.
  // Bước (2) ghi đè activeApp về app nền → mất whitelist NFC + cushion →
  // "về"→"ề", "dở"→"ở", "fix"→"fx".
  //
  // Nay: chụp AX trước → một lần phân giải ưu tiên bundle của focused UI
  // element; overlay Spotlight vẫn thắng khi Smart Switch bật; event-target
  // chỉ fallback khi AX hụt. KHÔNG kèm `newWord()` ở `changeActiveApp`.
  if let appState = eventHook.appState {
    if type == .keyDown {
      // Chụp AX trước khi chọn activeApp — cùng snapshot nuôi fieldKind bên
      // dưới (handleEvent). Trước đây chụp SAU nên cache luôn lệch một phím.
      appState.syncFocusedContextForKeystroke()
    }

    if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown {
      let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
      if targetPID > 0 {
        // v2.15: PID đích cho axDirect (fallback khi system-wide không cho focus).
        EventSimulator.axTargetPID = targetPID
        if targetPID != eventHook.lastEventTargetPID {
          eventHook.lastEventTargetPID = targetPID
          eventHook.lastEventTargetBundleId =
            NSRunningApplication(processIdentifier: targetPID)?.bundleIdentifier
        }
      }

      let frontmost = frontmostBundle
      // Ưu tiên AX focused element (đúng nonactivating Plume / WKWebView host).
      // Overlay Spotlight thắng khi Smart Switch bật (event-target trả app nền
      // trên macOS 26). Event-target chỉ khi AX hụt.
      var focusedBid = appState.currentFocusedBundleId
        ?? eventHook.lastEventTargetBundleId
      if Defaults[.smartSwitchEnabled],
         let ov = EventSimulator.focusedOverlayBundle()
      {
        focusedBid = ov
      }
      if let focusedBid {
        let resolved = InputProcessor.canonicalAppBundle(
          focused: focusedBid, frontmost: frontmost)
        if resolved != input.activeApp {
          input.changeActiveApp(resolved)
          appState.noteFocusedBundleId(resolved)
        }
      }
    }

    var isFocusShiftingKey = false
    if type == .keyDown {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      // Tab (48), Enter (36), Esc (53), Up (126), Down (125), Left (123), Right (124)
      if keyCode == 48 || keyCode == 36 || keyCode == 53 || (keyCode >= 123 && keyCode <= 126) {
        isFocusShiftingKey = true
      }
    }

    // v2.10: ⌘-combo (⌘Space mở Spotlight, ⌘Tab đổi app…) cũng có thể chuyển
    // focus sang overlay không fire NSWorkspace notification → trigger refresh.
    let isCommandCombo = type == .keyDown && event.flags.contains(.maskCommand)

    if type == .leftMouseDown || type == .rightMouseDown || isFocusShiftingKey
      || isCommandCombo {
      appState.refreshFocusedBundleIdAsync()
    }

    if Defaults[.smartSwitchEnabled],
       (type == .keyDown || type == .leftMouseDown || type == .rightMouseDown) {
      // Tra cấu hình theo app ĐÃ QUY CHUẨN, không theo bundle thô AX trả về.
      // `currentFocusedBundleId` giữ nguyên id của tiến trình phụ khi `resolved`
      // ở khối trên trùng `activeApp` (`noteFocusedBundleId` không chạy), nên
      // trong hộp thoại Lưu (`com.apple.appkit.xpc.openAndSavePanelService`) hay
      // tiến trình phụ của app, tra thô ra "app không có cấu hình" → Smart
      // Switch tự gỡ và trả chế độ cũ giữa lúc đang gõ; AX nhảy cha/phụ từng
      // phím thì chế độ lật từng phím, mỗi lần lật `setEnabled` xoá từ đang gõ.
      // Cùng lớp lỗi "Haf Nooij" mà `canonicalAppBundle` (v4.22) vá cho `activeApp`.
      //
      // Bỏ qua app mà người dùng vừa tự đổi V/E (`manualModeBundleId`): ép lại
      // cấu hình ở mỗi phím làm phím tắt đổi chế độ mất tác dụng ngay phím kế.
      if let rawFocusedBundleId = appState.currentFocusedBundleId,
         case let focusedBundleId = InputProcessor.canonicalAppBundle(
           focused: rawFocusedBundleId, frontmost: frontmostBundle),
         appState.manualModeBundleId != focusedBundleId
      {
        let desiredEnabled = EventHook.smartSwitchDesiredEnabled(
          bundleId: focusedBundleId,
          ruleBundleId: appState.activeRuleOverridesBundleId,
          ruleState: appState.activeRuleOverrides.overrideState,
          config: appState.smartSwitchConfig(for: focusedBundleId),
          isLegacyEnglishApp: Defaults[.smartSwitchApps].contains(focusedBundleId))

        if let desired = desiredEnabled {
          if !appState.smartSwitchActive {
            appState.enabledBeforeSmartSwitch = appState.enabled
            appState.smartSwitchActive = true
            // 1.5.0: record fire for weekly stats. Async-recorded inside
            // UsageStatistics so the event tap callback stays fast.
            UsageStatistics.shared.recordSmartSwitchFire(toApp: focusedBundleId)
          }
          if appState.enabled != desired {
            appState.setEnabledWithoutPersist(desired)
          }
        } else if appState.smartSwitchActive {
          appState.smartSwitchActive = false
          appState.setEnabledWithoutPersist(appState.enabledBeforeSmartSwitch)
        }
      }
    }
  }

  // Không chạy Telex/VNI khi user đang gõ trong chính vkey (Settings, macro…).
  // Clipboard / modifier-only / focus vẫn xử lý phía trên.
  let skipVietnameseIME = frontmostBundle == Bundle.main.bundleIdentifier

  if type == .keyDown && eventHook.processing && !skipVietnameseIME {
    // Phím qua Screen Sharing mà mang chữ đã soạn sẵn (bộ gõ ở máy điều khiển
    // cũng đang bật): không đọc theo mã phím — kết thúc từ và để chữ đi thẳng.
    // Phím phần cứng (stateID 1) không bao giờ vào nhánh này.
    if event.getIntegerValueField(.eventSourceStateID) != 1,
       EventHook.isPrecomposedRemoteText(EventHook.unicodePayload(of: event))
    {
      input.newWord()
      return Unmanaged.passUnretained(event)
    }
    // AX snapshot đã chạy ở khối Focus Tracking phía trên (v4.28) — trước khi
    // chọn activeApp — nên không chụp lại ở đây (tránh 2× ~50 message AX/phím).
    return input.handleEvent(event: event)
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
    input.resetSentenceCapitalizeState()  // click dời con trỏ → huỷ chờ viết hoa (A5 fix)
  }

  return Unmanaged.passUnretained(event)
}

// MARK: - Clipboard history hotkey (EventHook)

/// So khớp phím tắt mở menu lịch sử clipboard trong event tap.
/// Khi lịch sử rỗng, caller không nuốt phím (⇧⌘V vẫn là Paste and Match Style).
enum ClipboardHistoryHotkey {
  static var modifierOnlyMask: UInt64 {
    UInt64(Defaults[.clipboardHistoryModifierOnlyHotkey])
  }

  static func installDefaultIfNeeded() {
    guard KeyboardShortcuts.getShortcut(for: .pasteClipboardHistory) == nil,
          Defaults[.clipboardHistoryModifierOnlyHotkey] == 0
    else { return }
    KeyboardShortcuts.setShortcut(
      KeyboardShortcuts.Shortcut(.v, modifiers: [.shift, .command]),
      for: .pasteClipboardHistory
    )
  }

  static func matchesKeyDown(_ event: CGEvent) -> Bool {
    guard Defaults[.clipboardHistoryModifierOnlyHotkey] == 0 else { return false }
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    if let shortcut = KeyboardShortcuts.getShortcut(for: .pasteClipboardHistory),
       let key = shortcut.key
    {
      return keyCode == key.rawValue
        && modifierFlags(from: flags) == shortcut.modifiers
    }
    // Mặc định ⇧⌘V
    return keyCode == 9
      && flags.contains(.maskCommand)
      && flags.contains(.maskShift)
      && !flags.contains(.maskAlternate)
      && !flags.contains(.maskControl)
  }

  private static func modifierFlags(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
    var mods = NSEvent.ModifierFlags()
    if flags.contains(.maskCommand) { mods.insert(.command) }
    if flags.contains(.maskShift) { mods.insert(.shift) }
    if flags.contains(.maskAlternate) { mods.insert(.option) }
    if flags.contains(.maskControl) { mods.insert(.control) }
    return mods
  }
}
