//
//  svarApp.swift
//  svar
//
//  Created by Rajat Kapoor on 10/01/26.
//

import SwiftUI
import AppKit

@main
struct SvarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Register the window opener here where Environment is available
        let _ = {
            AppDelegate.openMainWindow = { [openWindow] in
                openWindow(id: "main")
            }
        }()

        // Menu bar dropdown
        MenuBarExtra("Svar", image: "MenuBarIcon") {
            MenuBarMenuView()
        }

        // Main app window (Home)
        Window("Svar", id: "main") {
            MainWindowView()
        }
        .defaultSize(width: 800, height: 600)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // Store reference to open window function
    static var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Observe window visibility to toggle Dock/Cmd-Tab visibility
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        // Initialize managers
        Task { @MainActor in
            _ = HotkeyManager.shared
            _ = VocabularyManager.shared
            AppState.shared.transcriptionHistory = HistoryManager.shared.load()

            // Auto-load previously downloaded model
            await TranscriptionEngine.shared.initializeOnStartup()

            // Check permissions after a short delay to let the app fully initialize
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            checkPermissionsAndShowHomeIfNeeded()
        }
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == "Svar" else { return }

        // Show in Dock and Cmd-Tab when main window is open
        NSApp.setActivationPolicy(.regular)
    }

    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == "Svar" else { return }
        // Hide from Dock and Cmd-Tab when main window closes
        NSApp.setActivationPolicy(.accessory)
    }

    @MainActor
    func checkPermissionsAndShowHomeIfNeeded() {
        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions()

        if !permissionManager.allPermissionsGranted {
            // Set flag to show permissions tab, then open home window
            AppState.shared.showPermissionsTab = true

            // Open the main window
            AppDelegate.openMainWindow?()
            NSApp.activate(ignoringOtherApps: true)

            // Start polling for permission changes
            startPermissionPolling()
        }
    }

    private var permissionPollTimer: Timer?

    private func startPermissionPolling() {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let permissionManager = PermissionManager.shared
                permissionManager.checkPermissions()

                if permissionManager.allPermissionsGranted {
                    self?.permissionPollTimer?.invalidate()
                    self?.permissionPollTimer = nil
                    // Re-setup hotkey event tap now that we have permissions
                    CustomHotkeyManager.shared.setupEventTap()
                }
            }
        }
    }
}
