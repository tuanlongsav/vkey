//
//  FontRegistration.swift
//  vkey
//
//  v2.3.0: register bundled custom fonts at process scope.
//
//  This is the ONLY thing registering the bundled fonts. It iterates over the
//  bundled `.ttf` files and calls `CTFontManagerRegisterFontsForURL(_,
//  .process)`. Idempotent — it swallows the "already registered" error code,
//  so calling it more than once is safe.
//
//  Earlier comments here described it as a "Tier 2 fallback" behind an
//  `ATSApplicationFontsPath = Resources` key in Info.plist that would let
//  macOS auto-register the folder at launch. That key has never existed —
//  not in vkey/Info.plist and not in the build settings — so there was no
//  Tier 1 to fall back from. Adding it would give real defence in depth;
//  until then, if this call fails the custom fonts are simply absent and
//  `VKeyDesign.display` quietly falls back to the system rounded face.
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
