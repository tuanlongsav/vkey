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
import UserNotifications

enum Updater {
  // Share a single global controller instance to manage updates silently in the background
  static let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil as (any SPUUpdaterDelegate)?,
    userDriverDelegate: nil as (any SPUStandardUserDriverDelegate)?
  )

  static func checkForUpdates(manual: Bool = false) {
    if manual {
      // User explicitly clicked "Check for Updates..." in settings or menu
      guard let appcastURL = URL(
        string: "https://api.github.com/repos/tuanlongsav/vkey/contents/appcast.xml"
      ) else {
        updaterController.checkForUpdates(nil)
        return
      }
      var request = URLRequest(url: appcastURL)
      request.cachePolicy = .reloadIgnoringLocalCacheData
      request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

      URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
          guard error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200,
            let data = data
          else {
            // Fallback to native Sparkle on network error or non-200 status
            updaterController.checkForUpdates(nil)
            return
          }

          // 1.5.0: parse the appcast with Foundation's XMLParser instead of
          // regex. The regex approach broke on multi-line tag values and
          // didn't honour attribute quoting nuances.
          let summary = AppcastParser.parseTopItem(data: data)

          // 1.5.10: nếu parse XML fail HOẶC thiếu version, fallback ngay sang
          // native Sparkle (đừng show "đã là mới nhất" sai). Trước đây nếu
          // appcast.xml có ký tự `&` chưa escape, parser trả nil shortVersion
          // và Updater báo nhầm "server v1.5.0" với versionCode=0 — user
          // thấy app báo "đã mới nhất" mặc dù thực ra có bản mới.
          guard let summary = summary,
                let serverVersionCodeStr = summary.versionCode,
                let serverVersionCode = Int(serverVersionCodeStr),
                serverVersionCode > 0
          else {
            updaterController.checkForUpdates(nil)
            return
          }

          let serverVersionStr = summary.shortVersion ?? "?"
          _ = summary.enclosureURL  // available if we ever want to deep-link

          let localVersionCodeStr =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
          let localVersionStr =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.5.0"

          let localVersionCode = Int(localVersionCodeStr) ?? 0

          if localVersionCode < serverVersionCode {
            // There is a real newer version! Let Sparkle handle the native update flow
            updaterController.checkForUpdates(nil)
          } else {
            // Local version is equal to or greater than the server version
            let alert = NSAlert()
            alert.messageText = "Bạn đang sử dụng phiên bản mới nhất!"
            alert.informativeText =
              "Phiên bản v\(localVersionStr) (Build \(localVersionCodeStr)) là phiên bản mới nhất hiện tại. (Phiên bản server: v\(serverVersionStr))"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Đóng")
            // v3.3: app accessory không active → alert modal có thể VÔ HÌNH
            // mà vẫn chặn main thread (treo menu). Ép nổi + activate.
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .floating
            alert.window.orderFrontRegardless()
            alert.runModal()
          }
        }
      }.resume()
    } else {
      // 1.6.0: throttle background auto-check thành 1 lần/ngày (user
      // muốn "lần đầu mở máy buổi sáng", interpret là lần đầu launch
      // mỗi ngày). Quit+relaunch trong ngày → skip.
      guard shouldRunAutoCheckToday() else { return }
      Defaults[.lastUpdateCheckDate] = Date()

      // Sparkle native background check + bổ sung Notification Center
      // banner cho visibility.
      updaterController.updater.checkForUpdatesInBackground()
      scheduleProactiveNotificationCheck()
    }
  }

  // MARK: - 1.6.0: Throttle + Notification Center banner

  /// Trả true nếu chưa check trong ngày hôm nay.
  private static func shouldRunAutoCheckToday() -> Bool {
    guard let lastCheck = Defaults[.lastUpdateCheckDate] else {
      return true   // Chưa check bao giờ → check ngay.
    }
    return !Calendar.current.isDateInToday(lastCheck)
  }

  /// Sau 5s từ launch, parse appcast lần nữa qua AppcastParser custom.
  /// Nếu thấy version mới (so với CFBundleVersion local) VÀ chưa hiện
  /// notification banner cho version đó → post UNNotification banner.
  /// Layer 2 cho Sparkle's own dialog — đảm bảo user thấy ngay cả khi
  /// app chạy ẩn ở menu bar.
  private static func scheduleProactiveNotificationCheck() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      fetchAndNotifyIfNewer()
    }
  }

  private static func fetchAndNotifyIfNewer() {
    guard let url = URL(
      string: "https://api.github.com/repos/tuanlongsav/vkey/contents/appcast.xml"
    ) else { return }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

    URLSession.shared.dataTask(with: request) { data, response, error in
      guard error == nil,
        let http = response as? HTTPURLResponse,
        http.statusCode == 200,
        let data = data,
        let summary = AppcastParser.parseTopItem(data: data),
        let codeStr = summary.versionCode,
        let serverCode = Int(codeStr),
        serverCode > 0
      else { return }

      let localCodeStr = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
      let localCode = Int(localCodeStr) ?? 0
      guard serverCode > localCode else { return }

      // Đã notify version này rồi → skip.
      if Defaults[.lastNotifiedUpdateBuild] >= serverCode { return }

      DispatchQueue.main.async {
        Defaults[.lastNotifiedUpdateBuild] = serverCode
        postUpdateNotification(
          version: summary.shortVersion ?? "?",
          build: serverCode
        )
      }
    }.resume()
  }

  private static func postUpdateNotification(version: String, build: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Có bản vkey mới: v\(version)"
    content.body = "Click để xem & cài đặt qua Sparkle."
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "vkey-update-\(build)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { _ in
      // Ignore errors — nếu user chưa cho permission, alert sẽ
      // không hiện. Sparkle dialog vẫn còn là backup.
    }
  }
}

