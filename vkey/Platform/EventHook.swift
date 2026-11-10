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

  /// Có nên CẢNH BÁO rằng Secure Input đang bật mà vkey KHÔNG đang đứng ngoài
  /// cho một lần nhập mật khẩu thật — tức có tiến trình giữ secure input ngoài ý
  /// muốn (ô mật khẩu bỏ quên ở cửa sổ khác, `loginwindow` sau khi ngủ dậy, hay
  /// chính app đang trước giữ kẹt dù con trỏ ở ô chữ thường). Lúc đó macOS có
  /// thể không chuyển phím cho vkey, nên phải nói cho người dùng biết ai giữ.
  /// Không báo khi màn hình đang khoá.
  static func shouldWarnAboutSecureInputHolder(
    ownerPID: pid_t?, ownPID: pid_t, screenLocked: Bool,
    standingAsideForPasswordEntry: @autoclosure () -> Bool
  ) -> Bool {
    guard let ownerPID, ownerPID > 0, ownerPID != ownPID, !screenLocked else { return false }
    return !standingAsideForPasswordEntry()
  }

  /// Màn hình đang khoá (theo WindowServer).
  static func isScreenLocked() -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
  }

  /// Số nhịp watchdog liên tiếp thấy một tiến trình khác giữ secure input.
  private var secureInputWarningTicks = 0

  /// Gọi từ watchdog 2 giây. Trả tên tiến trình đang giữ Secure Input trong lúc
  /// người dùng KHÔNG đứng ở ô mật khẩu (xem `shouldWarnAboutSecureInputHolder`)
  /// để biểu tượng menu bar và menu báo; `nil` nếu không có gì để báo.
  ///
  /// Chỉ báo khi thấy ở HAI nhịp liên tiếp: một ô mật khẩu vừa mở, AX chưa kịp
  /// trả subrole, là ca thoáng qua không đáng nháy biểu tượng.
  ///
  /// Kèm việc cũ: chủ là một app nền thì ghi lại vào `secureInputOwnerPID`, sửa
  /// phép đoán "app đang trước" nếu callback đã đoán nhầm.
  func secureInputWarningHolder(systemFlag: Bool) -> String? {
    guard systemFlag else {
      secureInputWarningTicks = 0
      return nil
    }
    let frontmost = NSWorkspace.shared.frontmostApplication
    if let app = Self.backgroundSecureInputHolderApp(frontmost: frontmost) {
      secureInputOwnerPID = app.processIdentifier
    }
    guard let pid = Self.systemSecureInputOwnerPID(),
      Self.shouldWarnAboutSecureInputHolder(
        ownerPID: pid, ownPID: ownPID, screenLocked: Self.isScreenLocked(),
        // Cùng phép quyết định với callback tap, với chủ THẬT từ IORegistry.
        standingAsideForPasswordEntry: Self.resolveSecureInput(
          systemFlag: true, knownOwner: pid, backgroundHolder: nil,
          frontmostPID: frontmost?.processIdentifier,
          frontField: Focused.secureFieldState(),
          frontmostHidesPasswordPrompts: EventSimulator.isTerminalApp(
            frontmost?.bundleIdentifier)
        ).isSecure)
    else {
      secureInputWarningTicks = 0
      return nil
    }
    secureInputWarningTicks += 1
    guard secureInputWarningTicks >= 2 else { return nil }
    if let app = NSRunningApplication(processIdentifier: pid),
      let name = app.localizedName ?? app.bundleIdentifier
    {
      return name
    }
    if let path = Self.executablePath(of: pid) {
      return (path as NSString).lastPathComponent
    }
    return "pid \(pid)"
  }

  /// Quyết định "vkey có phải đứng ngoài vì secure input không" cho MỘT event.
  ///
  /// `CGSIsSecureEventInputSet` là cờ toàn hệ thống: nó bật chừng nào còn BẤT KỲ
  /// tiến trình nào giữ secure input, kể cả app nền và kể cả khi tiến trình đó
  /// giữ kẹt sau khi ô mật khẩu đã đóng. Cờ đó vì vậy KHÔNG có nghĩa "người dùng
  /// đang nhập mật khẩu". vkey chỉ đứng ngoài (khoá tiếng Việt) khi:
  ///
  ///   1. ô đang focus đúng là ô mật khẩu (`.secure`); hoặc
  ///   2. app đang trước là chủ secure input VÀ không có bằng chứng rằng con trỏ
  ///      đang ở một ô chữ thường — tức AX không trả lời / phần tử tự vẽ
  ///      (`.unknown`), hoặc app là terminal, nơi lời nhắc mật khẩu của `sudo`
  ///      trông y như ô chữ thường.
  ///
  /// Trước 4.35, vế 2 không xét ô đang focus: app đang trước mà là chủ thì khoá
  /// luôn. Chrome giữ kẹt secure input sau khi rời ô mật khẩu là đủ để mọi ô
  /// nhập trong Chrome mất tiếng Việt, và ổ khoá hiện lên dù không có ô mật khẩu
  /// nào trên màn hình.
  ///
  /// ⚠️ Cái giá đã cân: một ô mật khẩu TỰ VẼ khai role là ô chữ chuẩn mà không
  /// khai subrole secure (hiếm; Qt/Java đời cũ) sẽ không còn được coi là ô mật
  /// khẩu. Danh sách role hẹp ở `Focused.plainTextRoles` là để thu nhỏ ca này.
  ///
  /// - Parameter backgroundHolder: chủ là app nền nếu xác định được (xem
  ///   `backgroundSecureInputHolderApp`). Chỉ được hỏi khi chưa có `knownOwner`.
  /// - Parameter frontmostHidesPasswordPrompts: app đang trước là terminal.
  /// - Returns: `owner` là giá trị mới của `secureInputOwnerPID`.
  static func resolveSecureInput(
    systemFlag: Bool, knownOwner: pid_t?,
    backgroundHolder: @autoclosure () -> pid_t?,
    frontmostPID: pid_t?,
    frontField: @autoclosure () -> Focused.SecureFieldState,
    frontmostHidesPasswordPrompts: Bool
  ) -> (isSecure: Bool, owner: pid_t?) {
    guard systemFlag else { return (false, nil) }
    let field = frontField()
    // Đang đứng ở ô mật khẩu — quyền chủ thuộc về app đang trước.
    if field == .secure { return (true, frontmostPID) }
    let owner = knownOwner ?? backgroundHolder() ?? frontmostPID
    // Secure input thuộc về một tiến trình khác; ở đây không có ô mật khẩu.
    guard owner == frontmostPID else { return (false, owner) }
    // App đang trước giữ secure input nhưng con trỏ ở một ô chữ thường.
    if field == .plainText, !frontmostHidesPasswordPrompts { return (false, owner) }
    return (true, owner)
  }

  /// App ĐIỀU KHIỂN MÁY TỪ XA: chúng chuyển phím vật lý sang máy kia qua mạng.
  /// Backspace + event Unicode do vkey tự phát đi qua đó thành chữ rác ở đầu bên
  /// kia, và nếu máy kia cũng có bộ gõ thì hai bộ gõ cùng biến đổi một chuỗi
  /// phím (phần còn thiếu của lỗi "hai máy cùng bật vkey" ở 4.34). Để phím thô
  /// đi thẳng; việc bỏ dấu thuộc về bộ gõ ở máy được điều khiển.
  ///
  /// Nguồn: `com.apple.ScreenSharing`, `com.apple.ScreenContinuity` (iPhone
  /// Mirroring) và `com.philandro.anydesk` kiểm bằng `mdfind` trên máy
  /// 2026-11-10; RustDesk, TeamViewer theo `RustBridge.swift` của Gõ Nhanh;
  /// Windows App, RealVNC, Citrix theo `ClientPolicy.swift` của VietTelex.
  /// Máy ảo (Parallels, VMware, UTM) CỐ Ý không có ở đây: gõ tiếng Việt vào máy
  /// ảo bằng bộ gõ của máy chủ là cách dùng phổ biến.
  static let remoteDesktopViewerBundles: Set<String> = [
    "com.apple.ScreenSharing",
    "com.apple.ScreenContinuity",
    "com.philandro.anydesk",
    "com.carriez.rustdesk",
    "com.teamviewer.TeamViewer",
    "com.microsoft.rdc.macos",
    "com.realvnc.vncviewer",
    "com.citrix.receiver.icaviewer.mac",
  ]

  /// Kết quả `standsAsideForRemoteDesktop(frontmostBundle:userState:)` gần nhất.
  /// Chỉ đọc/ghi trên main thread (callback tap và `AppState`).
  private(set) var lastStandsAsideForRemoteDesktop = false

  /// Tính lại "đang đứng ngoài cho app điều khiển máy từ xa" theo app đang
  /// trước, xử lý mốc vào/ra, và trả kết quả.
  ///
  /// Gọi từ callback tap ở mỗi event VÀ từ `AppState` khi macOS báo đổi app —
  /// chỉ dựa vào event thì biểu tượng menu bar đứng ở trạng thái cũ cho tới
  /// phím/cú click đầu tiên sau khi đổi app.
  @discardableResult
  func updateRemoteDesktopStandAside(frontmostBundle: String?) -> Bool {
    let standsAside = Self.standsAsideForRemoteDesktop(
      frontmostBundle: frontmostBundle,
      userState: frontmostBundle.flatMap { appState?.smartSwitchConfig(for: $0)?.state })
    guard lastStandsAsideForRemoteDesktop != standsAside else { return standsAside }
    // Vừa vào/ra app điều khiển từ xa: từ đang gõ dở thuộc về ngữ cảnh cũ, và
    // tổ hợp modifier đang giữ dở không được tính cho bên nào. So với bản sao
    // ở đây (đổi đồng bộ), không so với giá trị `@Published` (đổi trễ một nhịp)
    // — nếu không phím kế tiếp lại xoá bộ đệm.
    lastStandsAsideForRemoteDesktop = standsAside
    inputProcessor.newWord()
    inputProcessor.resetSentenceCapitalizeState()
    modifierArmedMask = 0
    modifierKeyUsedDuringArm = false
    if let appState {
      DispatchQueue.main.async { appState.remoteDesktopStandAside = standsAside }
    }
    return standsAside
  }

  /// vkey có đứng ngoài vì app đang trước là app điều khiển máy từ xa không.
  /// Người dùng đảo lại bằng cách đặt app đó là "Tiếng Việt" trong Smart Switch
  /// (máy kia không có bộ gõ, muốn gõ dấu từ máy này).
  static func standsAsideForRemoteDesktop(
    frontmostBundle: String?, userState: @autoclosure () -> AppSmartSwitchState?
  ) -> Bool {
    guard let frontmostBundle, remoteDesktopViewerBundles.contains(frontmostBundle) else {
      return false
    }
    return userState() != .vietnameseMode
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

  /// Phím/chuột người dùng gần nhất đến qua Screen Sharing (máy này đang ĐƯỢC
  /// điều khiển) chứ không từ bàn phím thật. Callback tap ghi; dùng để biết
  /// trạng thái bàn phím phần cứng của máy này có còn nói lên điều gì không
  /// (xem `syncHardwareShiftFromSystem`).
  private(set) var lastUserInputWasRemote = false

  func isUserInput(_ event: CGEvent) -> Bool {
    guard let remote = userInputOrigin(of: event) else { return false }
    lastUserInputWasRemote = remote
    return true
  }

  /// Nguồn của một event do NGƯỜI DÙNG gõ: `false` = bàn phím thật, `true` =
  /// Screen Sharing; `nil` = không phải người dùng (vkey hay app khác tự phát).
  private func userInputOrigin(of event: CGEvent) -> Bool? {
    let stateID = event.getIntegerValueField(.eventSourceStateID)
    if stateID == 1 { return false }
    let pid = pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventSourceUnixProcessID))
    // Event vkey tự phát: trả lời ngay, KHÔNG ghi vào đệm. Đệm chỉ có một ô, mà
    // gõ tiếng Việt qua Screen Sharing thì phím của agent và backspace/chữ thay
    // của vkey đi xen kẽ qua cùng tap — để event của chính mình chiếm ô thì
    // phím nào của agent cũng trượt đệm và gọi lại `proc_pidpath`.
    guard pid > 0, pid != ownPID else { return nil }
    if let cached = sourcePIDCache, cached.pid == pid { return cached.isScreenSharing ? true : nil }
    let result = Self.isUserInputSource(
      stateID: stateID, sourcePID: pid, ownPID: ownPID, pathForPID: Self.executablePath(of:))
    sourcePIDCache = (pid, result)
    return result ? true : nil
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
  ///
  /// Khi máy này đang được điều khiển qua Screen Sharing, Shift của người gõ
  /// KHÔNG nằm trong trạng thái HID của máy này (bàn phím thật không ai chạm).
  /// Đọc HID lúc đó luôn ra `false`, và nếu người gõ đang giữ Shift thì chữ hoa
  /// thành chữ thường cho tới `flagsChanged` kế tiếp. Trường hợp đó trả cờ về
  /// "chưa theo dõi" (`nil` = tin `maskShift` trên chính event).
  func syncHardwareShiftFromSystem() {
    inputProcessor.hardwareShiftDown = Self.resyncedShiftState(
      lastInputWasRemote: lastUserInputWasRemote,
      hidShiftDown: CGEventSource.flagsState(.hidSystemState).contains(.maskShift))
  }

  static func resyncedShiftState(lastInputWasRemote: Bool, hidShiftDown: Bool) -> Bool? {
    lastInputWasRemote ? nil : hidShiftDown
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

  // Chỉ đứng ngoài khi đang ở ô mật khẩu thật (xem `resolveSecureInput`). Ở mốc
  // cờ vừa bật (chưa có chủ) hỏi WindowServer xem có phải một app NỀN đang giữ
  // không; không xác định được thì coi app đang trước là chủ như cũ.
  let secureVerdict = EventHook.resolveSecureInput(
    systemFlag: rawSecureInput,
    knownOwner: eventHook.secureInputOwnerPID,
    backgroundHolder: EventHook.backgroundSecureInputHolderApp(frontmost: frontmostApp)?
      .processIdentifier,
    frontmostPID: frontmostPID,
    frontField: Focused.secureFieldState(),
    frontmostHidesPasswordPrompts: EventSimulator.isTerminalApp(frontmostBundle))
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

  // ── Đứng ngoài trong app điều khiển máy từ xa ─────────────────────────────
  // Khi cửa sổ Screen Sharing / AnyDesk… đang ở trước, vkey của máy NÀY phải
  // trong suốt hoàn toàn: mọi phím đi thẳng sang máy kia, nơi bộ gõ của máy đó
  // lo việc bỏ dấu. Trả về sớm, TRƯỚC khối phím tắt và khối theo dõi focus:
  //   • Phím tắt đổi V/E (⇧⌥) cũng đi sang máy kia, nên phải để vkey ở ĐÓ đổi
  //     chế độ. Xử lý ở đây nữa là đổi luôn chế độ của máy này — lá cờ bên này
  //     lật trong khi chữ gõ ra không liên quan gì tới nó, và rời cửa sổ điều
  //     khiển thì chế độ bên này đã bị đổi ngoài ý muốn.
  //   • Không chụp AX mỗi phím cho một cửa sổ mà vkey không gõ vào: gõ từ xa
  //     vốn đã trễ theo mạng, không cộng thêm độ trễ của máy này.
  if eventHook.updateRemoteDesktopStandAside(frontmostBundle: frontmostBundle) {
    return Unmanaged.passUnretained(event)
  }

  // ── Modifier-only hotkey detection ────────────────────────────────────────
  // The user can configure a pure-modifier combo (e.g. ⇧⌥) for the Vi/En
  // toggle. Carbon's RegisterEventHotKey can't bind to modifiers alone, so we
  // watch .flagsChanged events directly and trigger on press→release without
  // an intervening keyDown or click.
  let toggleTarget = UInt64(Defaults[.modifierOnlyToggleHotkey])
  if toggleTarget != 0 {
    let currentMods = event.flags.rawValue & kModifierMask
    if eventHook.handleModifierOnlyHotkey(
      type: type, currentMods: currentMods, modifierTarget: toggleTarget),
      let appState = eventHook.appState
    {
      DispatchQueue.main.async {
        appState.setEnabledByUser(!appState.enabled)
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
        let desiredEnabled =
          appState.smartSwitchConfig(for: focusedBundleId)?.state.enablesVietnamese

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
  // Modifier-only / focus vẫn xử lý phía trên. (App điều khiển máy từ xa đã
  // được trả về sớm ở khối "đứng ngoài".)
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
