//
//  WindowRules.swift
//  vkey
//
//  Editor cho Window Title Rules: override theo bundle ID + regex tiêu đề
//  cửa sổ (rule đầu tiên khớp thắng cho `overrideState`, các flag khác cộng
//  dồn). Hữu ích cho web app như Google Docs (cần delay) hay Notion (tắt
//  prediction).
//
//  Tách khỏi SmartSwitchView.swift khi tab Smart Switch đời cũ bị VKSmartTab
//  thay thế; VKSmartTab nhúng lại `WindowRulesSection` dưới dạng
//  DisclosureGroup, mặc định gập vì là tính năng power-user.
//

import AppKit
import Defaults
import SwiftUI


// 2.16: dùng lại ở VKSmartTab (redesign). Bỏ `private`.
struct WindowRulesSection: View {
  @Default(.windowTitleRules) private var rules
  @State private var expanded: Bool = false

  var body: some View {
    DisclosureGroup(isExpanded: $expanded) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Áp dụng override khi bundle ID + window title regex match. Hữu ích cho web apps như Google Docs (cần delay), Notion (tắt prediction). Rule đầu tiên match sẽ thắng cho `overrideState`; các flag khác cộng dồn.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack {
          Spacer()
          Button {
            let rule = WindowTitleRule(name: "Rule mới")
            rules.append(rule)
          } label: {
            Label("Thêm rule", systemImage: "plus.circle.fill")
          }
        }

        if rules.isEmpty {
          HStack {
            Spacer()
            VStack(spacing: 6) {
              Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
              Text("Chưa có rule nào")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("Bấm “Thêm rule” để bắt đầu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            Spacer()
          }
        } else {
          VStack(spacing: 4) {
            ForEach($rules) { $rule in
              WindowRuleRow(rule: $rule) {
                if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                  rules.remove(at: idx)
                }
              }
              .padding(.vertical, 4)
              Divider()
            }
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    } label: {
      HStack(spacing: 10) {
        ThemedSymbol(name: "list.bullet.rectangle.portrait")
          .font(.system(size: 18))
          .foregroundStyle(Color.accentColor)
        VStack(alignment: .leading, spacing: 2) {
          Text("Quy tắc theo cửa sổ (nâng cao)")
            .font(.subheadline).bold()
          Text("Ghi đè theo bundle ID + regex tiêu đề cửa sổ — \(rules.count) quy tắc")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
    }
    .padding(12)
  }
}

struct WindowRuleRow: View {
  @Binding var rule: WindowTitleRule
  let onDelete: () -> Void

  var body: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Tiền tố Bundle ID")
            .frame(width: 130, alignment: .leading)
          TextField("com.google.Chrome", text: $rule.bundleIdPrefix)
            .textFieldStyle(.roundedBorder)
        }
        HStack {
          Text("Regex tiêu đề cửa sổ")
            .frame(width: 130, alignment: .leading)
          TextField("Google Docs|Notion", text: $rule.titleRegex)
            .textFieldStyle(.roundedBorder)
            .monospaced()
        }
        HStack {
          Text("Trạng thái ghi đè")
            .frame(width: 130, alignment: .leading)
          Picker("", selection: Binding(
            get: { rule.overrideState ?? .vietnameseMode },
            set: { rule.overrideState = $0 }
          )) {
            ForEach(AppSmartSwitchState.allCases, id: \.self) { state in
              Text(state.displayName).tag(state)
            }
          }
          .pickerStyle(.menu)
          .frame(width: 200)
          Toggle("Bật ghi đè", isOn: Binding(
            get: { rule.overrideState != nil },
            set: { newVal in
              if newVal {
                rule.overrideState = rule.overrideState ?? .englishMode
              } else {
                rule.overrideState = nil
              }
            }
          ))
        }
        Toggle("Tắt prediction trong context này", isOn: $rule.disablePrediction)
        Toggle("Tắt spell-check trong context này", isOn: $rule.disableSpellCheck)
        HStack {
          Text("Độ trễ thích ứng (ms)")
            .frame(width: 130, alignment: .leading)
          Stepper(value: $rule.flushDelayMs, in: 0...500, step: 10) {
            Text("\(rule.flushDelayMs) ms").monospacedDigit()
          }
        }
        HStack {
          Spacer()
          Button(role: .destructive) {
            onDelete()
          } label: {
            Label("Xoá rule", systemImage: "trash")
          }
        }
      }
      .padding(.vertical, 6)
    } label: {
      HStack {
        Toggle("", isOn: $rule.enabled)
          .toggleStyle(.switch)
          .labelsHidden()
        TextField("Tên rule", text: $rule.name)
          .textFieldStyle(.plain)
        Spacer()
        if !rule.bundleIdPrefix.isEmpty || !rule.titleRegex.isEmpty {
          Text("\(rule.bundleIdPrefix.isEmpty ? "*" : rule.bundleIdPrefix)  ·  \(rule.titleRegex.isEmpty ? "*" : rule.titleRegex)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
  }
}
