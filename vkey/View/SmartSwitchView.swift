import SwiftUI
import Defaults
import AppKit

/// SmartSwitchView 1.7.0: 3-state per-app (Tiếng Việt / Tiếng Anh / Không
/// dùng vkey) + source icon (👤 user / 🤖 auto-learn). Thay UI list 1-chiều
/// cũ. Tự động học state từ Stats per-app language ratio (≥5 ngày dataset,
/// ≥5 commit/ngày, ratio ≥75%).
struct SmartSwitchView: View {
    @Default(.appSmartSwitchConfigs) private var configs
    @Default(.smartSwitchEnabled) private var smartSwitchEnabled

    @State private var newBundleId: String = ""
    @State private var selectedBundleId: String? = nil
    @State private var editingBundleId: String? = nil
    @State private var showingAutoLearnSheet = false

    var sortedConfigs: [(bundleId: String, config: AppSmartSwitchConfig)] {
        configs.sorted { $0.key < $1.key }
            .map { (bundleId: $0.key, config: $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                ThemedSymbol(name: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Switch")
                        .font(.headline)
                    Text("Tự động chọn chế độ gõ phù hợp cho từng ứng dụng (Tiếng Việt / Tiếng Anh / Tắt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $smartSwitchEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .labelsHidden()
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if !smartSwitchEnabled {
                VStack(spacing: 12) {
                    Spacer()
                    ThemedSymbol(name: "arrow.left.arrow.right.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Tính năng đang tắt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Kích hoạt Smart Switch ở menu bar hoặc toggle phía trên.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Legend + auto-learn button
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.blue)
                            Text("Người dùng đặt")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .foregroundStyle(.purple)
                            Text("Tự động học")
                        }
                        Spacer()
                        Button {
                            showingAutoLearnSheet = true
                        } label: {
                            Label("Tự học từ Thống kê", themedSymbol: "wand.and.stars")
                        }
                        .help("Xem các app vkey gợi ý đổi state dựa trên thống kê ngôn ngữ.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    // App list
                    if sortedConfigs.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            ThemedSymbol(name: "tray")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("Chưa có app nào được cấu hình")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("Thêm bundle ID bên dưới hoặc bấm \"Tự học từ Thống kê\".")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(selection: $selectedBundleId) {
                            ForEach(sortedConfigs, id: \.bundleId) { item in
                                AppConfigRow(
                                    bundleId: item.bundleId,
                                    config: item.config,
                                    onStateChange: { newState in
                                        setState(newState, for: item.bundleId)
                                    },
                                    onReset: { resetToAutoLearn(item.bundleId) }
                                )
                                .tag(item.bundleId)
                            }
                        }
                        .listStyle(.inset)
                    }

                    Divider()

                    // Add bundle ID input
                    HStack(spacing: 8) {
                        TextField("com.example.app", text: $newBundleId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { addNewApp() }

                        Button(action: addNewApp) {
                            Label("Thêm", themedSymbol: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(action: removeSelected) {
                            Label("Xoá", themedSymbol: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedBundleId == nil)
                    }
                    .padding(10)
                    .background(Color(NSColor.windowBackgroundColor))

                    // Help text
                    Text("💡 Lấy Bundle ID: mở Terminal → `osascript -e 'id of app \"Tên App\"'`. Hoặc click app trong danh sách trên rồi bấm \"Sửa\" để đổi state thủ công.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 480, minHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAutoLearnSheet) {
            SmartSwitchAutoLearnSheet()
        }
    }

    // MARK: - Actions

    private func addNewApp() {
        let cleanId = newBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        if configs[cleanId] == nil {
            configs[cleanId] = AppSmartSwitchConfig(
                state: .englishMode, source: .user, lastModified: Date()
            )
        }
        newBundleId = ""
    }

    private func removeSelected() {
        guard let sel = selectedBundleId else { return }
        configs.removeValue(forKey: sel)
        selectedBundleId = nil
    }

    private func setState(_ state: AppSmartSwitchState, for bundleId: String) {
        configs[bundleId] = AppSmartSwitchConfig(
            state: state, source: .user, lastModified: Date()
        )
    }

    private func resetToAutoLearn(_ bundleId: String) {
        configs.removeValue(forKey: bundleId)
    }
}

// MARK: - Row UI

private struct AppConfigRow: View {
    let bundleId: String
    let config: AppSmartSwitchConfig
    let onStateChange: (AppSmartSwitchState) -> Void
    let onReset: () -> Void

    @State private var showingPicker = false

    var displayName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                  ?? bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleId
    }

    var stateBadgeColor: Color {
        switch config.state {
        case .disabled: return .gray
        case .vietnameseMode: return .red
        case .englishMode: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                Text(bundleId)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // State badge
            Text(config.state.shortLabel)
                .font(.system(.caption, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(stateBadgeColor.opacity(0.15))
                .foregroundStyle(stateBadgeColor)
                .clipShape(Capsule())

            // Source icon
            Image(systemName: config.source.iconSymbol)
                .font(.system(size: 12))
                .foregroundStyle(config.source == .user ? .blue : .purple)
                .help(config.source.displayName)

            // Edit button
            Button {
                showingPicker = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderless)
            .help("Sửa state cho ứng dụng này")
            .popover(isPresented: $showingPicker) {
                AppConfigPicker(
                    bundleId: bundleId,
                    currentState: config.state,
                    currentSource: config.source,
                    onSelectState: { state in
                        onStateChange(state)
                        showingPicker = false
                    },
                    onReset: {
                        onReset()
                        showingPicker = false
                    }
                )
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AppConfigPicker: View {
    let bundleId: String
    let currentState: AppSmartSwitchState
    let currentSource: AppSmartSwitchSource
    let onSelectState: (AppSmartSwitchState) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chọn chế độ cho")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(bundleId)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(AppSmartSwitchState.allCases, id: \.self) { state in
                Button {
                    onSelectState(state)
                } label: {
                    HStack {
                        Image(systemName: state == currentState ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(state == currentState ? Color.accentColor : Color.secondary)
                        Text(state.displayName)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if currentSource == .user {
                Divider()
                Button {
                    onReset()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .foregroundStyle(.purple)
                        Text("Để vkey tự học (auto-learn)")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Xoá cấu hình thủ công → lần check kế tiếp auto-learn sẽ re-evaluate.")
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}

struct SmartSwitchView_Previews: PreviewProvider {
    static var previews: some View {
        SmartSwitchView()
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
    }
}
