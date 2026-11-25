//
//  EngineOptions.swift
//  vkey
//
//  Immutable configuration value passed into the Vietnamese typing engine.
//  Keeps `vkey/Engine/` 100% pure Foundation (zero `Defaults` or AppKit imports).
//

import Foundation

struct EngineOptions: Equatable, Sendable {
  var autoTypoCorrection: Bool = true
  var newStyleTonePlacement: Bool = true
  var freeMarkModeEnabled: Bool = false
  var allowedZWJF: Bool = true

  static let `default` = EngineOptions()
}
