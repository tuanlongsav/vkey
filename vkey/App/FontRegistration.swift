//
//  FontRegistration.swift
//  vkey
//
//  v2.3.0: register bundled custom fonts at process scope.
//
//  Two-tier defensive strategy:
//
//    Tier 1 (preferred): `ATSApplicationFontsPath = Resources` in Info.plist
//                        — macOS auto-registers all `.ttf` / `.otf` in that
//                        folder at launch. No code required.
//
//    Tier 2 (fallback): this file. Iterates over bundled `.ttf` files and
//                       calls `CTFontManagerRegisterFontsForURL(_, .process)`.
//                       Used in case the plist key fails (e.g. font path moves,
//                       sandbox change). Idempotent — silently swallows the
//                       "already registered" error code so calling from Tier 1
//                       contexts is safe.
//

import AppKit
import CoreText
import os.log

enum FontRegistration {
  /// Register all bundled `.ttf` fonts at process scope. Idempotent.
  static func register() {
    guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
      return
    }
    for url in urls {
      var unmanagedError: Unmanaged<CFError>?
      let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &unmanagedError)
      if !ok, let cfError = unmanagedError?.takeRetainedValue() {
        let nsError = cfError as Error as NSError
        // kCTFontManagerErrorAlreadyRegistered = 105 — Tier 1 (ATSApplicationFontsPath)
        // beat us to it. That's a success, not a failure.
        let alreadyRegisteredCode = 105
        if nsError.code != alreadyRegisteredCode {
          os_log(
            "FontRegistration: failed to register %{public}@ — %{public}@",
            log: .default, type: .info,
            url.lastPathComponent, nsError.localizedDescription
          )
        }
      }
    }
  }
}
