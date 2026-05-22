//
//  WindowRulesView.swift
//  vkey
//
//  2.0 (B1): Editor cho Window Title Rules. List + add/edit/delete.
//

import Defaults
import SwiftUI

struct WindowRulesView: View {
  @Default(.windowTitleRules) private var rules
  @State private var editingId: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Quy tắc theo cửa sổ")
          .font(.title3).bold()
        Spacer()
        Button {
          let rule = WindowTitleRule(name: "Rule mới")
          rules.append(rule)
          editingId = rule.id
        } label: {
          Label("Thêm rule", systemImage: "plus.circle.fill")
        }
      }

      Text("Áp dụng override khi bundle ID + window title regex match. Hữu ích cho web apps như Google Docs (cần delay), Notion (tắt prediction). Rule đầu tiên match sẽ thắng cho `overrideState`; các flag khác cộng dồn.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if rules.isEmpty {
        ContentUnavailableViewCompat(
          title: "Chưa có rule nào",
          systemImage: "list.bullet.rectangle",
          subtitle: "Bấm “Thêm rule” để bắt đầu."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach($rules) { $rule in
            WindowRuleRow(rule: $rule) {
              if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                rules.remove(at: idx)
              }
            }
          }
        }
        .listStyle(.inset)
      }
    }
    .padding()
  }
}

private struct WindowRuleRow: View {
  @Binding var rule: WindowTitleRule
  let onDelete: () -> Void

  var body: some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Bundle ID prefix")
            .frame(width: 130, alignment: .leading)
          TextField("com.google.Chrome", text: $rule.bundleIdPrefix)
            .textFieldStyle(.roundedBorder)
        }
        HStack {
          Text("Window title regex")
            .frame(width: 130, alignment: .leading)
          TextField("Google Docs|Notion", text: $rule.titleRegex)
            .textFieldStyle(.roundedBorder)
            .monospaced()
        }
        HStack {
          Text("Override state")
            .frame(width: 130, alignment: .leading)
          Picker("", selection: Binding(
            get: { rule.overrideState ?? .vietnameseMode },
            set: { rule.overrideState = $0 }
          )) {
            Text("(không override)").tag(AppSmartSwitchState.vietnameseMode)
            ForEach(AppSmartSwitchState.allCases, id: \.self) { state in
              Text(state.displayName).tag(state)
            }
          }
          .pickerStyle(.menu)
          .frame(width: 200)
          Toggle("Bật override", isOn: Binding(
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
          Text("Adaptive delay (ms)")
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

/// Compatibility wrapper cho `ContentUnavailableView` (macOS 14+).
private struct ContentUnavailableViewCompat: View {
  let title: String
  let systemImage: String
  let subtitle: String

  var body: some View {
    if #available(macOS 14.0, *) {
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        Text(subtitle)
      }
    } else {
      VStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.largeTitle)
          .foregroundStyle(.secondary)
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding()
    }
  }
}