// MARK: - Appcast parsing

struct AppcastItemSummary: Equatable {
  let versionCode: String?     // sparkle:version
  let shortVersion: String?    // sparkle:shortVersionString
  let enclosureURL: String?    // enclosure[@url]
}

/// XMLParser-based replacement for the regex parser we shipped through 1.4.x.
///
/// Reads only what we actually need: the *first* `<item>` in the feed
/// (Sparkle appcasts list newest-first), and from it the `sparkle:version`
/// + `sparkle:shortVersionString` text content plus the `<enclosure url=…>`
/// attribute. Other tags and items are ignored.
///
/// Exposed at file scope (not `private`) so the test target can exercise it.
final class AppcastParser: NSObject, XMLParserDelegate {
  private var insideFirstItem = false
  fileprivate(set) var seenFirstItem = false
  private var currentTag: String?
  private var currentText: String = ""

  private(set) var versionCode: String?
  private(set) var shortVersion: String?
  private(set) var enclosureURL: String?

  static func parseTopItem(data: Data) -> AppcastItemSummary? {
    let parser = XMLParser(data: data)
    let delegate = AppcastParser()
    parser.delegate = delegate
    parser.shouldProcessNamespaces = false   // keep "sparkle:version" as a single qualified name
    // We deliberately don't surface an error if parse() returns false:
    // - `abortParsing()` is the documented way to stop after the first <item>,
    //   and it causes parse() to return false. We've already captured what we
    //   need by then.
    // - Genuine XML errors still produce a sensible empty result; callers
    //   treat nil fields as "no info".
    _ = parser.parse()
    if delegate.versionCode == nil && delegate.shortVersion == nil && delegate.enclosureURL == nil {
      // Distinguish "garbage in" from "empty <item> in valid feed":
      // - Garbage: parser raised an error before any tag was seen.
      // - Empty item: `seenFirstItem` is true (we entered and exited <item>).
      if !delegate.seenFirstItem && parser.parserError != nil {
        return nil
      }
    }
    return AppcastItemSummary(
      versionCode: delegate.versionCode,
      shortVersion: delegate.shortVersion,
      enclosureURL: delegate.enclosureURL
    )
  }

  // MARK: XMLParserDelegate

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String]
  ) {
    if elementName == "item" {
      if seenFirstItem {
        parser.abortParsing()  // we only care about the newest item
        return
      }
      insideFirstItem = true
      return
    }
    guard insideFirstItem else { return }

    currentTag = elementName
    currentText = ""

    if elementName == "enclosure" {
      if let url = attributeDict["url"] {
        enclosureURL = url
      }
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard insideFirstItem, currentTag != nil else { return }
    currentText += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "item" {
      insideFirstItem = false
      seenFirstItem = true
      return
    }
    guard insideFirstItem else { return }

    let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    switch elementName {
    case "sparkle:version":
      if versionCode == nil { versionCode = trimmed }
    case "sparkle:shortVersionString":
      if shortVersion == nil { shortVersion = trimmed }
    default:
      break
    }
    currentTag = nil
    currentText = ""
  }
}
