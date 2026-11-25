//
//  VKVisualEffect.swift
//  vkey
//
//  Hợp nhất các wrapper `NSVisualEffectView` (Settings Liquid Glass, Menu Bar dark-glass,
//  và HUD rounded-mask backdrop) về một tệp duy nhất.
//

import AppKit
import SwiftUI

/// Wrapper `NSVisualEffectView` dùng chung cho cửa sổ Settings, Menu Bar và HUD.
/// Khi `maskedCornerRadius` khác `nil` (hoặc `capsuleMask == true`), lớp blur
/// được cắt bằng `maskImage` bo góc — tránh viền vuông trong borderless NSPanel.
struct VKVisualEffect: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .underWindowBackground
  var blending: NSVisualEffectView.BlendingMode = .behindWindow
  var appearanceName: NSAppearance.Name? = nil
  var maskedCornerRadius: CGFloat? = nil
  var capsuleMask: Bool = false

  /// Preset kính tối cho Menu Bar panel.
  static var menuDark: VKVisualEffect {
    VKVisualEffect(material: .menu, blending: .behindWindow, appearanceName: .vibrantDark)
  }

  func makeNSView(context: Context) -> VKMaskedVisualEffectView {
    let v = VKMaskedVisualEffectView()
    apply(to: v)
    return v
  }

  func updateNSView(_ nsView: VKMaskedVisualEffectView, context: Context) {
    apply(to: nsView)
  }

  private func apply(to v: VKMaskedVisualEffectView) {
    v.material = material
    v.blendingMode = blending
    v.state = .active
    if let appearanceName {
      v.appearance = NSAppearance(named: appearanceName)
    } else if v.appearance != nil {
      v.appearance = nil
    }
    let needsMask = capsuleMask || maskedCornerRadius != nil
    if needsMask {
      v.wantsLayer = true
      v.useMask = true
      v.fixedCornerRadius = maskedCornerRadius
      v.needsLayout = true
    } else {
      v.useMask = false
      v.fixedCornerRadius = nil
      v.maskImage = nil
    }
  }
}

/// Nền blur cắt đúng bo góc cho HUD trong borderless NSPanel trong suốt.
struct HUDBackdrop: View {
  var cornerRadius: CGFloat? = nil

  var body: some View {
    VKVisualEffect(
      material: .hudWindow,
      blending: .behindWindow,
      maskedCornerRadius: cornerRadius,
      capsuleMask: cornerRadius == nil
    )
  }
}

final class VKMaskedVisualEffectView: NSVisualEffectView {
  var useMask: Bool = false
  var fixedCornerRadius: CGFloat?
  private var appliedMaskRadius: CGFloat?

  override func layout() {
    super.layout()
    guard useMask else {
      if appliedMaskRadius != nil {
        appliedMaskRadius = nil
        maskImage = nil
      }
      return
    }
    let maxR = min(bounds.width, bounds.height) / 2
    let r = max(1, min(fixedCornerRadius ?? maxR, maxR))
    guard r != appliedMaskRadius else { return }
    appliedMaskRadius = r
    maskImage = .vkRoundedMask(cornerRadius: r)
  }
}

extension NSImage {
  /// Mask image bo góc chuẩn AppKit để cắt `NSVisualEffectView` trong cửa sổ trong suốt.
  static func vkRoundedMask(cornerRadius r: CGFloat) -> NSImage {
    let edge = r * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
    image.resizingMode = .stretch
    return image
  }
}
