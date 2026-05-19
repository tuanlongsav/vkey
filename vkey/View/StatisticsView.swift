//
//  StatisticsView.swift
//  vkey
//
//  Settings tab introduced in 1.5.0 showing weekly usage statistics + the
//  backup/restore controls for personal data. Mirrors the structure of the
//  existing General/SpellCheck views (Form + grouped sections) so it slots
//  into the current TabView without a wholesale UI rewrite.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct StatisticsView: View {
  @Default(.statisticsEnabled) private var statisticsEnabled
  @Default(.autoBackupOnUpgrade) private var autoBackupOnUpgrade

  @State private var currentSummary: UsageSummary?
  @State private var historical: [UsageSummary] = []
  @State private var lastFeedbackChanges: String = ""
  @State private var backupStatus: String = ""

  var body: some View {
    VStack(spacing: 0) {
      Form {
        // MARK: Stats toggle + privacy note
        Section {
          Toggle(isOn: $statisticsEnabled) {
            Label("Ghi nhận thống kê sử dụng", themedSymbol: "chart.bar")
          }
          .toggleStyle(SwitchToggleStyle(tint: .accentColor))

          Text("Dữ liệu chỉ lưu cục bộ tại `~/Library/Application Support/vkey/stats/`. Không có request mạng nào. Bạn có thể xóa toàn bộ bằng nút bên dưới.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("Quyền riêng tư")
        }

        if statisticsEnabled, let s = currentSummary {
          // MARK: Current week summary
          Section {
            statRow("Tổng số từ đã commit", value: "\(s.wordsTotal)")
            statRow("Giữ tiếng Việt", value: "\(s.wordsKeptVietnamese)")
            statRow("Khôi phục tiếng Anh", value: "\(s.wordsRestoredEnglish)")
            statRow("Giữ nguyên (raw)", value: "\(s.wordsKeptRaw)")
            statRow("Có gợi ý", value: "\(s.wordsSuggested)")
            statRow("Smart Switch kích hoạt", value: "\(s.smartSwitchFires)")
          } header: {
            Text("Tuần này — \(s.weekId)")
          }

          // MARK: Top words this week — 1.5.9: thêm trash button mỗi row
          // để user xoá cụm từ cụ thể nếu không muốn auto-promote.
          if !s.topVietnameseWords.isEmpty {
            Section {
              ForEach(s.topVietnameseWords.prefix(10), id: \.word) { wc in
                statDeletableRow(word: wc.word, count: wc.count, category: .vietnamese)
              }
            } header: {
              Text("Top từ tiếng Việt (tuần này)")
            }
          }

          if !s.topEnglishWords.isEmpty {
            Section {
              ForEach(s.topEnglishWords.prefix(10), id: \.word) { wc in
                statDeletableRow(word: wc.word, count: wc.count, category: .english)
              }
            } header: {
              Text("Top từ tiếng Anh / raw (tuần này)")
            }
          }

          if !s.topApps.isEmpty {
            Section {
              ForEach(s.topApps.prefix(5), id: \.word) { wc in
                statDeletableRow(
                  word: wc.word, count: wc.count,
                  category: .app, monospaced: true
                )
              }
            } header: {
              Text("Top app dùng nhiều")
            }
          }

          // MARK: Manual feedback trigger
          Section {
            HStack {
              Spacer()
              Button(action: runFeedback) {
                Label("Chạy đồng bộ Personal Dictionary ngay", themedSymbol: "arrow.triangle.merge")
              }
              .help("Đẩy các từ bạn gõ nhiều lần tuần này vào từ điển cá nhân (Allow / Keep) để lần sau bộ gõ xử lý nhanh hơn.")
              Spacer()
            }
            if !lastFeedbackChanges.isEmpty {
              Text(lastFeedbackChanges)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }

            HStack {
              Spacer()
              Button(role: .destructive, action: clearStats) {
                Label("Xóa toàn bộ dữ liệu thống kê", themedSymbol: "trash")
              }
              .help("Xóa cả tuần này và các tuần đã đóng (~/Library/Application Support/vkey/stats/).")
              Spacer()
            }
          } header: {
            Text("Đồng bộ hành vi vào Personal Dictionary")
          }
        }

        // MARK: Backup / Restore — always visible
        Section {
          Toggle(isOn: $autoBackupOnUpgrade) {
            Label("Tự động hỏi sao lưu khi cập nhật app", themedSymbol: "shippingbox.and.arrow.backward")
          }
          .toggleStyle(SwitchToggleStyle(tint: .accentColor))

          HStack {
            Spacer()
            Button(action: exportNow) {
              Label("Xuất dữ liệu cá nhân", themedSymbol: "square.and.arrow.up")
            }
            Button(action: importNow) {
              Label("Nhập từ tệp sao lưu", themedSymbol: "square.and.arrow.down")
            }
            Spacer()
          }
          if !backupStatus.isEmpty {
            Text(backupStatus)
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.top, 2)
          }

          Text("File JSON gồm Cài đặt, Macro, Từ điển cá nhân (allow/keep/deny), Smart Switch, Per-app override, và thống kê. Tất cả lưu local, không gửi đi đâu.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("Sao lưu & Khôi phục dữ liệu cá nhân")
        }
      }
      .formStyle(.grouped)
      .scrollDisabled(false)
    }
    .frame(width: 440, height: 560)
    .onAppear(perform: refresh)
  }

  // MARK: - Actions

  private func refresh() {
    currentSummary = UsageStatistics.shared.currentWeekSummary()
    historical = UsageStatistics.shared.historicalSummaries()
  }

  private func runFeedback() {
    let summary = UsageStatistics.shared.performWeeklyFeedback()
    if summary.promotedToAllow.isEmpty && summary.promotedToKeep.isEmpty {
      lastFeedbackChanges = "Chưa có từ nào đủ ngưỡng (cần ≥5 lần xuất hiện thống nhất)."
    } else {
      var parts: [String] = []
      if !summary.promotedToAllow.isEmpty {
        parts.append("Allow: +\(summary.promotedToAllow.count) (\(summary.promotedToAllow.prefix(3).joined(separator: ", ")))")
      }
      if !summary.promotedToKeep.isEmpty {
        parts.append("Keep: +\(summary.promotedToKeep.count) (\(summary.promotedToKeep.prefix(3).joined(separator: ", ")))")
      }
      lastFeedbackChanges = "Đã đồng bộ → " + parts.joined(separator: " · ")
    }
    refresh()
  }

  private func clearStats() {
    let alert = NSAlert()
    alert.messageText = "Xóa toàn bộ thống kê?"
    alert.informativeText = "Không thể hoàn tác. Các từ đã được promote sang từ điển cá nhân vẫn giữ nguyên."
    alert.addButton(withTitle: "Xóa")
    alert.addButton(withTitle: "Huỷ")
    alert.alertStyle = .warning
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    UsageStatistics.shared.clearAll()
    lastFeedbackChanges = ""
    refresh()
  }

  // MARK: - Backup / Restore

  private func exportNow() {
    let panel = NSSavePanel()
    panel.title = "Xuất dữ liệu cá nhân vkey"
    let suggested = UserDataMigration.defaultBackupURL()
    panel.nameFieldStringValue = suggested.lastPathComponent
    panel.directoryURL = suggested.deletingLastPathComponent()
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try UserDataMigration.writeAtomically(
        to: url,
        export: UserDataMigration.currentExport()
      )
      backupStatus = "Đã xuất: \(url.lastPathComponent)"
    } catch {
      backupStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
  }

  private func importNow() {
    let panel = NSOpenPanel()
    panel.title = "Nhập dữ liệu cá nhân vkey"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let export = try UserDataMigration.loadFrom(url)
      // Confirm before applying — list-merge by default.
      let confirm = NSAlert()
      confirm.messageText = "Nhập từ \(url.lastPathComponent)?"
      confirm.informativeText = """
      Tệp tạo lúc \(export.exportedAt) — vkey v\(export.appVersion).
      Cài đặt sẽ được ghi đè; các danh sách (macro, allow/keep/deny, smart switch apps) sẽ được gộp vào danh sách hiện tại (không xóa).
      """
      confirm.alertStyle = .informational
      confirm.addButton(withTitle: "Gộp (giữ dữ liệu hiện tại)")
      confirm.addButton(withTitle: "Ghi đè toàn bộ")
      confirm.addButton(withTitle: "Huỷ")
      let resp = confirm.runModal()
      guard resp != .alertThirdButtonReturn else {
        backupStatus = "Đã huỷ."
        return
      }
      let replace = (resp == .alertSecondButtonReturn)
      let changes = UserDataMigration.importExport(export, replaceLists: replace)
      backupStatus = changes.isEmpty
        ? "Không có thay đổi nào — dữ liệu hiện tại đã trùng khớp."
        : "Đã áp dụng \(changes.count) thay đổi."
      // Make engine pick up the new state immediately
      LexiconManager.shared.reload()
    } catch {
      backupStatus = "Lỗi nhập: \(error.localizedDescription)"
    }
  }

  @ViewBuilder
  private func statRow(_ label: String, value: String) -> some View {
    HStack {
      Text(label)
      Spacer()
      Text(value).foregroundStyle(.secondary).monospacedDigit()
    }
  }

  /// Row trong top words/apps có nút trash xoá entry cụ thể (1.5.9+).
  @ViewBuilder
  private func statDeletableRow(
    word: String,
    count: Int,
    category: UsageStatistics.StatCategory,
    monospaced: Bool = false
  ) -> some View {
    HStack {
      if monospaced {
        Text(word).font(.system(.body, design: .monospaced))
      } else {
        Text(word)
      }
      Spacer()
      Text("×\(count)")
        .foregroundStyle(.secondary)
        .monospacedDigit()
      Button {
        UsageStatistics.shared.removeFromCurrentWeek(word: word, category: category)
        // Refresh sau 1 tick để counters update qua queue.async.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          refresh()
        }
      } label: {
        ThemedSymbol(name: "trash")
          .foregroundStyle(.red)
      }
      .buttonStyle(.borderless)
      .help("Xoá cụm này khỏi thống kê tuần này")
    }
  }
}

struct StatisticsView_Previews: PreviewProvider {
  static var previews: some View {
    StatisticsView()
  }
}
