//
//  Updater.swift
//  vkey
//
//  Created by KhanhIceTea on 17/02/2024.
//

import AppKit
import Defaults
import Foundation
import Sparkle

enum Updater {
  static let delegate = VkeyUpdaterDelegate()

  // Share a single global controller instance to manage updates silently in the background
  static let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: delegate,
    userDriverDelegate: delegate
  )

  /// Chặn bấm "Kiểm tra cập nhật" liên tục → nhiều dialog chồng nhau.
  private static var manualCheckInProgress = false

  /// Gọi từ AppDelegate sau launch — áp preference + check nền + HUD hoàn tất.
  static func configureOnLaunch() {
    delegate.applyPreferences()
    showPostUpdateSuccessHUDIfNeeded()

    guard Defaults[.autoUpdateEnabled] else { return }
    guard shouldRunAutoCheckToday() else { return }
    Defaults[.lastUpdateCheckDate] = Date()
    updaterController.updater.checkForUpdatesInBackground()
  }

  /// Gọi khi user bật/tắt toggle trong Cài đặt.
  static func applyAutomaticUpdatePreference() {
    delegate.applyPreferences()
  }

  static func checkForUpdates(manual: Bool = false) {
    if manual {
      guard !manualCheckInProgress else { return }
      manualCheckInProgress = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        manualCheckInProgress = false
      }
      prepareAppForUserFacingModal {
        updaterController.checkForUpdates(nil)
      }
      return
    }

    guard Defaults[.autoUpdateEnabled] else { return }
    guard shouldRunAutoCheckToday() else { return }
    Defaults[.lastUpdateCheckDate] = Date()
    updaterController.updater.checkForUpdatesInBackground()
  }

  /// HUD xanh sau khi Sparkle cài xong và relaunch app.
  static func showPostUpdateSuccessHUDIfNeeded() {
    let pending = Defaults[.pendingUpdateSuccessHUDVersion].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !pending.isEmpty else { return }

    let current = Bundle.main.appVersionLong
    guard pending == current else { return }

    Defaults[.pendingUpdateSuccessHUDVersion] = ""
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      NoticeHUDWindow.shared.show(
        message: "vkey \(current) đã sẵn sàng sử dụng.",
        title: "Cập nhật hoàn tất",
        style: .success,
        duration: 4.0
      )
    }
  }

  /// Menu-bar accessory cần activation + delay ngắn trước modal Sparkle/NSAlert.
  private static func prepareAppForUserFacingModal(_ work: @escaping () -> Void) {
    NSApp.setActivationPolicy(.regular)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      NSApp.activate(ignoringOtherApps: true)
      work()
    }
  }

  // MARK: - 1.6.0: Throttle

  /// Trả true nếu chưa check trong ngày hôm nay.
  private static func shouldRunAutoCheckToday() -> Bool {
    guard let lastCheck = Defaults[.lastUpdateCheckDate] else {
      return true
    }
    return !Calendar.current.isDateInToday(lastCheck)
  }
}

// MARK: - Sparkle delegate (silent auto-update + suppress scheduled dialogs)

final class VkeyUpdaterDelegate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {

  func applyPreferences() {
    let enabled = Defaults[.autoUpdateEnabled]
    let updater = Updater.updaterController.updater
    updater.automaticallyChecksForUpdates = enabled
    updater.automaticallyDownloadsUpdates = enabled
  }

  // MARK: SPUUpdaterDelegate

  func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
    if !Defaults[.autoUpdateEnabled], updateCheck == .updatesInBackground {
      throw NSError(
        domain: "dev.longht.vkey.updater",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Tự động cập nhật đã tắt"]
      )
    }
  }

  func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    guard Defaults[.autoUpdateEnabled] else { return }
    DispatchQueue.main.async {
      Defaults[.pendingUpdateSuccessHUDVersion] = item.displayVersionString
    }
  }

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    guard Defaults[.autoUpdateEnabled] else { return false }
    DispatchQueue.main.async {
      Defaults[.pendingUpdateSuccessHUDVersion] = item.displayVersionString
    }
    return false
  }

  // MARK: SPUStandardUserDriverDelegate

  /// Khi auto-update bật: không hiện dialog Sparkle cho check nền — chỉ tải/cài im lặng.
  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem,
    andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    !Defaults[.autoUpdateEnabled]
  }
}
