//
//  UpgradeBackupPrompt.swift
//  vkey
//
//  AppKit NSAlert flow offering a local backup whenever the user launches
//  a newer vkey version. Extracted from UserDataMigration.swift so the
//  migration core stays free of AppKit.
//

import AppKit
import Defaults
import Foundation

enum UpgradeBackupPrompt {

  static func present(from persisted: String, to running: String) {
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "vkey đã được cập nhật lên \(running)"
      alert.informativeText = """
      Bạn vừa nâng từ v\(persisted) lên v\(running). Khuyến nghị sao lưu \
      dữ liệu cá nhân (macros, từ điển cá nhân, cấu hình) ngay bây giờ. \
      File sao lưu chỉ lưu trên máy bạn, không gửi đi đâu.
      """
      alert.alertStyle = .informational
      alert.addButton(withTitle: "Sao lưu ngay")
      alert.addButton(withTitle: "Để sau")
      alert.showsSuppressionButton = true
      alert.suppressionButton?.title = "Không hiện lại"
      alert.suppressionButton?.state = .off

      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      alert.window.level = .floating
      alert.window.orderFrontRegardless()
      let response = alert.runModal()

      if alert.suppressionButton?.state == .on {
        Defaults[.autoBackupOnUpgrade] = false
      }

      if response == .alertFirstButtonReturn {
        let url = UserDataMigration.defaultBackupURL()
        do {
          try UserDataMigration.writeAtomically(to: url, export: UserDataMigration.currentExport())
          let confirm = NSAlert()
          confirm.messageText = "Đã sao lưu thành công"
          confirm.informativeText = "Đường dẫn: \(url.path)"
          confirm.addButton(withTitle: "Mở thư mục")
          confirm.addButton(withTitle: "Đóng")
          if confirm.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
          }
        } catch {
          let fail = NSAlert()
          fail.messageText = "Sao lưu thất bại"
          fail.informativeText = error.localizedDescription
          fail.alertStyle = .warning
          fail.runModal()
        }
      }

      Defaults[.currentVersion] = running
      WindowCoordinator.restoreAccessoryPolicyIfNeeded()
    }
  }
}
