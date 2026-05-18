import SwiftUI
import Defaults

struct SmartSwitchView: View {
    @Default(.smartSwitchApps) private var smartSwitchApps
    @Default(.smartSwitchEnabled) private var smartSwitchEnabled
    
    @State private var newBundleId: String = ""
    @State private var selectedApp: String? = nil
    
    struct PresetApp: Identifiable {
        let name: String
        let bundleId: String
        let icon: String
        var id: String { bundleId }
    }
    
    // Popular macOS applications bundle IDs as presets
    let presets: [PresetApp] = [
        PresetApp(name: "Terminal", bundleId: "com.apple.Terminal", icon: "terminal"),
        PresetApp(name: "iTerm2", bundleId: "com.googlecode.iterm2", icon: "terminal.fill"),
        PresetApp(name: "VS Code", bundleId: "com.microsoft.VSCode", icon: "curlybraces"),
        PresetApp(name: "Xcode", bundleId: "com.apple.dt.Xcode", icon: "hammer"),
        PresetApp(name: "Raycast", bundleId: "com.raycast.macos", icon: "magnifyingglass.circle"),
        PresetApp(name: "Spotlight", bundleId: "com.apple.Spotlight", icon: "magnifyingglass"),
        PresetApp(name: "Alfred", bundleId: "com.runningwithcrayons.Alfred", icon: "hat.3")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Switch")
                            .font(.headline)
                        Text("Tự tắt Tiếng Việt khi chuyển sang ứng dụng lập trình/tìm kiếm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle("Kích hoạt tính năng Smart Switch", isOn: $smartSwitchEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .padding(.top, 8)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if !smartSwitchEnabled {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Tính năng đang tắt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Bật Smart Switch để tự động quản lý bộ gõ cho từng ứng dụng.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                HSplitView {
                    // Left Column: List of current Apps
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ỨNG DỤNG BỊ GIỚI HẠN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        
                        List(smartSwitchApps, id: \.self, selection: $selectedApp) { app in
                            HStack {
                                Image(systemName: "app.dashed")
                                    .foregroundStyle(.secondary)
                                Text(app)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                            }
                            .tag(app)
                        }
                        .listStyle(.inset)
                        
                        // Add Bundle ID text field and buttons
                        HStack(spacing: 8) {
                            TextField("com.company.app", text: $newBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .onSubmit {
                                    addNewApp()
                                }
                            
                            Button(action: addNewApp) {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help("Thêm ứng dụng")
                            
                            Button(action: removeSelectedApp) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedApp == nil)
                            .help("Xóa ứng dụng đang chọn")
                        }
                        .padding(10)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                    .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Right Column: Presets & Info
                    VStack(alignment: .leading, spacing: 14) {
                        Text("THÊM NHANH MẪU CÓ SẴN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(presets) { preset in
                                    let isAdded = smartSwitchApps.contains(preset.bundleId)
                                    Button(action: {
                                        if isAdded {
                                            smartSwitchApps.removeAll(where: { $0 == preset.bundleId })
                                        } else {
                                            smartSwitchApps.append(preset.bundleId)
                                        }
                                    }) {
                                        HStack {
                                            Label(preset.name, systemImage: preset.icon)
                                            Spacer()
                                            if isAdded {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                            } else {
                                                Image(systemName: "plus.circle")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("💡 Cách lấy Bundle ID:")
                                .font(.caption)
                                .bold()
                            Text("Mở Terminal và gõ lệnh sau để lấy Bundle ID của ứng dụng đang chạy:")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            
                            Text("osascript -e 'id of app \"Tên Ứng Dụng\"'")
                                .font(.system(size: 9, design: .monospaced))
                                .padding(6)
                                .background(Color.black.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 190)
                    .frame(maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(width: 440, height: 540)
    }
    
    private func addNewApp() {
        let cleanId = newBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        
        if !smartSwitchApps.contains(cleanId) {
            smartSwitchApps.append(cleanId)
        }
        newBundleId = ""
    }
    
    private func removeSelectedApp() {
        guard let selected = selectedApp else { return }
        smartSwitchApps.removeAll(where: { $0 == selected })
        selectedApp = nil
    }
}

struct SmartSwitchView_Previews: PreviewProvider {
    static var previews: some View {
        SmartSwitchView()
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
    }
}
