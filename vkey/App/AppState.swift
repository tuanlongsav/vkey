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
import os.log

private let appLog = OSLog(subsystem: "dev.longht.vkey", category: "AppState")

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
    public var smartSwitchActive = false
    public var enabledBeforeSmartSwitch = false
    private var skipHUDNotification = true

    @Published public var enabled = false {
        didSet {
            if !skipPersistAppMode {
                self.appModes[self.activeAppName] = enabled
            }
            self.eventHook.setEnabled(enabled)
            
            if !skipHUDNotification {
                DispatchQueue.main.async {
                    ToggleHUDWindow.shared.show(isEnabled: self.enabled)
                }
            }
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
            
        // Enable HUD notifications after a brief delay once startup is fully completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.skipHUDNotification = false
        }
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
        do {
            try "".write(to: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            os_log("AppState: failed to seed %{public}@ — %{public}@",
                   log: appLog, type: .error, tmpPath.path, error.localizedDescription)
            // Continue: monitor init may still succeed if the file already exists.
        }
        do {
            switchFileMonitor = try FileMonitor(url: tmpPath)
            switchFileMonitor?.delegate = self
        } catch {
            os_log("AppState: FileMonitor init failed for %{public}@ — %{public}@. Smart Switch via /tmp signalling disabled.",
                   log: appLog, type: .error, tmpPath.path, error.localizedDescription)
            // Smart Switch via AX probing still works; the /tmp signalling is
            // a secondary path (used by some launcher integrations).
        }
    }

    func didReceive(changes: String) {
        setEnabled(set: changes.trimmingCharacters(in: .whitespacesAndNewlines) == "vi")
    }

    @objc func activeApplicationDidChange(notification: Notification) {
        let wasSkippingHUD = skipHUDNotification
        skipHUDNotification = true
        defer { skipHUDNotification = wasSkippingHUD }

        if let activeApp = NSWorkspace.shared.frontmostApplication,
            let appName = activeApp.bundleIdentifier,
            appName != bundleId
        {
            // 1.7.0: ưu tiên đọc từ appSmartSwitchConfigs (3-state).
            // Fallback smartSwitchApps để backward-compat user chưa migrate.
            let configs = Defaults[.appSmartSwitchConfigs]
            if Defaults[.smartSwitchEnabled], let config = configs[appName] {
                if !smartSwitchActive {
                    enabledBeforeSmartSwitch = enabled
                }
                smartSwitchActive = true
                activeAppName = appName
                inputProcessor.changeActiveApp(activeAppName)
                switch config.state {
                case .disabled, .englishMode:
                    setEnabledWithoutPersist(false)
                case .vietnameseMode:
                    setEnabledWithoutPersist(true)
                }
                return
            }

            // Legacy fallback: smartSwitchApps list (will be migrated later).
            if Defaults[.smartSwitchEnabled],
                Defaults[.smartSwitchApps].contains(appName)
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

    /// 1.7.0: Migration smartSwitchApps (list) → appSmartSwitchConfigs (3-state map).
    /// Chạy 1 lần khi app launch v1.7.0 và `appSmartSwitchConfigs` đang rỗng
    /// (user chưa migrate). Idempotent — gọi nhiều lần không sao.
    public static func migrateSmartSwitchTo3State() {
        guard Defaults[.appSmartSwitchConfigs].isEmpty else { return }
        var newConfigs: [String: AppSmartSwitchConfig] = [:]
        let now = Date()
        for bundleId in Defaults[.smartSwitchApps] {
            newConfigs[bundleId] = AppSmartSwitchConfig(
                state: .englishMode,
                source: .user,
                lastModified: now
            )
        }
        Defaults[.appSmartSwitchConfigs] = newConfigs
    }

    /// 1.7.0: User manual override → ghi vào appSmartSwitchConfigs với source=.user.
    /// Gọi từ UI khi user click chuyển state thủ công, hoặc từ menu bar toggle.
    public func setAppSmartSwitchState(_ state: AppSmartSwitchState, bundleId: String) {
        var configs = Defaults[.appSmartSwitchConfigs]
        configs[bundleId] = AppSmartSwitchConfig(
            state: state,
            source: .user,
            lastModified: Date()
        )
        Defaults[.appSmartSwitchConfigs] = configs
    }

    /// 1.7.0: Reset 1 app về auto-learn → xoá entry, lần check kế tiếp
    /// auto-learn sẽ re-evaluate.
    public func resetAppSmartSwitchToAutoLearn(bundleId: String) {
        var configs = Defaults[.appSmartSwitchConfigs]
        configs.removeValue(forKey: bundleId)
        Defaults[.appSmartSwitchConfigs] = configs
    }

    /// 1.7.0: Apply auto-learn suggestions → ghi vào configs với source=.autoLearn.
    /// User-set entries (source=.user) KHÔNG bị override.
    public func applySmartSwitchAutoLearn(_ suggestions: [String: AppSmartSwitchState]) {
        var configs = Defaults[.appSmartSwitchConfigs]
        let now = Date()
        var updated = 0
        for (bundleId, state) in suggestions {
            // Skip nếu đã có user setting
            if let existing = configs[bundleId], existing.source == .user { continue }
            // Skip nếu state đã đúng (giữ lastModified ổn định)
            if configs[bundleId]?.state == state { continue }
            configs[bundleId] = AppSmartSwitchConfig(
                state: state,
                source: .autoLearn,
                lastModified: now
            )
            updated += 1
        }
        if updated > 0 {
            Defaults[.appSmartSwitchConfigs] = configs
        }
    }

    /// Apply an enabled state change without writing it to per-app memory.
    /// Used by Smart Switch so transient launcher activations don't override
    /// the user's preference for the app underneath.
    public func setEnabledWithoutPersist(_ value: Bool) {
        let wasSkippingHUD = skipHUDNotification
        skipHUDNotification = true
        skipPersistAppMode = true
        enabled = value
        skipPersistAppMode = false
        skipHUDNotification = wasSkippingHUD
    }
}
