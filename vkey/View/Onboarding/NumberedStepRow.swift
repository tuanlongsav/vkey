//
//  NumberedStepRow.swift
//  vkey
//
//  Hàng bước hướng dẫn đánh số dùng chung giữa `OnboardingSteps` và `UpgradeAppView`.
//

import SwiftUI

struct NumberedStepRow: View {
  enum Style {
    case regular  // Onboarding (circle 32pt, text 18pt)
    case compact  // Upgrade guide (circle 26pt, text 13pt)

    var badgeSize: CGFloat { self == .regular ? 32 : 26 }
    var checkFontSize: CGFloat { self == .regular ? 14 : 11 }
    var numberFontSize: CGFloat { self == .regular ? 16 : 13 }
    var textFontSize: CGFloat { self == .regular ? 18 : 13 }
  }

  let number: Int
  let text: String
  var isCompleted: Bool = false
  var style: Style = .regular

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(isCompleted ? Color.green : Color.accentColor)
          .frame(width: style.badgeSize, height: style.badgeSize)

        if isCompleted {
          Image(systemName: "checkmark")
            .foregroundColor(.white)
            .font(.system(size: style.checkFontSize, weight: .bold))
        } else {
          Text("\(number)")
            .foregroundColor(.white)
            .font(.system(size: style.numberFontSize, weight: .bold))
        }
      }

      Text(text)
        .font(.system(size: style.textFontSize))
        .foregroundColor(isCompleted ? .secondary : .primary)
    }
  }
}
