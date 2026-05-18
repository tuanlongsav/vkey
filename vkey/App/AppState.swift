//
//  AppState.swift
//  vkey
//
//  Created by KhanhIceTea on 20/02/2024.
//

import Cocoa
import Combine
import Defaults
import Foundation
import KeyboardShortcuts

class AppState: ObservableObject, FileMonitorDelegate {

    /// Launcher / search apps that should default to English typing.
    /// vkey auto-disables in these apps but does not persist that to `appModes`,
    /// so the underlying app's mode is restored when the launcher closes.
    static let SmartSwitchApps: Set<String> = [
        "com.apple.Spotlight",
        "com.raycast.macos",
        "com.runningwithcrayons.Alfred",
        "com.runningwithcrayons.Alfred-Preferences",
        "com.obdev.LaunchBar",
    ]

    /// When true, the next `enabled` mutation skips persistence into `appModes`.
    /// Used by Smart Switch so launcher apps don't pollute the per-app memory.
    private var skipPersistAppMode = false
    private var switchFileMonitor: FileMonitor?
    private var smartSwitchActive = false
    private var enabledBeforeSmartSwitch = false

    @Published public var enabled = false {
        didSet {
            if !skipPersistAppMode {
                self.appModes[self.activeAppName] = enabled
            }
            self.eventHook.setEnabled(enabled)
        }
    }
    @Published public var typingMethod: TypingMethods {
        didSet {
            self.inputProcessor.changeTypingMethod(newMethod: typingMethod)
            Defaults[.typingMethod] = typingMethod
        }
    }
    @Published public var allowedZWJF: Bool {
        didSet {
            if allowedZWJF {
                TiengViet.PhuAmDau =
                    TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
            } else {
                TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
            }
            TiengViet.updatePhuAmDauTrie()

            Defaults[.allowedZWJF] = allowedZWJF
        }
    }
    @Published public var secureInputActive = false

    public var inputProcessor: InputProcessor
    public var eventHook: EventHook
    @Published public var appModes: [String: Bool] = [:]
    @Published public var activeAppName = "Unknown"
    public var bundleId: String

    init() {
        bundleId = Bundle.main.bundleIdentifier ?? "dev.longht.vkey"

        let defaultMethod = Defaults[.typingMethod]
        // Use direct assignment to avoid didSet during init if not needed, 
        // but here we want to ensure side effects are consistent.
        // Actually, didSet does NOT run in init.
        typingMethod = defaultMethod
        allowedZWJF = Defaults[.allowedZWJF]
        
        let processor = InputProcessor(method: defaultMethod)
        inputProcessor = processor
        eventHook = EventHook(inputProcessor: processor)

        // Initial setup for allowedZWJF side effects since didSet doesn't run in init
        if allowedZWJF {
            TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
        } else {
            TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
        }
        TiengViet.updatePhuAmDauTrie()

        KeyboardShortcuts.onKeyUp(for: .toggleInputMode) { [self] in
            self.setEnabled(set: !self.enabled)
        }

        // Register application change observer
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    public func load() {
        // Load something later
    }

    public func isNewAppVersion() -> Bool {
        let storedVersion = Defaults[.currentVersion]
        return storedVersion != "0.1" && Bundle.main.appVersionLong != storedVersion
    }

    public func storeTrustedAppVersion() {
        Defaults[.currentVersion] = Bundle.main.appVersionLong
    }

    public func setTypingMethod(method: TypingMethods) {
        typingMethod = method
    }

    public func setEnabled(set state: Bool) {
        enabled = state
    }

    func registerSwitchFileMonitor() {
        let tmpPath = URL(fileURLWithPath: "/tmp/vkey_switch")
        try? "".write(to: tmpPath, atomically: true, encoding: .utf8)
        switchFileMonitor = try? FileMonitor(url: tmpPath)
        switchFileMonitor?.delegate = self
    }

    func didReceive(changes: String) {
        setEnabled(set: changes.trimmingCharacters(in: .whitespacesAndNewlines) == "vi")
    }

    @objc func activeApplicationDidChange(notification: Notification) {
        if let activeApp = NSWorkspace.shared.frontmostApplication,
            let appName = activeApp.bundleIdentifier,
            appName != bundleId
        {
            // Smart Switch: launcher / search apps default to English typing
            // without overwriting per-app memory of the underlying app.
            if Defaults[.smartSwitchEnabled],
                AppState.SmartSwitchApps.contains(appName)
            {
                if !smartSwitchActive {
                    enabledBeforeSmartSwitch = enabled
                }
                smartSwitchActive = true
                activeAppName = appName
                inputProcessor.changeActiveApp(activeAppName)
                setEnabledWithoutPersist(false)
                return
            }

            let shouldRestoreBeforeSmartSwitch = smartSwitchActive
            smartSwitchActive = false
            activeAppName = appName
            inputProcessor.changeActiveApp(activeAppName)

            if let appMode = appModes[activeAppName] {
                setEnabled(set: appMode)
            } else if shouldRestoreBeforeSmartSwitch {
                setEnabled(set: enabledBeforeSmartSwitch)
            } else {
                setEnabled(set: enabled)
            }
        }
    }

    /// Apply an enabled state change without writing it to per-app memory.
    /// Used by Smart Switch so transient launcher activations don't override
    /// the user's preference for the app underneath.
    private func setEnabledWithoutPersist(_ value: Bool) {
        skipPersistAppMode = true
        enabled = value
        skipPersistAppMode = false
    }
}
