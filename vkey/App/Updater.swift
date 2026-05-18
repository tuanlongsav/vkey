//
//  Updater.swift
//  vkey
//

import Foundation
import AppKit

enum Updater {
  static func checkForUpdates(manual: Bool = false) {
    guard let url = URL(string: "https://api.github.com/repos/tuanlongsav/vkey/releases/latest") else { return }
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      guard let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tagName = json["tag_name"] as? String,
            let htmlUrl = json["html_url"] as? String else {
        if manual {
          DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Lỗi kiểm tra bản cập nhật"
            alert.informativeText = "Không thể kết nối đến máy chủ GitHub."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Đóng")
            alert.runModal()
          }
        }
        return
      }
      
      let currentVersion = Bundle.main.appVersionLong
      
      // So sánh phiên bản (chỉ so sánh số)
      // Ví dụ: tagName = "1.3.5", currentVersion = "1.3.5"
      let isNewer = tagName.compare(currentVersion, options: .numeric) == .orderedDescending
      
      DispatchQueue.main.async {
        if isNewer {
          let alert = NSAlert()
          alert.messageText = "Có bản cập nhật mới!"
          alert.informativeText = "Phiên bản \(tagName) đã có sẵn. Bạn đang dùng bản \(currentVersion)."
          alert.alertStyle = .informational
          alert.addButton(withTitle: "Tải về")
          alert.addButton(withTitle: "Bỏ qua")
          
          if alert.runModal() == .alertFirstButtonReturn {
            if let releaseUrl = URL(string: htmlUrl) {
              NSWorkspace.shared.open(releaseUrl)
            }
          }
        } else if manual {
          let alert = NSAlert()
          alert.messageText = "Bạn đang dùng bản mới nhất"
          alert.informativeText = "Phiên bản \(currentVersion) là phiên bản mới nhất hiện tại."
          alert.alertStyle = .informational
          alert.addButton(withTitle: "OK")
          alert.runModal()
        }
      }
    }
    task.resume()
  }
}
