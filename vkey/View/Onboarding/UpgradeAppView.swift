//
//  UpgradeAppView.swift
//  vkey
//
//  Hướng dẫn cấp lại quyền Trợ năng sau khi cập nhật phiên bản mới.
//

import Cocoa
import Combine
import SwiftUI

struct UpgradeAppView: View {
  @EnvironmentObject var appState: AppState

  @State private var hasRequestedPermission = false
  @State private var permissionGranted = false
  private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Image("Cficon")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 40, height: 40)
          .clipShape(RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 2) {
          Text("Cập nhật vkey thành công!")
            .font(.system(size: 18, weight: .bold))
          Text("Cần cấp lại quyền \(AccessibilityPermissionPane.names().vi)")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 30)
      .padding(.top, 20)

      Image("PermissionGuide")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: 200)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)

      VStack(alignment: .leading, spacing: 12) {
        NumberedStepRow(
          number: 1,
          text: "Bấm nút bên dưới để mở \(AccessibilityPermissionPane.displayName) trong Cài đặt Hệ thống",
          isCompleted: hasRequestedPermission,
          style: .compact)
        NumberedStepRow(
          number: 2,
          text: "Chọn 'vkey' và ấn nút '-' ở dưới danh sách để xoá bỏ quyền cũ",
          isCompleted: permissionGranted,
          style: .compact)
        NumberedStepRow(
          number: 3,
          text: "Ấn nút '+' rồi chọn 'vkey' trong Applications để cấp quyền mới",
          isCompleted: permissionGranted,
          style: .compact)
      }
      .padding(.horizontal, 30)

      Spacer()

      if permissionGranted {
        VStack(spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Đã cấp quyền thành công!")
              .foregroundColor(.green)
          }
          .font(.system(size: 16, weight: .medium))

          Button(action: relaunchApp) {
            HStack {
              Text("Khởi động lại")
              Image(systemName: "arrow.clockwise")
            }
            .frame(width: 200)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        }
      } else {
        VStack(spacing: 10) {
          Button {
            AccessibilityPermissionPane.openSettings()
            hasRequestedPermission = true
          } label: {
            HStack {
              Image(systemName: "gear")
              Text("Mở Cài đặt \(AccessibilityPermissionPane.names().vi)")
            }
            .frame(width: 240)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          if hasRequestedPermission {
            HStack(spacing: 8) {
              ProgressView()
                .scaleEffect(0.7)
              Text("Đang chờ cấp quyền...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
          }
        }
      }

      Spacer().frame(height: 16)
    }
    .frame(width: 520, height: 480)
    .onReceive(permissionTimer) { _ in
      if hasRequestedPermission && !permissionGranted {
        permissionGranted = appState.eventHook.isTrusted(prompt: false)
      }
    }
  }

  private func relaunchApp() {
    let url = Bundle.main.bundleURL
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true

    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
      DispatchQueue.main.async {
        NSApp.terminate(nil)
      }
    }
  }
}
