//
//  OnboardingView.swift
//  swar
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top)

            Spacer()

            // Step content
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep()
                case 1:
                    MicrophoneStep()
                case 2:
                    AccessibilityStep()
                case 3:
                    ModelStep()
                default:
                    EmptyView()
                }
            }

            Spacer()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                }

                Spacer()

                Button(currentStep == 3 ? "Finish" : "Continue") {
                    if currentStep == 3 {
                        finishOnboarding()
                    } else {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
            .padding()
        }
        .frame(width: 450, height: 350)
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1: return permissionManager.hasMicrophonePermission
        case 2: return permissionManager.hasAccessibilityPermission
        case 3: return transcriptionEngine.isModelLoaded || transcriptionEngine.isDownloading
        default: return true
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        if let window = NSApp.windows.first(where: { $0.title == "Welcome to Swar" }) {
            window.close()
        }
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Welcome to Swar")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Voice-to-text transcription that runs entirely on your device. No data ever leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct MicrophoneStep: View {
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: permissionManager.hasMicrophonePermission ? "checkmark.circle.fill" : "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(permissionManager.hasMicrophonePermission ? .green : .accentColor)

            Text("Microphone Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Swar needs microphone access to record your voice for transcription.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if !permissionManager.hasMicrophonePermission {
                Button("Grant Microphone Access") {
                    permissionManager.requestMicrophonePermission()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Microphone access granted!")
                    .foregroundColor(.green)
            }
        }
    }
}

struct AccessibilityStep: View {
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: permissionManager.hasAccessibilityPermission ? "checkmark.circle.fill" : "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundColor(permissionManager.hasAccessibilityPermission ? .green : .accentColor)

            Text("Accessibility Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Swar needs accessibility access to paste transcriptions directly into any text field.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if !permissionManager.hasAccessibilityPermission {
                Button("Open System Settings") {
                    permissionManager.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)

                Text("Enable Swar in System Settings → Privacy & Security → Accessibility")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Accessibility access granted!")
                    .foregroundColor(.green)
            }
        }
    }
}

struct ModelStep: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: transcriptionEngine.isModelLoaded ? "checkmark.circle.fill" : "cpu")
                .font(.system(size: 64))
                .foregroundColor(transcriptionEngine.isModelLoaded ? .green : .accentColor)

            Text("Download Model")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose a speech recognition model. V3 supports multiple languages, V2 is English-only but slightly faster.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Picker("Model", selection: $appState.selectedModel) {
                ForEach(ParakeetModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if transcriptionEngine.isDownloading {
                VStack {
                    ProgressView(value: transcriptionEngine.downloadProgress)
                        .padding(.horizontal)
                    Text("Downloading model...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if transcriptionEngine.isModelLoaded {
                Text("Model ready!")
                    .foregroundColor(.green)
            } else {
                Button("Download Model (~600MB)") {
                    Task {
                        await transcriptionEngine.downloadModel(appState.selectedModel)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
