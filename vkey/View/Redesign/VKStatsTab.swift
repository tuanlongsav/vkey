//
//  VKStatsTab.swift
//  vkey — Tab "Thống kê & Sao lưu" redesign (đầy đủ chức năng 2.15:
//  aggregate + top từ VN/ngoài-VN + cụm + app + tuần đã đóng + đề xuất +
//  chẩn đoán + backup/restore).
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct VKStatsTab: View {
  @Default(.autoBackupOnUpgrade) private var autoBackup
  @Default(.statisticsEnabled) private var statsEnabled
  @Default(.pendingDictSuggestions) private var pendingSuggestions

  @State private var summary: UsageSummary?
  @State private var historical: [UsageSummary] = []
  @State private var backupStatus = ""
  @State private var feedbackStatus = ""
  @State private var diagnosticStatus = ""
  @State private var showingSuggestionSheet = false
  @State private var detailCategory: TopWordsDetailCategory?

  // MARK: Aggregate bars

  private struct StatBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let color: Color
    let pct: Double
  }

  private var statBars: [StatBar] {
    guard let s = summary, s.wordsTotal > 0 else { return [] }
    let total = Double(s.wordsTotal)
    return [
      StatBar(label: "Tổng số từ đã commit", value: s.wordsTotal, color: VK.Color.brand, pct: 1),
      StatBar(label: "Giữ tiếng Việt", value: s.wordsKeptVietnamese, color: VK.Color.success,
              pct: Double(s.wordsKeptVietnamese) / total),
      StatBar(label: "Khôi phục tiếng Anh", value: s.wordsRestoredEnglish, color: VK.Color.info,
              pct: Double(s.wordsRestoredEnglish) / total),
      StatBar(label: "Tự sửa lỗi gõ", value: s.typoCorrectionsApplied, color: VK.Color.ink200,
              pct: Double(s.typoCorrectionsApplied) / total),
      StatBar(label: "Smart Switch kích hoạt", value: s.smartSwitchFires, color: VK.Color.gold,
              pct: Double(s.smartSwitchFires) / total),
    ]
  }

  // MARK: Top word data

  private var topVN: [WordCount] {
    (summary?.topVietnameseWords ?? []).filter { isCleanTopWord($0.word, category: .vietnamese) }
  }
  private var topVNPhrases: [WordCount] {
    UsageStatistics.shared.aggregatedTopVietnamesePhrases(minWords: 2, maxWords: 3, threshold: 3)
  }
  private var topEN: [WordCount] {
    (summary?.topEnglishWords ?? []).filter { isCleanTopWord($0.word, category: .english) }
  }
  private var topENPhrases: [WordCount] {
    UsageStatistics.shared.aggregatedTopEnglishPhrases(minWords: 2, maxWords: 3, threshold: 3)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: VK.Space.s6) {

      backupSection

      if statsEnabled {
        if let s = summary, s.wordsTotal > 0 {
          weekAggregateSection(s)
        }

        wordListSection("Top từ tiếng Việt", words: topVN, detail: .vietnamese,
                        accent: VK.Color.success)
        wordListSection("Top cụm 2-3 từ tiếng Việt", words: topVNPhrases,
                        detail: .vietnamesePhrases, accent: VK.Color.success)
        wordListSection("Top từ ngoài tiếng Việt · gợi ý từ điển", words: topEN,
                        detail: .english, accent: VK.Color.info)
        wordListSection("Top cụm ngoài tiếng Việt", words: topENPhrases,
                        detail: .englishPhrases, accent: VK.Color.info)
        topAppsSection
        historicalSection
      }

      syncSection
      privacySection
    }
    .onAppear(perform: refresh)
    .sheet(isPresented: $showingSuggestionSheet, onDismiss: refresh) {
      PersonalDictSuggestionSheet()
    }
    .sheet(item: $detailCategory) { category in
      TopWordsDetailSheet(
        category: category,
        words: detailWords(for: category),
        onDelete: { word in
          UsageStatistics.shared.removeTopEntry(word: word, category: category.statCategory)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: refresh)
        },
        onDismiss: { detailCategory = nil }
      )
    }
  }

  // MARK: - Sections

  private var backupSection: some View {
    VKSection("Sao lưu & khôi phục dữ liệu cá nhân") {
      VKRowGroup {
        VKToggleRow(icon: "externaldrive.fill", iconColor: VK.Color.brand,
                    label: "Tự động hỏi sao lưu khi cập nhật app", isOn: $autoBackup)
      }
      HStack {
        VKButton(title: "Xuất dữ liệu cá nhân", icon: "square.and.arrow.up",
                 variant: .secondary, fullWidth: true) { exportData() }
        VKButton(title: "Nhập từ tệp sao lưu", icon: "square.and.arrow.down",
                 variant: .secondary, fullWidth: true) { importData() }
      }
      if !backupStatus.isEmpty { VKGroupHint(backupStatus) }
      VKGroupHint("File JSON gồm Cài đặt, Macro, Từ điển cá nhân, Smart Switch và thống kê. Tất cả lưu cục bộ, không gửi đi đâu.")
    }
  }

  private func weekAggregateSection(_ s: UsageSummary) -> some View {
    VKSection("Thống kê tuần · \(s.weekId)") {
      VStack(spacing: 12) {
        ForEach(statBars) { bar in
          HStack(spacing: VK.Space.s3) {
            Text(bar.label).font(.vk(.small)).foregroundStyle(VK.Color.fg2)
              .frame(width: 150, alignment: .leading)
            GeometryReader { geo in
              ZStack(alignment: .leading) {
                Capsule().fill(VK.Color.bgSunken).frame(height: 8)
                Capsule().fill(bar.color)
                  .frame(width: max(0, geo.size.width * bar.pct), height: 8)
              }
            }
            .frame(height: 8)
            Text(bar.value.formatted())
              .font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundStyle(VK.Color.fg1)
              .frame(width: 56, alignment: .trailing)
          }
        }
      }
      .padding(14)
      .background(cardBackground)
    }
  }

  @ViewBuilder
  private func wordListSection(_ title: String, words: [WordCount],
                               detail: TopWordsDetailCategory?, accent: Color) -> some View {
    if !words.isEmpty {
      VKSection(title) {
        VStack(spacing: 0) {
          ForEach(Array(words.prefix(10).enumerated()), id: \.element.word) { idx, wc in
            if idx > 0 { Divider().overlay(VK.Color.border1) }
            HStack(spacing: VK.Space.s3) {
              Circle().fill(accent).frame(width: 6, height: 6)
              Text(wc.word).font(.system(size: 13))
                .foregroundStyle(VK.Color.fg1).lineLimit(1)
              Spacer(minLength: 8)
              Text("×\(wc.count)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(VK.Color.fgMuted)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
          }
        }
        .background(cardBackground)

        if let detail {
          HStack {
            Spacer()
            VKButton(
              title: words.count > 10
                ? "Xem chi tiết (\(words.count))"
                : "Quản lý & xóa (\(words.count))",
              icon: "list.bullet",
              variant: .ghost,
              size: .sm
            ) { detailCategory = detail }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var topAppsSection: some View {
    if let apps = summary?.topApps, !apps.isEmpty {
      VKSection("Top app dùng nhiều") {
        VStack(spacing: 0) {
          ForEach(Array(apps.prefix(5).enumerated()), id: \.element.word) { idx, wc in
            if idx > 0 { Divider().overlay(VK.Color.border1) }
            HStack(spacing: VK.Space.s3) {
              Image(systemName: "app.fill").font(.system(size: 11)).foregroundStyle(VK.Color.gold)
              Text(wc.word).font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(VK.Color.fg1).lineLimit(1).truncationMode(.middle)
              Spacer(minLength: 8)
              Text("×\(wc.count)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(VK.Color.fgMuted)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
          }
        }
        .background(cardBackground)
      }
    }
  }

  @ViewBuilder
  private var historicalSection: some View {
    if !historical.isEmpty {
      VKSection("Các tuần đã đóng") {
        VStack(spacing: 0) {
          ForEach(Array(historical.prefix(4).enumerated()), id: \.element.weekId) { idx, week in
            if idx > 0 { Divider().overlay(VK.Color.border1) }
            HStack(spacing: VK.Space.s3) {
              Text(week.weekId).font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(VK.Color.fg1)
              Spacer(minLength: 8)
              Text("Tổng \(week.wordsTotal) · VN \(week.wordsKeptVietnamese) · EN \(week.wordsRestoredEnglish)")
                .font(.system(size: 11.5)).foregroundStyle(VK.Color.fgMuted)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
          }
        }
        .background(cardBackground)
      }
    }
  }

  private var syncSection: some View {
    VKSection("Đồng bộ & đề xuất từ điển") {
      VKRowGroup {
        VKRow(icon: "arrow.triangle.2.circlepath", iconColor: VK.Color.info,
              label: "Đồng bộ hành vi vào Personal Dictionary",
              hint: "Cần ≥ 5 lần gõ thống nhất cho mỗi từ.") {
          VKButton(title: "Chạy tính toán", icon: "wand.and.stars", variant: .secondary, size: .sm) {
            runCompute()
          }
        }
        VKRow(icon: "lightbulb.fill", iconColor: VK.Color.gold,
              label: "Đề xuất bổ sung từ điển",
              hint: pendingSuggestions.isEmpty ? "Chưa có đề xuất." : nil) {
          VKButton(title: "Xem đề xuất (\(pendingSuggestions.count))",
                   variant: .secondary, size: .sm) {
            showingSuggestionSheet = true
          }
          .disabled(pendingSuggestions.isEmpty)
        }
        VKToggleRow(icon: "chart.bar.fill", iconColor: VK.Color.brand,
                    label: "Ghi nhận thống kê sử dụng", isOn: $statsEnabled)
      }
      if !feedbackStatus.isEmpty { VKGroupHint(feedbackStatus) }
    }
  }

  private var privacySection: some View {
    VKSection("Quyền riêng tư & chẩn đoán") {
      VKGroupHint("Dữ liệu chỉ lưu cục bộ tại ~/Library/Application Support/vkey/stats/. Không có request mạng nào.")
      HStack {
        VKButton(title: "Xuất chẩn đoán thống kê", icon: "stethoscope",
                 variant: .secondary, size: .sm) { exportDiagnostic() }
        Spacer()
        VKButton(title: "Xóa toàn bộ dữ liệu thống kê", icon: "trash",
                 variant: .danger, size: .sm) { clearStats() }
      }
      if !diagnosticStatus.isEmpty { VKGroupHint(diagnosticStatus) }
    }
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
      .fill(VK.Color.bgElevated)
      .overlay(RoundedRectangle(cornerRadius: VK.Radius.lg, style: .continuous)
                .strokeBorder(VK.Color.border1, lineWidth: 1))
  }

  // MARK: - Data helpers

  private func refresh() {
    summary = UsageStatistics.shared.currentWeekSummary()
    historical = UsageStatistics.shared.historicalSummaries()
  }

  private func isCleanTopWord(_ word: String, category: UsageStatistics.StatCategory) -> Bool {
    let normalized = word.normalizedDictionaryToken
    guard normalized.count >= 2 else { return false }
    let denied = Set(Defaults[.userDenyWords].map { $0.normalizedDictionaryToken })
    if denied.contains(normalized) { return false }
    switch category {
    case .vietnamese, .vietnamesePhrase:
      return LexiconManager.shared.isVietnameseWord(normalized)
        || LexiconManager.shared.shouldKeepVietnamese(normalized)
    case .english, .englishPhrase:
      if LexiconManager.shared.isVietnameseWord(normalized) { return false }
      return true
    case .app:
      return true
    }
  }

  private func detailWords(for category: TopWordsDetailCategory) -> [WordCount] {
    switch category {
    case .vietnamese:        return topVN
    case .english:           return topEN
    case .vietnamesePhrases: return topVNPhrases
    case .englishPhrases:    return topENPhrases
    }
  }

  // MARK: - Actions

  private func runCompute() {
    _ = UsageStatistics.shared.performWeeklyFeedback()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      let count = pendingSuggestions.count
      feedbackStatus = count == 0
        ? "Chưa có đề xuất — cần ≥ 5 lần gõ thống nhất cho mỗi từ."
        : "Đã compute \(count) đề xuất. Bấm \"Xem đề xuất\" để chốt thêm."
      refresh()
    }
  }

  private func exportDiagnostic() {
    let report = UsageStatistics.shared.diagnosticReport()
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Desktop/vkey-stats-diagnostic.txt")
    do {
      try report.write(to: url, atomically: true, encoding: .utf8)
      diagnosticStatus = "Đã lưu: \(url.lastPathComponent) (Desktop)"
    } catch {
      diagnosticStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
  }

  private func clearStats() {
    let alert = NSAlert()
    alert.messageText = "Xóa toàn bộ thống kê?"
    alert.informativeText = "Không thể hoàn tác. Các từ đã promote sang từ điển cá nhân vẫn giữ nguyên."
    alert.addButton(withTitle: "Xóa")
    alert.addButton(withTitle: "Huỷ")
    alert.alertStyle = .warning
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    UsageStatistics.shared.clearAll()
    feedbackStatus = ""
    refresh()
  }

  private func exportData() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = "vkey-backup.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let export = UserDataMigration.currentExport()
      let data = try JSONEncoder().encode(export)
      try data.write(to: url)
      backupStatus = "Đã xuất dữ liệu cá nhân."
    } catch {
      backupStatus = "Lỗi xuất: \(error.localizedDescription)"
    }
  }

  private func importData() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      _ = try UserDataMigration.loadFrom(url)
      backupStatus = "Đã nhập dữ liệu. Khởi động lại app để áp dụng đầy đủ."
    } catch {
      backupStatus = "Lỗi nhập: \(error.localizedDescription)"
    }
  }
}
