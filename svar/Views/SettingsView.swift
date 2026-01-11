//
//  SettingsView.swift
//  swar
//

import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general = 0
    case model = 1
    case permissions = 2

    var title: String {
        switch self {
        case .general: return "General"
        case .model: return "Models"
        case .permissions: return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .model: return "cpu"
        case .permissions: return "lock.shield"
        }
    }
}

struct GeneralSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HotkeyRecorderView()
                    .padding(.vertical, 4)

                Text("Supports single keys like Right Command, Function keys, or key combinations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Recording Mode") {
                Picker("Mode:", selection: $appState.recordingMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(appState.recordingMode == .pushToTalk
                    ? "Hold the shortcut to record, release to transcribe"
                    : "Press once to start, press again to stop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Output") {
                Picker("After transcription:", selection: $appState.outputMode) {
                    ForEach(OutputMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        Task { @MainActor in
                            LaunchAtLoginManager.shared.setLaunchAtLogin(newValue)
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.shared.isLaunchAtLoginEnabled
        }
        .onChange(of: appState.recordingMode) { _, _ in
            Task { @MainActor in
                appState.saveSettings()
            }
        }
        .onChange(of: appState.outputMode) { _, _ in
            Task { @MainActor in
                appState.saveSettings()
            }
        }
    }
}

struct ModelSettingsView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared

    var body: some View {
        Form {
            Section("Select Model") {
                ForEach(ParakeetModel.allCases, id: \.self) { model in
                    ModelRowView(
                        model: model,
                        isSelected: appState.selectedModel == model,
                        isDownloaded: transcriptionEngine.isModelDownloaded(model),
                        isDownloading: transcriptionEngine.downloadingModel == model,
                        downloadProgress: transcriptionEngine.downloadProgress,
                        isLoaded: transcriptionEngine.loadedModelVersion == model
                    ) {
                        Task { @MainActor in
                            appState.selectedModel = model
                            appState.saveSettings()
                            // If model is downloaded, switch to it
                            if transcriptionEngine.isModelDownloaded(model) {
                                await transcriptionEngine.switchModel(model)
                            }
                        }
                    } onDownload: {
                        Task { @MainActor in
                            await transcriptionEngine.downloadModel(model, loadAfterDownload: appState.selectedModel == model)
                        }
                    }
                }
            }

            Section {
                if let loadedModel = transcriptionEngine.loadedModelVersion, transcriptionEngine.isModelLoaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(loadedModel.displayName) is active and ready")
                            .foregroundColor(.secondary)
                    }
                } else if !transcriptionEngine.downloadedModels.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Select a downloaded model to activate it")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                        Text("Download a model to get started")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ModelRowView: View {
    let model: ParakeetModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let isLoaded: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Radio button
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { onSelect() }

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .fontWeight(.medium)

                    Text("• \(model.tagline)")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture { onSelect() }

            Spacer()

            // Download status / button
            if isDownloading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Button("Download") {
                    onDownload()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PermissionsView: View {
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        Form {
            Section("Required Permissions") {
                HStack {
                    Image(systemName: permissionManager.hasMicrophonePermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionManager.hasMicrophonePermission ? .green : .red)
                    Text("Microphone Access")
                    Spacer()
                    if !permissionManager.hasMicrophonePermission {
                        Button("Grant") {
                            permissionManager.requestMicrophonePermission()
                        }
                    }
                }

                HStack {
                    Image(systemName: permissionManager.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionManager.hasAccessibilityPermission ? .green : .red)
                    Text("Accessibility Access")
                    Spacer()
                    if !permissionManager.hasAccessibilityPermission {
                        Button("Open Settings") {
                            permissionManager.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section {
                Text("Microphone access is needed to record your voice. Accessibility access is needed to paste text into other applications.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            #if DEBUG
            Section("Debug") {
                Button("Reset All App Data", role: .destructive) {
                    resetAllAppData()
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            permissionManager.checkPermissions()
        }
    }

    #if DEBUG
    private func resetAllAppData() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Unload model
        TranscriptionEngine.shared.unloadModel()

        // Clear history
        HistoryManager.shared.clear()
        AppState.shared.transcriptionHistory = []

        // Reset hotkey to default
        CustomHotkeyManager.shared.config = .default
        CustomHotkeyManager.shared.setupEventTap()

        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "App Data Reset"
        alert.informativeText = "All app data has been cleared. Please restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit & Restart")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            // Restart the app
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            NSApp.terminate(nil)
        }
    }
    #endif
}
