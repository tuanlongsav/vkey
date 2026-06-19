//
//  VKGeneralTab.swift
//  vkey — Tab "Chung" redesign (đầy đủ chức năng 2.15).
//

import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct VKGeneralTab: View {
  @EnvironmentObject var appState: AppState
  @Default(.allowedZWJF) private var allowedZWJF
  @Default(.autoTypoCorrection) private var autoTypo
  @Default(.autoCapitalizeEnabled) private var autoCapitalize
  @Default(.nonLatinIMEAutoDisable) private var nonLatinAutoDisable
  @Default(.hudEnabled) private var hudEnabled
  @Default(.freeMarkModeEnabled) private var freeMark
  @Default(.newStyleTonePlacement) private var newStyleTone
  @Default(.clipboardHistoryEnabled) private var clipboardHistory
  @Default(.clipboardHistoryCapacity) private var clipboardCapacity
  @Default(.clipboardHistoryContentMode) private var clipboardContentMode

  private var methodBinding: Binding<TypingMethods> {
    Binding(get: { appState.typingMethod }, set: { appState.setTypingMethod(method: $0) })
  }
  private var enabledBinding: Binding<Bool> {
    Binding(get: { appState.enabled }, set: { appState.setEnabled(set: $0) })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // MARK: Bộ gõ
      VKSection("Bộ gõ") {
        VKRowGroup {
          VKToggleRow(icon: "keyboard.fill", iconColor: VK.Color.brand,
                      label: "Bật / Tắt gõ tiếng Việt",
                      hint: "Công tắc chính của bộ gõ.", isOn: enabledBinding)
          VKRow(icon: "power", iconColor: VK.Color.ink200, label: "Tự khởi động cùng hệ thống") {
            LaunchAtLogin.Toggle { EmptyView() }
              .labelsHidden().toggleStyle(.switch).tint(VK.Color.brand)
          }
          VKRow(icon: "character.cursor.ibeam", iconColor: VK.Color.info, label: "Kiểu gõ") {
            VKSegmented(selection: methodBinding,
                        options: [(.Telex, "Telex"), (.VNI, "VNI")])
          }
          VKToggleRow(icon: "globe", iconColor: VK.Color.gold,
                      label: "Phụ âm z, w, j, f",
                      hint: "Cho phép gõ trực tiếp các phụ âm vay mượn.",
                      isOn: $allowedZWJF)
        }
      }

      // MARK: Hỗ trợ thông minh
      VKSection("Hỗ trợ thông minh") {
        VKRowGroup {
          VKToggleRow(icon: "sparkles", iconColor: VK.Color.brand,
                      label: "Tự động sửa lỗi gõ nhầm",
                      hint: "thfi → thì · veeitj → việt · phuowgn → phương",
                      isOn: $autoTypo)
          VKToggleRow(icon: "textformat", iconColor: VK.Color.info,
                      label: "Viết hoa đầu câu",
                      hint: "Tự động viết hoa sau dấu chấm, chấm than, chấm hỏi hoặc xuống dòng.",
                      isOn: $autoCapitalize)
          VKToggleRow(icon: "character.bubble.fill", iconColor: VK.Color.success,
                      label: "Tự tắt khi đổi sang bộ gõ khác",
                      hint: "Khi chuyển sang IME Nhật / Trung / Hàn, vkey tạm dừng để tránh xung đột.",
                      isOn: $nonLatinAutoDisable)
          VKToggleRow(icon: "bell.badge.fill", iconColor: VK.Color.gold,
                      label: "Hiển thị thông báo khi chuyển VI / EN",
                      isOn: $hudEnabled)
        }
      }

      // MARK: Cấu hình nâng cao
      VKSection("Cấu hình nâng cao") {
        VKRowGroup {
          VKToggleRow(icon: "pencil.and.scribble", iconColor: VK.Color.ink200,
                      label: "Đặt dấu tự do (Free Mark)",
                      hint: "Cho phép đặt dấu ở vị trí bất kỳ, bỏ qua kiểm tra âm tiết.",
                      isOn: $freeMark)
          VKRow(icon: "textformat.subscript", iconColor: VK.Color.brand,
                label: "Kiểu đặt dấu") {
            VKSegmented(selection: $newStyleTone,
                        options: [(false, "Kiểu cũ"), (true, "Kiểu mới")])
          }
        }
        VKGroupHint(newStyleTone ? "Ví dụ kiểu mới: oà, uý, khoẻ, thuỷ"
                                 : "Ví dụ kiểu cũ: òa, úy, khỏe, thủy")
      }

      // MARK: Phím tắt
      VKSection("Phím tắt chuyển chế độ") {
        VKRowGroup {
          VKRow(icon: "command", iconColor: VK.Color.ink200, label: "Chuyển đổi VI / EN") {
            // Không ép width cứng — NSButton rộng hơn 150 sẽ tràn đè viền card.
            // fixedSize → nút tự co đúng intrinsic size, nằm gọn trong padding.
            FlexibleShortcutRecorder(name: .toggleInputMode)
              .fixedSize()
              .frame(height: 26)
          }
          VKRow(icon: "wand.and.stars", iconColor: VK.Color.info, label: "Mở Text Tools") {
            FlexibleShortcutRecorder(name: .openTextConversionMenu)
              .fixedSize()
              .frame(height: 26)
          }
        }
        VKGroupHint("Nhấn & thả tổ hợp modifier (vd ⌃⇧, ⇧⌥) để chuyển nhanh giữa tiếng Việt và tiếng Anh.")
      }

      // MARK: Clipboard tùy chỉnh
      VKSection("Clipboard tùy chỉnh") {
        VKRowGroup {
          VKToggleRow(icon: "doc.on.clipboard.fill", iconColor: VK.Color.brand,
                      label: "Bật lịch sử clipboard",
                      hint: "⌘C lưu vào danh sách; ⌥⌘V chọn mục để dán. ⌘V và ⇧⌘V dán bình thường.",
                      isOn: $clipboardHistory)
          if clipboardHistory {
            VKRow(icon: "list.number", iconColor: VK.Color.info,
                  label: "Số mục lưu tối đa") {
              clipboardStepper(value: $clipboardCapacity, range: 3...50)
            }
            VKRow(icon: "tray.full.fill", iconColor: VK.Color.ink200,
                  label: "Loại nội dung lưu") {
              VKSegmented(
                selection: $clipboardContentMode,
                options: ClipboardHistoryContentMode.allCases.map { ($0, $0.label) }
              )
            }
            VKRow(icon: "trash", iconColor: VK.Color.warning,
                  label: "Xóa lịch sử hiện tại") {
              VKButton(title: "Xóa", icon: "trash", variant: .secondary, size: .sm) {
                ClipboardHistoryService.shared.clear()
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func clipboardStepper(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    HStack(spacing: 8) {
      Text("\(value.wrappedValue) mục")
        .font(.system(size: 12.5, weight: .medium, design: .rounded))
        .foregroundStyle(VK.Color.fg2)
        .frame(minWidth: 52, alignment: .trailing)
        .monospacedDigit()
      Stepper("", value: value, in: range)
        .labelsHidden()
    }
    .fixedSize()
  }
}
