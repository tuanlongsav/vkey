//
//  AccessibilityWatchdog.swift
//  vkey
//
//  Polling cấp quyền Trợ năng khi mới khởi chạy, watchdog 2 giây phát hiện
//  thu hồi quyền / tap bị tắt ngầm / Secure Input kẹt, và hộp thoại hướng dẫn.
//

import AppKit
import CoreGraphics
import Foundation
import os.log

private let watchdogLog = OSLog(subsystem: "dev.longht.vkey", category: "AccessibilityWatchdog")

final class AccessibilityWatchdog {

  private weak var appState: AppState?
  private let isCurrentlyTrusted: () -> Bool
  private let onTrustStatusChanged: (Bool) -> Void
  private let onBecameTrusted: () -> Void

  private var trustCheckTimer: Timer?
  private var trustCheckRetries = 0
  private let maxTrustCheckRetries = 30
  private var revocationWatchdog: Timer?
  private var accessibilityAlertShowing = false

  init(
    appState: AppState,
    isCurrentlyTrusted: @escaping () -> Bool,
    onTrustStatusChanged: @escaping (Bool) -> Void,
    onBecameTrusted: @escaping () -> Void
  ) {
    self.appState = appState
    self.isCurrentlyTrusted = isCurrentlyTrusted
    self.onTrustStatusChanged = onTrustStatusChanged
    self.onBecameTrusted = onBecameTrusted
  }

  deinit {
    stopAll()
  }

  func stopAll() {
    trustCheckTimer?.invalidate()
    trustCheckTimer = nil
    revocationWatchdog?.invalidate()
    revocationWatchdog = nil
  }

  /// Polling 2s/lần (tối đa ~60s) chờ người dùng cấp quyền Trợ năng.
  func restartTrustCheckLoop() {
    trustCheckRetries = 0
    trustCheckTimer?.invalidate()
    trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
      [weak self] timer in
      guard let self, let appState = self.appState else {
        timer.invalidate()
        return
      }
      let trusted = appState.eventHook.isTrusted(prompt: false)
      self.onTrustStatusChanged(trusted)
      if trusted {
        timer.invalidate()
        self.trustCheckTimer = nil
        self.onBecameTrusted()
        return
      }
      self.trustCheckRetries += 1
      if self.trustCheckRetries >= self.maxTrustCheckRetries {
        timer.invalidate()
        self.trustCheckTimer = nil
        self.showAccessibilityHelpAlert()
      }
    }
  }

  /// Watchdog 2 giây suốt phiên trusted:
  /// - Phát hiện quyền Trợ năng bị thu hồi → tháo tap ngay; cấp lại → dựng tap mới.
  /// - Phát hiện tap bị macOS tắt ngầm → tự bật lại + resync.
  /// - Gỡ ổ khoá Secure Input kẹt & cập nhật tên tiến trình giữ Secure Input ngoài ý muốn.
  func startRevocationWatchdog() {
    revocationWatchdog?.invalidate()
    let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      guard let self, let appState = self.appState else { return }
      let trusted = appState.eventHook.isTrusted(prompt: false)
      appState.eventHook.trustedCache = trusted
      let wasTrusted = self.isCurrentlyTrusted()

      if !trusted && wasTrusted {
        self.onTrustStatusChanged(false)
        appState.eventHook.suspendAfterRevocation()
        appState.setEnabled(set: false)
      } else if trusted && !wasTrusted {
        self.onBecameTrusted()
      } else if trusted, let tap = appState.eventHook.eventTap,
        !CGEvent.tapIsEnabled(tap: tap)
      {
        appState.eventHook.recoverTap()
        os_log(
          "Event tap was silently disabled, watchdog re-enabled it (count: %{public}d)",
          log: watchdogLog, type: .error, appState.eventHook.tapRecoveryCount)
      }

      let secureInputOn = CGSIsSecureEventInputSet()
      if appState.eventHook.reconcileSecureInput(
        systemFlag: secureInputOn,
        lockShown: appState.secureInputActive)
      {
        appState.secureInputActive = false
      }

      let holder = trusted
        ? appState.eventHook.secureInputWarningHolder(systemFlag: secureInputOn) : nil
      if appState.secureInputHolderName != holder {
        appState.secureInputHolderName = holder
      }
    }
    timer.tolerance = 0.5
    RunLoop.main.add(timer, forMode: .common)
    revocationWatchdog = timer
  }

  /// Alert một lần hướng dẫn người dùng cấp lại quyền Trợ năng trong System Settings.
  func showAccessibilityHelpAlert() {
    guard !accessibilityAlertShowing else { return }
    accessibilityAlertShowing = true

    WindowCoordinator.presentFloatingModal(delay: 0.35) { [weak self] in
      guard let self else { return }

      let alert = NSAlert()
      alert.messageText = "vkey cần quyền \(AccessibilityPermissionPane.displayName)"
      alert.informativeText = """
      vkey cần được cấp quyền này để có thể chuyển ký tự bạn gõ thành tiếng \
      Việt. Vui lòng mở:

      \(AccessibilityPermissionPane.settingsPath)

      rồi bật toggle cho vkey. Sau đó nhấn "Thử lại" để vkey tiếp tục.
      """
      alert.addButton(withTitle: "Mở Cài đặt")
      alert.addButton(withTitle: "Thử lại")
      alert.addButton(withTitle: "Để sau")
      alert.alertStyle = .warning
      alert.window.level = .floating
      alert.window.orderFrontRegardless()

      let response = alert.runModal()
      self.accessibilityAlertShowing = false
      WindowCoordinator.restoreAccessoryPolicyIfNeeded()

      switch response {
      case .alertFirstButtonReturn:
        AccessibilityPermissionPane.openSettings()
        self.restartTrustCheckLoop()
      case .alertSecondButtonReturn:
        self.restartTrustCheckLoop()
      default:
        break
      }
    }
  }
}
