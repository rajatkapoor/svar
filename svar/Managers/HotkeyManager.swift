//
//  HotkeyManager.swift
//  swar
//

import SwiftUI

@MainActor
class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {
        setupHotkeys()
    }

    func setupHotkeys() {
        let customHotkey = CustomHotkeyManager.shared

        // Handle key down
        customHotkey.onKeyDown = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }

                if AppState.shared.recordingMode == .pushToTalk {
                    // Push to talk: start on key down
                    self.startRecording()
                } else {
                    // Toggle mode: toggle on key down
                    if AppState.shared.isRecording {
                        self.stopRecordingAndTranscribe()
                    } else {
                        self.startRecording()
                    }
                }
            }
        }

        // Handle key up (for push to talk)
        customHotkey.onKeyUp = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }

                if AppState.shared.recordingMode == .pushToTalk {
                    self.stopRecordingAndTranscribe()
                }
            }
        }
    }

    private func startRecording() {
        guard PermissionManager.shared.allPermissionsGranted else {
            print("Permissions not granted")
            return
        }

        guard TranscriptionEngine.shared.isModelLoaded else {
            print("Model not loaded")
            return
        }

        do {
            try AudioRecorder.shared.startRecording()
            // Show dictation indicator
            DictationIndicatorWindowController.shared.show()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    /// Public method to stop recording and transcribe - called by stop button in indicator
    func stopAndTranscribe() {
        stopRecordingAndTranscribe()
    }

    private func stopRecordingAndTranscribe() {
        // Prevent concurrent transcription
        guard !AppState.shared.isTranscribing else {
            print("Already transcribing, ignoring duplicate stop request")
            return
        }

        guard let recording = AudioRecorder.shared.stopRecording() else {
            DictationIndicatorWindowController.shared.hide()
            return
        }

        // Don't transcribe very short recordings
        guard recording.duration > 0.5 else {
            DictationIndicatorWindowController.shared.hide()
            return
        }

        Task {
            do {
                let rawText = try await TranscriptionEngine.shared.transcribe(samples: recording.samples)

                // Apply vocabulary corrections
                let text = VocabularyPostProcessor.shared.process(rawText)

                // Skip empty transcriptions
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    DictationIndicatorWindowController.shared.hide()
                    return
                }

                // Add to history
                let item = TranscriptionItem(text: trimmedText, duration: recording.duration)
                AppState.shared.transcriptionHistory.insert(item, at: 0)
                AppState.shared.lastTranscription = trimmedText

                // Insert text
                TextInserter.shared.insertText(trimmedText, mode: AppState.shared.outputMode)

                // Save history
                HistoryManager.shared.save(AppState.shared.transcriptionHistory)

                // Update word count asynchronously (doesn't block transcription)
                AppState.shared.updateWordCountAsync(newText: trimmedText)

                // Hide dictation indicator after successful transcription
                DictationIndicatorWindowController.shared.hide()
            } catch {
                print("Transcription failed: \(error)")
                DictationIndicatorWindowController.shared.hide()
            }
        }
    }
}
