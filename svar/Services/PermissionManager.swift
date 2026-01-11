//
//  PermissionManager.swift
//  swar
//

import AVFoundation
import Cocoa
import Combine

@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false

    private var accessibilityTimer: Timer?

    private init() {
        checkPermissions()
    }

    func checkPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    // MARK: - Microphone

    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        case .notDetermined, .denied, .restricted:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
    }

    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasMicrophonePermission = granted
            }
        }
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        startPollingAccessibility()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        startPollingAccessibility()
    }

    private func startPollingAccessibility() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
                if self?.hasAccessibilityPermission == true {
                    self?.accessibilityTimer?.invalidate()
                }
            }
        }
    }

    var allPermissionsGranted: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }
}
