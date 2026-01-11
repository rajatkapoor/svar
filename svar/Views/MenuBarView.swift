//
//  MenuBarView.swift
//  svar
//

import SwiftUI

struct MenuBarMenuView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            // Home - opens the main window
            Button("Home") {
                openHome()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            // Model Selection
            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(ParakeetModel.allCases, id: \.self) { model in
                Button {
                    selectModel(model)
                } label: {
                    HStack {
                        if appState.selectedModel == model {
                            Image(systemName: "checkmark")
                        }
                        Text(model.displayName)
                        Spacer()
                        if transcriptionEngine.isModelDownloaded(model) {
                            Text("Downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Status indicator
            HStack {
                Circle()
                    .fill(permissionManager.allPermissionsGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(permissionManager.allPermissionsGranted ? "All permissions granted" : "Permissions needed")
            }

            Divider()

            // Quit
            Button("Quit Svar") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func selectModel(_ model: ParakeetModel) {
        Task { @MainActor in
            appState.selectedModel = model
            appState.saveSettings()

            // If model not downloaded, open home (user can navigate to Settings > Models)
            if !transcriptionEngine.isModelDownloaded(model) {
                openHome()
            } else {
                // Switch to the selected model
                await transcriptionEngine.switchModel(model)
            }
        }
    }

    private func openHome() {
        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
