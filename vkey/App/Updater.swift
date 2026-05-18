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
      updaterController.checkForUpdates(nil)
    } else {
      // Silent automatic check in background on application launch
      updaterController.updater.checkForUpdatesInBackground()
    }
  }
}
