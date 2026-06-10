//
//  ThemedSymbol.swift
//  vkey
//
//  v2.16: sau khi bỏ hết theme cũ (classic/liquidGlass + icon-style
//  threeD/emoji), icon render thẳng SF Symbol — đồng nhất với design
//  Tonal. Giữ lại type + extension `Label(_, themedSymbol:)` để các view
//  cũ (Macro/SmartSwitch/Statistics/Onboarding/Guide/Upgrade + menu bar
//  label) không phải sửa call-site.
//

import SwiftUI

struct ThemedSymbol: View {
  let name: String

  var body: some View {
    Image(systemName: name)
  }
}

extension Label where Title == Text, Icon == ThemedSymbol {
  /// Drop-in thay cho `Label(_, systemImage:)`.
  init(_ title: String, themedSymbol name: String) {
    self.init {
      Text(title)
    } icon: {
      ThemedSymbol(name: name)
    }
  }
}
