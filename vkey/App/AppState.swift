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

    // 2.0 (B2): theo dõi non-Latin IME để tự động disable vkey.
    private let inputSourceMonitor = InputSourceMonitor()
    public private(set) var nonLatinIMEActive = false
    private var enabledBeforeNonLatinIME = false

    // 2.0 (B1): cache resolved overrides cho focused context. Tránh
    // gọi AX query mỗi keystroke.
    public private(set) var activeRuleOverrides: ResolvedRuleOverrides = .init()
    public private(set) var activeRuleOverridesBundleId: String?
    private var ruleOverrideActive = false
    private var enabledBeforeRuleOverride = false
    /// State VI/EN đã apply từ Window Title Rule — tránh toggle lại mỗi focus refresh.
    private var appliedRuleOverrideState: AppSmartSwitchState?

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

    /// 1.7.x: cached bundle ID của focused app — cập nhật bởi NSWorkspace
    /// notification (cross-app) và async AX refresh trên mouse-click
    /// (cho in-app sub-window focus). EventHook callback đọc property
    /// này thay vì gọi `Focused.focusedAppBundleId()` đồng bộ.
    public private(set) var currentFocusedBundleId: String?
    public private(set) var currentFocusedElementIsSearchOrCombo = false {
        didSet {
            inputProcessor.isSearchOrComboFocused = currentFocusedElementIsSearchOrCombo
        }
    }
    /// v3.9: phân loại field đang focus (web content / hộp thoại native /
    /// field cửa sổ chính). InputProcessor dùng để chọn diff NFC/NFD và chiến
    /// lược gửi (omnibox Chrome = windowField của app NFD → axDirect).
    public private(set) var currentFocusedFieldKind: Focused.FieldKind = .unknown {
        didSet {
            inputProcessor.focusedFieldKind = currentFocusedFieldKind
        }
    }
    private let focusRefreshQueue = DispatchQueue(label: "dev.longht.vkey.focusRefresh", qos: .userInteractive)
    /// v3.6: refresh trễ thứ hai (coalesced) — hộp thoại native (Save panel)
    /// xuất hiện SAU ⌘S/click một nhịp nên refresh ngay tại event còn thấy
    /// focus cũ; nhịp trễ ~0.5s bắt đúng field mới.
    private var pendingDelayedFocusRefresh: DispatchWorkItem?
    private var wordPredictionSettingsObserver: Defaults.Observation?

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

        // 2.0.1: Floating Toolbar handler đã bị xoá cùng với tính năng.

        // 2.0 (B4): mở Text Conversion menu cho selection.
        KeyboardShortcuts.onKeyUp(for: .openTextConversionMenu) {
            DispatchQueue.main.async {
                TextConversionService.shared.openMenu(near: nil)
            }
        }

        ClipboardHistoryHotkey.installDefaultIfNeeded()

        // Register application change observer
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        // 1.7.x: seed currentFocusedBundleId từ frontmost app — đảm bảo
        // EventHook callback có giá trị valid trước khi notification đầu
        // tiên fire (e.g. app khởi động khi Spotlight đang mở).
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let bid = frontmost.bundleIdentifier,
           bid != bundleId
        {
            currentFocusedBundleId = bid
            refreshFocusedBundleIdAsync()
        }
            
        // Enable HUD notifications after a brief delay once startup is fully completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.skipHUDNotification = false
        }

        // 2.0 (B2): theo dõi input source change.
        inputSourceMonitor.onInputSourceChange = { [weak self] category in
            self?.handleInputSourceCategoryChange(category)
        }
        inputSourceMonitor.start()

        wordPredictionSettingsObserver = Defaults.observe(
            keys: .wordPredictionEnabled, .wordPredictionExcludedApps,
            options: []
        ) { [weak self] in
            self?.inputProcessor.refreshWordPredictionState()
        }
    }

    deinit {
        // Gỡ observer NSWorkspace đã đăng ký trong init để tránh leak nếu
        // AppState bị tái tạo (observer giữ tham chiếu tới self).
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    /// 2.0 (B2): xử lý khi user chuyển input source. Khi sang non-Latin IME
    /// (Japanese / Chinese / Korean / Thai / Arabic …) — vkey tự động
    /// disable và nhớ state trước đó. Khi quay về Latin — restore state.
    /// Logic không chạm vào `appModes` để tránh ô nhiễm per-app memory.
    private func handleInputSourceCategoryChange(_ category: InputSourceCategory) {
        guard Defaults[.nonLatinIMEAutoDisable] else {
            // Toggle off → nếu đang bị disable bởi non-Latin trước đó,
            // restore state để không kẹt user.
            if nonLatinIMEActive {
                nonLatinIMEActive = false
                setEnabledWithoutPersist(enabledBeforeNonLatinIME)
            }
            return
        }

        switch category {
        case .nonLatin:
            if !nonLatinIMEActive {
                enabledBeforeNonLatinIME = enabled
                nonLatinIMEActive = true
                setEnabledWithoutPersist(false)
                os_log("AppState: non-Latin IME active — vkey disabled",
                       log: appLog, type: .info)
            }
        case .latin, .unknown:
            if nonLatinIMEActive {
                nonLatinIMEActive = false
                setEnabledWithoutPersist(enabledBeforeNonLatinIME)
                os_log("AppState: Latin input source restored — vkey re-enabled to %{public}@",
                       log: appLog, type: .info, String(enabledBeforeNonLatinIME))
            }
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
        let uid = getuid()
        let tmpPath = URL(fileURLWithPath: "/tmp/vkey_switch_\(uid)")
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
            // 1.7.x: cập nhật cached focused bundle ID — push-based,
            // tránh AX query đồng bộ trong EventHook callback.
            currentFocusedBundleId = appName
            refreshFocusedBundleIdAsync()

            refreshRuleOverrides(for: appName)
            activeAppName = appName
            inputProcessor.changeActiveApp(activeAppName)

            if applyActiveRuleOverrideState() {
                return
            }

            // 1.7.0: ưu tiên đọc từ appSmartSwitchConfigs (3-state).
            // Fallback smartSwitchApps để backward-compat user chưa migrate.
            let configs = Defaults[.appSmartSwitchConfigs]
            if Defaults[.smartSwitchEnabled], let config = configs[appName] {
                if !smartSwitchActive {
                    enabledBeforeSmartSwitch = enabled
                }
                smartSwitchActive = true
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
                setEnabledWithoutPersist(false)
                return
            }

            let shouldRestoreBeforeSmartSwitch = smartSwitchActive
            smartSwitchActive = false

            if let appMode = appModes[activeAppName] {
                setEnabled(set: appMode)
            } else if shouldRestoreBeforeSmartSwitch {
                setEnabled(set: enabledBeforeSmartSwitch)
            } else {
                setEnabled(set: enabled)
            }
        }
    }

    /// v2.11: cập nhật cache focused-bundle từ event-target PID — EventHook
    /// đọc PID đích trực tiếp trên mỗi event nên chính xác hơn AX refresh
    /// cho overlay UIElement (Spotlight). Gọi trên main run loop (event tap).
    public func noteFocusedBundleId(_ bid: String) {
        currentFocusedBundleId = bid
        if activeRuleOverridesBundleId != bid {
            if ruleOverrideActive {
                ruleOverrideActive = false
                setEnabledWithoutPersist(enabledBeforeRuleOverride)
            }
            activeRuleOverrides = .init()
            activeRuleOverridesBundleId = nil
            appliedRuleOverrideState = nil
            inputProcessor.ruleOverrides = .init()
            inputProcessor.updateAdaptiveFlushDelay()
            refreshRuleOverrides(for: bid, invalidate: false)
            _ = applyActiveRuleOverrideState()
        }
    }

    /// v3.13: snapshot AX đồng bộ ngay trước transform — `focusedFieldKind` async
    /// không kịp sau Cmd+L / click omnibox rồi gõ nhanh.
    public func syncFocusedContextForKeystroke() {
        let snap = Focused.snapshot()
        if let bid = snap.bundleId {
            currentFocusedBundleId = bid
        }
        currentFocusedElementIsSearchOrCombo = snap.isComboOrSearch
        currentFocusedFieldKind = snap.fieldKind
    }

    private func refreshRuleOverrides(for appName: String, invalidate: Bool = true) {
        if invalidate {
            WindowTitleRuleEngine.shared.invalidateCache()
        }
        let evaluated = WindowTitleRuleEngine.shared.evaluate(bundleId: appName)
        guard activeRuleOverridesBundleId != appName || activeRuleOverrides != evaluated else {
            return
        }
        activeRuleOverrides = evaluated
        activeRuleOverridesBundleId = appName
        inputProcessor.ruleOverrides = activeRuleOverrides
        inputProcessor.updateAdaptiveFlushDelay()
        inputProcessor.refreshWordPredictionState()
    }

    @discardableResult
    private func applyActiveRuleOverrideState() -> Bool {
        let target = activeRuleOverrides.overrideState
        if target == appliedRuleOverrideState {
            return target != nil
        }

        if target == nil {
            if ruleOverrideActive {
                ruleOverrideActive = false
                setEnabledWithoutPersist(enabledBeforeRuleOverride)
            }
            appliedRuleOverrideState = nil
            return false
        }

        if !ruleOverrideActive {
            enabledBeforeRuleOverride = enabled
        }
        ruleOverrideActive = true
        appliedRuleOverrideState = target

        switch target! {
        case .disabled, .englishMode:
            setEnabledWithoutPersist(false)
        case .vietnameseMode:
            setEnabledWithoutPersist(true)
        }
        return true
    }

    /// 1.7.x: refresh `currentFocusedBundleId` async — gọi từ EventHook
    /// callback trên mouse-click events. Chạy trên background queue để
    /// không block event tap. NSWorkspace notification đã đủ cho cross-app
    /// switch; refresh này bắt sub-window focus changes trong cùng app.
    public func refreshFocusedBundleIdAsync() {
        focusRefreshQueue.async { [weak self] in
            self?.performFocusedElementRefresh()
        }
        // v3.6: nhịp refresh trễ — hộp thoại native (Save panel của Chrome)
        // mở SAU keystroke/click trigger nên nhịp đầu còn thấy focus cũ.
        // Coalesce: trigger mới hủy nhịp trễ cũ, chỉ giữ 1 pending.
        pendingDelayedFocusRefresh?.cancel()
        let delayed = DispatchWorkItem { [weak self] in
            self?.performFocusedElementRefresh()
        }
        pendingDelayedFocusRefresh = delayed
        focusRefreshQueue.asyncAfter(deadline: .now() + 0.5, execute: delayed)
    }

    /// Đọc AX state của focused element (chạy trên focusRefreshQueue) rồi
    /// publish về main. Tách riêng để refresh ngay + refresh trễ dùng chung.
    /// v3.7: gộp 3 round-trip AX (bundleId + combo/search + web-area) thành
    /// MỘT lần fetch focused element qua `Focused.snapshot()`.
    private func performFocusedElementRefresh() {
        let snap = Focused.snapshot()
        DispatchQueue.main.async {
            self.currentFocusedBundleId = snap.bundleId
            if let focusedBundleId = snap.bundleId,
               focusedBundleId != self.bundleId {
                self.refreshRuleOverrides(for: focusedBundleId, invalidate: false)
                _ = self.applyActiveRuleOverrideState()
            }
            self.currentFocusedElementIsSearchOrCombo = snap.isComboOrSearch
            self.currentFocusedFieldKind = snap.fieldKind
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

    /// v4.11: Spotlight giờ THEO MODE hiện tại (không ép English). Gỡ nó khỏi
    /// cả `smartSwitchApps` (list) lẫn `appSmartSwitchConfigs` (nếu bản cũ đã
    /// seed vào) — chạy 1 lần. An toàn vì Spotlight không cấu hình được qua UI
    /// (luôn là auto-seed, không phải lựa chọn có chủ đích của user). KHÔNG đụng
    /// tới launcher (Raycast/Alfred/LaunchBar) vì đó là app thường user tự chỉnh.
    public static func migrateSpotlightKeepMode() {
        guard !Defaults[.didMigrateSpotlightKeepMode] else { return }
        let spotlight = "com.apple.Spotlight"
        if Defaults[.smartSwitchApps].contains(spotlight) {
            Defaults[.smartSwitchApps].removeAll { $0 == spotlight }
        }
        if Defaults[.appSmartSwitchConfigs][spotlight] != nil {
            Defaults[.appSmartSwitchConfigs].removeValue(forKey: spotlight)
        }
        Defaults[.didMigrateSpotlightKeepMode] = true
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
