//
//  OnboardingView.swift
//  vkey
//
//  ViewModel, container view, step indicator và NSWindowController cho luồng Onboarding.
//

import Cocoa
import Defaults
import LaunchAtLogin
import SwiftUI

// MARK: - Onboarding ViewModel

class OnboardingViewModel: ObservableObject {
  enum Step: Int, CaseIterable {
    case welcome = 0
    case permission = 1
    case configuration = 2
    case removeIME = 3
  }

  @Published var currentStep: Step = .welcome
  @Published var permissionGranted: Bool = false
  @Published var selectedMethod: TypingMethods = Defaults[.typingMethod]
  @Published var launchAtLogin: Bool = true

  private var permissionTimer: Timer?

  init() {
    if AXIsProcessTrusted() {
      permissionGranted = true
      currentStep = .removeIME
    }
  }

  func startPermissionPolling(eventHook: EventHook) {
    permissionTimer?.invalidate()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
      [weak self] timer in
      if eventHook.isTrusted(prompt: false) {
        timer.invalidate()
        DispatchQueue.main.async {
          self?.permissionGranted = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self?.currentStep = .configuration
          }
        }
      }
    }
  }

  func stopPermissionPolling() {
    permissionTimer?.invalidate()
    permissionTimer = nil
  }

  func completeOnboarding(appState: AppState) {
    Defaults[.typingMethod] = selectedMethod
    appState.typingMethod = selectedMethod
    LaunchAtLogin.isEnabled = launchAtLogin
    appState.storeTrustedAppVersion()
    NotificationCenter.default.post(name: .vkeyOnboardingDidComplete, object: nil)
  }

  deinit {
    stopPermissionPolling()
  }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
  @EnvironmentObject var appState: AppState
  @StateObject private var viewModel = OnboardingViewModel()

  var body: some View {
    VStack(spacing: 0) {
      Group {
        switch viewModel.currentStep {
        case .welcome:
          WelcomeStepView(viewModel: viewModel)
        case .permission:
          PermissionStepView(viewModel: viewModel, appState: appState)
        case .configuration:
          ConfigurationStepView(viewModel: viewModel, appState: appState)
        case .removeIME:
          RemoveIMEStepView(viewModel: viewModel, appState: appState)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      StepIndicator(
        totalSteps: OnboardingViewModel.Step.allCases.count,
        currentStep: viewModel.currentStep.rawValue
      )
      .padding(.bottom, 24)
    }
    .frame(width: 800, height: 700)
    .background(Color(NSColor.windowBackgroundColor))
  }
}

// MARK: - Step Indicator

struct StepIndicator: View {
  let totalSteps: Int
  let currentStep: Int

  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<totalSteps, id: \.self) { index in
        Circle()
          .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
          .frame(width: 10, height: 10)
          .animation(.easeInOut(duration: 0.3), value: currentStep)
      }
    }
  }
}

// MARK: - Onboarding Window Controller

class OnboardingWindowController: NSWindowController {
  override init(window: NSWindow? = nil) {
    super.init(window: window)
    if window == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
        styleMask: [.titled, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.center()
      window.setFrameAutosaveName("Onboarding Window")
      window.title = "vkey - Cài Đặt"
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      self.window = window
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
