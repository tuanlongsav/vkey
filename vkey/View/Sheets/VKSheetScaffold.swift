//
//  VKSheetScaffold.swift
//  vkey
//
//  Khung chuẩn dùng chung cho các sheet quản lý/gợi ý (header + divider + nội dung + divider + footer).
//

import SwiftUI

struct VKSheetScaffold<HeaderExtra: View, Content: View, Footer: View>: View {
  let title: String
  var subtitle: String? = nil
  var width: CGFloat
  var height: CGFloat
  @ViewBuilder var headerExtra: () -> HeaderExtra
  @ViewBuilder var content: () -> Content
  @ViewBuilder var footer: () -> Footer

  init(
    title: String,
    subtitle: String? = nil,
    width: CGFloat,
    height: CGFloat,
    @ViewBuilder headerExtra: @escaping () -> HeaderExtra = { EmptyView() },
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder footer: @escaping () -> Footer
  ) {
    self.title = title
    self.subtitle = subtitle
    self.width = width
    self.height = height
    self.headerExtra = headerExtra
    self.content = content
    self.footer = footer
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(title)
            .font(.headline)
          Spacer(minLength: 0)
          headerExtra()
        }
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)

      Divider()

      content()
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      HStack {
        footer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .frame(width: width, height: height)
  }
}
