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

/// 1.7.4: identifier cho sheet "Xem chi tiết" của top từ — VN hoặc EN.
enum TopWordsDetailCategory: Identifiable {
  case vietnamese
  case english
  var id: Self { self }
  var title: String {
    switch self {
    case .vietnamese: return "Top từ tiếng Việt"
    case .english:    return "Top từ tiếng Anh / ký tự đặc biệt"
    }
  }
  var statCategory: UsageStatistics.StatCategory {
    switch self {
    case .vietnamese: return .vietnamese
    case .english:    return .english
    }
  }
}

struct StatisticsView: View {
  @Default(.statisticsEnabled) private var statisticsEnabled
  @Default(.autoBackupOnUpgrade) private var autoBackupOnUpgrade
  @Default(.pendingDictSuggestions) private var pendingSuggestions

  @State private var currentSummary: UsageSummary?
  @State private var historical: [UsageSummary] = []
  @State private var lastFeedbackChanges: String = ""
  @State private var backupStatus: String = ""
  @State private var diagnosticStatus: String = ""
  @State private var showingSuggestionSheet = false
  @State private var detailCategory: TopWordsDetailCategory?

  var body: some View {
    VStack(spacing: 0) {
      Form {
        // MARK: 1. Stats toggle + privacy note
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

        // MARK: 2. Backup / Restore — 1.6.0: move up ngay sau toggle.
        // Luôn hiển thị (không gate trên statisticsEnabled) vì backup là
        // utility độc lập với việc bật/tắt ghi nhận.
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

        // MARK: 3. Đồng bộ Personal Dictionary — 1.6.0: move up.
        // Luôn hiển thị; runFeedback compute đề xuất (không auto-write).
        Section {
          HStack {
            Spacer()
            Button(action: runFeedback) {
              Label("Chạy compute đề xuất ngay", themedSymbol: "arrow.triangle.merge")
            }
            .help("Compute đề xuất từ thống kê tuần này.")
            Spacer()
            Button {
              showingSuggestionSheet = true
            } label: {
              Label("Xem đề xuất (\(pendingSuggestions.count))",
                    themedSymbol: "tray.full")
            }
            .disabled(pendingSuggestions.isEmpty)
            .help("Review và chốt thêm các từ đề xuất vào từ điển cá nhân.")
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

        // MARK: 4. Current week summary (chỉ hiện khi statisticsEnabled)
        if statisticsEnabled, let s = currentSummary {
          Section {
            statRow("Tổng số từ đã commit", value: "\(s.wordsTotal)")
            statRow("Giữ tiếng Việt", value: "\(s.wordsKeptVietnamese)")
            statRow("Khôi phục tiếng Anh", value: "\(s.wordsRestoredEnglish)")
            statRow("Giữ nguyên (raw)", value: "\(s.wordsKeptRaw)")
            statRow("Có gợi ý", value: "\(s.wordsSuggested)")
            statRow("Smart Switch kích hoạt", value: "\(s.smartSwitchFires)")
          } header: {
            Text(UsageSummary.vietnameseHeader(for: s.weekId))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }

          // MARK: 5-7. Top words & apps (per-row delete)
          // 1.7.4: top từ = top 10% theo count (compute trong WeekBucket.summary),
          // áp thêm filter display (length ≥3, ngoài deny, có trong lexicon).
          // UI hiện prefix(10); nếu filtered > 10 → nút "Xem chi tiết".
          let filteredTopVN = s.topVietnameseWords.filter {
            isCleanTopWord($0.word, category: .vietnamese)
          }
          if !filteredTopVN.isEmpty {
            Section {
              ForEach(filteredTopVN.prefix(10), id: \.word) { wc in
                statDeletableRow(word: wc.word, count: wc.count, category: .vietnamese)
              }
              if filteredTopVN.count > 10 {
                HStack {
                  Spacer()
                  Button {
                    detailCategory = .vietnamese
                  } label: {
                    Label("Xem chi tiết (\(filteredTopVN.count))", themedSymbol: "list.bullet")
                  }
                  Spacer()
                }
              }
            } header: {
              Text("Top từ tiếng Việt (tuần này)")
            }
          }

          let filteredTopEN = s.topEnglishWords.filter {
            isCleanTopWord($0.word, category: .english)
          }
          if !filteredTopEN.isEmpty {
            Section {
              ForEach(filteredTopEN.prefix(10), id: \.word) { wc in
                statDeletableRow(word: wc.word, count: wc.count, category: .english)
              }
              if filteredTopEN.count > 10 {
                HStack {
                  Spacer()
                  Button {
                    detailCategory = .english
                  } label: {
                    Label("Xem chi tiết (\(filteredTopEN.count))", themedSymbol: "list.bullet")
                  }
                  Spacer()
                }
              }
            } header: {
              Text("Top từ tiếng Anh / ký tự đặc biệt (tuần này)")
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

          // MARK: 8. Historical weeks (1.6.1+ — đảm bảo data tuần cũ
          // không "biến mất" trên UI sau khi rotation đóng tuần).
          if !historical.isEmpty {
            Section {
              ForEach(historical.prefix(4), id: \.weekId) { week in
                VStack(alignment: .leading, spacing: 4) {
                  Text(UsageSummary.vietnameseHeader(for: week.weekId))
                    .font(.headline)
                  HStack {
                    Text("Tổng: \(week.wordsTotal)")
                    Spacer()
                    Text("VN: \(week.wordsKeptVietnamese)")
                    Spacer()
                    Text("EN: \(week.wordsRestoredEnglish)")
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
              }
            } header: {
              Text("Các tuần đã đóng")
            }
          }
        }

        // MARK: 9. Diagnostic (1.6.1+)
        Section {
          HStack {
            Spacer()
            Button(action: exportDiagnostic) {
              Label("Xuất chẩn đoán Stats", themedSymbol: "stethoscope")
            }
            .help("Lưu file text mô tả tình trạng stats hiện tại — gửi khi báo lỗi.")
            Spacer()
          }
          if !diagnosticStatus.isEmpty {
            Text(diagnosticStatus)
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
          }
        } header: {
          Text("Chẩn đoán")
        }
      }
      .formStyle(.grouped)
      .scrollDisabled(false)
    }
    .frame(minWidth: 180, minHeight: 720)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: refresh)
    .sheet(isPresented: $showingSuggestionSheet) {
      PersonalDictSuggestionSheet()
    }
    .sheet(item: $detailCategory) { category in
      TopWordsDetailSheet(
        category: category,
        words: detailWords(for: category),
        onDelete: { word in
          UsageStatistics.shared.removeFromCurrentWeek(
            word: word, category: category.statCategory
          )
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            refresh()
          }
        },
        onDismiss: { detailCategory = nil }
      )
    }
  }

  // MARK: - Top words filter (1.7.4)

  /// Lọc 1 từ top khỏi display nếu là noise: quá ngắn (<3), bị deny, hoặc
  /// không có trong bất kỳ lexicon nào (VN/EN/Keep + user allow/keep).
  /// Recovery-path commits đã được loại tại record time (UsageStatistics).
  private func isCleanTopWord(
    _ word: String,
    category: UsageStatistics.StatCategory
  ) -> Bool {
    let normalized = word.normalizedDictionaryToken
    guard normalized.count >= 3 else { return false }
    let denied = Set(Defaults[.userDenyWords].map { $0.normalizedDictionaryToken })
    if denied.contains(normalized) { return false }
    switch category {
    case .vietnamese:
      return LexiconManager.shared.isVietnameseWord(normalized)
        || LexiconManager.shared.shouldKeepVietnamese(normalized)
    case .english:
      return LexiconManager.shared.isEnglishWord(normalized)
        || Defaults[.userAllowWords].contains(normalized)
    case .app:
      return true
    }
  }

  private func detailWords(for category: TopWordsDetailCategory) -> [WordCount] {
    guard let s = currentSummary else { return [] }
    let source: [WordCount]
    switch category {
    case .vietnamese: source = s.topVietnameseWords
    case .english:    source = s.topEnglishWords
    }
    return source.filter { isCleanTopWord($0.word, category: category.statCategory) }
  }

  // MARK: - Actions

  private func refresh() {
    currentSummary = UsageStatistics.shared.currentWeekSummary()
    historical = UsageStatistics.shared.historicalSummaries()
  }

  private func runFeedback() {
    _ = UsageStatistics.shared.performWeeklyFeedback()
    // 1.6.0: compute đề xuất chạy async qua DispatchQueue.main trong
    // appendToPendingSuggestions. Đợi 1 tick rồi report số đề xuất.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      let count = pendingSuggestions.count
      if count == 0 {
        lastFeedbackChanges = "Chưa có đề xuất nào — cần ≥5 lần gõ thống nhất cho mỗi từ."
      } else {
        lastFeedbackChanges = "Đã compute \(count) đề xuất. Bấm \"Xem đề xuất\" để review và chốt thêm."
      }
      refresh()
    }
  }

  private func exportDiagnostic() {
    let report = UsageStatistics.shared.diagnosticReport()
    let url = FileManager.default
      .homeDirectoryForCurrentUser
      .appendingPathComponent("Desktop/vkey-stats-diagnostic.txt")
    do {
      try report.write(to: url, atomically: true, encoding: .utf8)
      diagnosticStatus = "Đã lưu: \(url.lastPathComponent)"
    } catch {
      diagnosticStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
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

/// 1.7.4: sheet hiển thị toàn bộ top từ đã lọc (>10). Có nút xóa từng từ
/// + nút Đóng.
struct TopWordsDetailSheet: View {
  let category: TopWordsDetailCategory
  let words: [WordCount]
  let onDelete: (String) -> Void
  let onDismiss: () -> Void

  @State private var localWords: [WordCount] = []

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(category.title)
          .font(.headline)
        Spacer()
        Text("\(localWords.count) từ")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

      List {
        ForEach(localWords, id: \.word) { wc in
          HStack {
            Text(wc.word)
            Spacer()
            Text("×\(wc.count)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
            Button {
              onDelete(wc.word)
              localWords.removeAll { $0.word == wc.word }
            } label: {
              ThemedSymbol(name: "trash")
                .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Xoá khỏi thống kê tuần này")
          }
        }
      }
      .listStyle(.inset)

      Divider()

      HStack {
        Spacer()
        Button("Đóng", action: onDismiss)
          .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .frame(width: 420, height: 520)
    .onAppear {
      localWords = words
    }
  }
}

struct StatisticsView_Previews: PreviewProvider {
  static var previews: some View {
    StatisticsView()
  }
}
