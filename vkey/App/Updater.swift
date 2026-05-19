//
//  Updater.swift
//  vkey
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Foundation
import AppKit
import Sparkle

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
      let timestamp = Int(Date().timeIntervalSince1970)
      let appcastURL = URL(string: "https://raw.githubusercontent.com/tuanlongsav/vkey/main/appcast.xml?t=\(timestamp)")!
      var request = URLRequest(url: appcastURL)
      request.cachePolicy = .reloadIgnoringLocalCacheData
      
      URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
          guard error == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let data = data,
                let xml = String(data: data, encoding: .utf8) else {
            // Fallback to native Sparkle on network error or non-200 status
            updaterController.checkForUpdates(nil)
            return
          }
          
          let serverVersionCodeStr = parseTag("sparkle:version", from: xml) ?? ""
          let serverVersionStr = parseTag("sparkle:shortVersionString", from: xml) ?? "1.4.2"
          let enclosureUrlStr = parseEnclosureUrl(from: xml) ?? "https://github.com/tuanlongsav/vkey/releases"
          
          let localVersionCodeStr = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
          let localVersionStr = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4.2"
          
          let serverVersionCode = Int(serverVersionCodeStr) ?? 0
          let localVersionCode = Int(localVersionCodeStr) ?? 0
          
          if localVersionCode < serverVersionCode {
            // There is a real newer version! Let Sparkle handle the native update flow
            updaterController.checkForUpdates(nil)
          } else {
            // Local version is equal to or greater than the server version
            let alert = NSAlert()
            alert.messageText = "Bạn đang sử dụng phiên bản mới nhất!"
            alert.informativeText = "Phiên bản v\(localVersionStr) (Build \(localVersionCodeStr)) là phiên bản mới nhất hiện tại."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Đóng")
            alert.runModal()
          }
        }
      }.resume()
    } else {
      // Silent automatic check in background on application launch
      updaterController.updater.checkForUpdatesInBackground()
    }
  }

  // MARK: - Private Helpers
  
  private static func parseTag(_ tag: String, from xml: String) -> String? {
    let pattern = "<\(tag)>([^<]+)</\(tag)>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let nsString = xml as NSString
    let results = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
    return results.first.map { nsString.substring(with: $0.range(at: 1)) }
  }

  private static func parseEnclosureUrl(from xml: String) -> String? {
    let pattern = "url=\"([^\"]+)\""
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let nsString = xml as NSString
    let results = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
    return results.first.map { nsString.substring(with: $0.range(at: 1)) }
  }
}
