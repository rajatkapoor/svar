//
//  DictationIndicatorWindow.swift
//  svar
//

import SwiftUI
import AppKit

// MARK: - Dictation Indicator Window Controller

@MainActor
class DictationIndicatorWindowController {
    static let shared = DictationIndicatorWindowController()

    private var window: NSPanel?
    private var hostingView: NSHostingView<DictationIndicatorView>?

    private init() {}

    func show() {
        guard AppState.shared.showDictationIndicator else { return }

        if window == nil {
            createWindow()
        }

        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let contentView = DictationIndicatorView()
        let hostingView = NSHostingView(rootView: contentView)
        self.hostingView = hostingView

        // Window size
        let windowWidth: CGFloat = 140
        let windowHeight: CGFloat = 44

        guard let screen = NSScreen.main else { return }
        // Use visibleFrame to position above the dock
        let visibleFrame = screen.visibleFrame

        // Position at bottom center, 20px above the visible area (above dock)
        let xPos = visibleFrame.midX - (windowWidth / 2)
        let yPos = visibleFrame.minY + 20

        let windowFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        // Create panel (floating window)
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        // Use screenSaver level to appear above all windows including dock
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.contentView = hostingView

        self.window = panel
    }
}

// MARK: - Dictation Indicator View

struct DictationIndicatorView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 8) {
            // Mic icon (red)
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)

            // Center: Waveform (recording) or Loader (transcribing)
            if appState.isRecording {
                WaveformView()
                    .frame(width: 40, height: 14)
            } else if appState.isTranscribing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 40, height: 14)
            }

            // Stop button
            Button {
                stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func stopRecording() {
        Task { @MainActor in
            // Cancel recording without transcribing
            _ = AudioRecorder.shared.stopRecording()
            DictationIndicatorWindowController.shared.hide()
        }
    }
}

// MARK: - Waveform Animation View

struct WaveformView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                WaveformBar(isAnimating: isAnimating, index: index)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct WaveformBar: View {
    let isAnimating: Bool
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(0.8))
            .frame(width: 3, height: isAnimating ? 14 : 4)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
                value: isAnimating
            )
    }
}

#Preview {
    DictationIndicatorView()
        .frame(width: 120, height: 36)
        .background(Color.gray)
}
