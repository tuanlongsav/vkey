//
//  VKSpellTab.swift
//  vkey — Tab "Chính tả" redesign (đầy đủ chức năng 2.15).
//

import Defaults
import SwiftUI

struct VKSpellTab: View {
  @Default(.spellCheckEnabled) private var spellCheck
  @Default(.suggestionEnabled) private var suggestion
  @Default(.autoApplyHighConfidenceSuggestion) private var autoApply
  @Default(.personalDictionaryEnabled) private var personalDict
  @Default(.autoPersonalDictFeedback) private var weeklyFeedback
  @Default(.wordPredictionEnabled) private var wordPrediction
  @Default(.englishAutoRestoreEnabled) private var spaceRestore
  @Default(.restorePolicy) private var restorePolicy
  @Default(.useEnVnReference) private var useRefDict
  @Default(.predictionHUDLineOffset) private var hudOffset
  @Default(.predictionHUDFontSize) private var hudFontSize
  @Default(.predictionMaxWords) private var predictionMaxWords
  @Default(.hudOpacityPercent) private var hudOpacity

  @State private var showingDictEditor = false

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      // Cấu hình kiểm tra chính tả
      VKSection("Cấu hình kiểm tra chính tả") {
        VKRowGroup {
          VKToggleRow(icon: "checkmark.seal.fill", iconColor: VK.Color.success,
                      label: "Kiểm tra chính tả", isOn: $spellCheck)
          if spellCheck {
            VKToggleRow(icon: "lightbulb.fill", iconColor: VK.Color.gold,
                        label: "Gợi ý sửa lỗi chính tả", isOn: $suggestion)
            if suggestion {
              VKToggleRow(icon: "wand.and.stars", iconColor: VK.Color.info,
                          label: "Tự động sửa khi tin cậy cao", isOn: $autoApply)
            }
            VKToggleRow(icon: "person.fill", iconColor: VK.Color.ink200,
                        label: "Sử dụng từ điển cá nhân", isOn: $personalDict)
            VKRow(icon: "character.book.closed.fill", iconColor: VK.Color.brand,
                  label: "Từ điển cá nhân") {
              VKButton(title: "Quản lý", icon: "slider.horizontal.3", variant: .secondary, size: .sm) {
                showingDictEditor = true
              }
            }
            VKToggleRow(icon: "arrow.clockwise", iconColor: VK.Color.brand,
                        label: "Tự động đề xuất hàng tuần",
                        hint: "Học từ thống kê sử dụng để gợi ý bổ sung từ điển.",
                        isOn: $weeklyFeedback)
          }
        }
      }

      // Đoán từ tiếp theo
      if spellCheck {
        VKSection("Đoán từ tiếp theo") {
          VKRowGroup {
            VKToggleRow(icon: "sparkles", iconColor: VK.Color.gold,
                        label: "Bật đoán từ",
                        hint: "Hiện HUD nhỏ cạnh con trỏ, nhấn ⇥ Tab để nhận cụm 1–3 từ.",
                        isOn: $wordPrediction)
            if wordPrediction {
              VKRow(icon: "text.word.spacing", iconColor: VK.Color.gold,
                    label: "Số từ gợi ý tối đa") {
                stepperControl(value: $predictionMaxWords, range: 1...3, unit: "từ")
              }
              VKRow(icon: "arrow.up.and.down", iconColor: VK.Color.info,
                    label: "Khoảng cách HUD đến con trỏ") {
                stepperControl(value: $hudOffset, range: 1...20, unit: "dòng")
              }
              VKRow(icon: "textformat.size", iconColor: VK.Color.ink200,
                    label: "Cỡ chữ HUD") {
                stepperControl(value: $hudFontSize, range: 12...24, unit: "pt")
              }
              VKRow(icon: "circle.lefthalf.filled", iconColor: VK.Color.brand,
                    label: "Độ đậm HUD") {
                stepperControl(value: $hudOpacity, range: 30...100, step: 5, unit: "%")
              }
            }
          }
        }
      }

      // Space Restore
      if spellCheck {
        VKSection("Tự động khôi phục tiếng Anh · Space Restore") {
          VKRowGroup {
            VKToggleRow(icon: "return", iconColor: VK.Color.info,
                        label: "Tự động khôi phục tiếng Anh", isOn: $spaceRestore)
            if spaceRestore {
              VKRow(icon: "slider.horizontal.3", iconColor: VK.Color.ink200,
                    label: "Chính sách khôi phục") {
                VKSegmented(selection: $restorePolicy,
                            options: [(.vietnameseFirst, "Ưu tiên VI"),
                                      (.balanced, "Cân bằng"),
                                      (.englishFirst, "Ưu tiên EN")])
              }
              VKToggleRow(icon: "character.book.closed.fill", iconColor: VK.Color.gold,
                          label: "Dùng từ điển tham chiếu Anh – Việt", isOn: $useRefDict)
            }
          }
          VKGroupHint("Lựa chọn cách xử lý với các từ mơ hồ giữa tiếng Việt và tiếng Anh (ví dụ: 'of', 'if', 'see', 'tee').")
        }
      }
    }
    .sheet(isPresented: $showingDictEditor) {
      PersonalDictionaryEditorView()
    }
  }

  // Value đặt rõ bên trái + Stepper bare bên phải (không bị cắt như cũ).
  @ViewBuilder
  private func stepperControl(value: Binding<Int>, range: ClosedRange<Int>,
                              step: Int = 1, unit: String) -> some View {
    HStack(spacing: 8) {
      Text("\(value.wrappedValue) \(unit)")
        .font(.system(size: 12.5, weight: .medium, design: .rounded))
        .foregroundStyle(VK.Color.fg2)
        .frame(minWidth: 52, alignment: .trailing)
        .monospacedDigit()
      Stepper("", value: value, in: range, step: step)
        .labelsHidden()
    }
    .fixedSize()
  }
}
