//
//  HotkeyRecorderView.swift
//  swar
//
//  Custom hotkey recorder that supports single modifier keys and combinations
//

import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @StateObject private var hotkeyManager = CustomHotkeyManager.shared
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    // Track current key state during recording
    @State private var currentKeyCode: UInt16?
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var isWaitingForRelease = false
    @State private var displayText = ""

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { toggleRecording() }) {
                Text(isRecording ? (displayText.isEmpty ? "Press keys..." : displayText) : hotkeyManager.config.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isRecording && displayText.isEmpty ? .secondary : .primary)
                    .frame(minWidth: 100)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )

            Button(isRecording ? "Cancel" : "Clear") {
                if isRecording {
                    cancelRecording()
                } else {
                    hotkeyManager.config = .default
                    hotkeyManager.setupEventTap()
                }
            }
            .font(.system(size: 11))
            .buttonStyle(.borderless)
        }
    }

    private func toggleRecording() {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        currentKeyCode = nil
        currentModifiers = []
        isWaitingForRelease = false
        displayText = ""

        // Monitor for key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            self.handleEvent(event)
            return nil // Consume the event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            self.handleEvent(event)
        }
    }

    private func cancelRecording() {
        stopRecording(save: false)
    }

    private func stopRecording(save: Bool) {
        isRecording = false
        isWaitingForRelease = false
        displayText = ""

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if save, let keyCode = currentKeyCode {
            let modifiers = currentModifiers.intersection([.command, .shift, .option, .control])
            let hasModifiers = !modifiers.isEmpty

            hotkeyManager.config = HotkeyConfig(
                keyCode: keyCode,
                requiresModifiers: hasModifiers && !isModifierKey(keyCode),
                modifierFlags: hasModifiers ? UInt64(modifiers.rawValue) : 0
            )

            // Re-setup the event tap with new config
            hotkeyManager.setupEventTap()
        }

        currentKeyCode = nil
        currentModifiers = []
    }

    private func handleEvent(_ event: NSEvent) {
        guard isRecording else { return }

        let keyCode = event.keyCode

        if event.type == .flagsChanged {
            // Modifier key pressed or released
            let newModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])

            // Check if this specific modifier key is being pressed (not released)
            let isModifierDown = isModifierKeyDown(keyCode: keyCode, flags: event.modifierFlags)

            if isModifierDown {
                // Modifier pressed
                if isModifierKey(keyCode) {
                    // If only pressing a modifier (no regular key yet), track it as potential single-modifier hotkey
                    if currentKeyCode == nil || isModifierKey(currentKeyCode!) {
                        currentKeyCode = keyCode
                    }
                }
                currentModifiers = newModifiers
                isWaitingForRelease = true
                updateDisplayText()
            } else if isWaitingForRelease {
                // Check if ALL keys are released
                let allModifiersReleased = event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty

                if allModifiersReleased && currentKeyCode != nil {
                    // All keys released - save the combination
                    stopRecording(save: true)
                } else {
                    // Some modifiers still held, update state
                    currentModifiers = newModifiers
                    updateDisplayText()
                }
            }
        } else if event.type == .keyDown {
            // Escape key cancels recording
            if keyCode == 53 {
                cancelRecording()
                return
            }

            // Regular key pressed
            currentKeyCode = keyCode
            currentModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            isWaitingForRelease = true
            updateDisplayText()
        } else if event.type == .keyUp {
            // Regular key released - if we were tracking this key, save
            if isWaitingForRelease && currentKeyCode == keyCode {
                stopRecording(save: true)
            }
        }
    }

    private func isModifierKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 54, 55: return true // Command
        case 56, 60: return true // Shift
        case 58, 61: return true // Option
        case 59, 62: return true // Control
        case 57: return true     // Caps Lock
        case 63: return true     // Fn
        default: return false
        }
    }

    private func isModifierKeyDown(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55: return flags.contains(.command)
        case 56, 60: return flags.contains(.shift)
        case 58, 61: return flags.contains(.option)
        case 59, 62: return flags.contains(.control)
        case 63: return flags.contains(.function)
        case 57: return flags.contains(.capsLock)
        default: return false
        }
    }

    private func updateDisplayText() {
        var parts: [String] = []

        if currentModifiers.contains(.control) { parts.append("⌃") }
        if currentModifiers.contains(.option) { parts.append("⌥") }
        if currentModifiers.contains(.shift) { parts.append("⇧") }
        if currentModifiers.contains(.command) { parts.append("⌘") }

        if let keyCode = currentKeyCode {
            if let special = SpecialKeyCode(rawValue: keyCode), special.isModifier {
                // For single modifier keys, show the specific key name
                if parts.isEmpty {
                    parts.append(special.displayName)
                }
            } else if let char = keyCodeToCharacter(keyCode) {
                parts.append(char.uppercased())
            } else {
                parts.append("Key \(keyCode)")
            }
        }

        displayText = parts.joined()
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        // Check special keys first
        if let special = SpecialKeyCode(rawValue: keyCode) {
            return special.displayName
        }

        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let result = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard result == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

#Preview {
    HotkeyRecorderView()
        .padding()
}
