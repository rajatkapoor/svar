//
//  CustomHotkeyManager.swift
//  swar
//
//  Custom hotkey detection that supports single modifier keys (e.g., right Command only)
//

import Foundation
import Carbon
import AppKit
import Combine

// Key codes for special keys
enum SpecialKeyCode: UInt16, CaseIterable {
    // Modifier keys
    case leftShift = 56
    case rightShift = 60
    case leftControl = 59
    case rightControl = 62
    case leftOption = 58
    case rightOption = 61
    case leftCommand = 55
    case rightCommand = 54
    case capsLock = 57
    case fn = 63

    // Function keys
    case f1 = 122
    case f2 = 120
    case f3 = 99
    case f4 = 118
    case f5 = 96
    case f6 = 97
    case f7 = 98
    case f8 = 100
    case f9 = 101
    case f10 = 109
    case f11 = 103
    case f12 = 111

    var displayName: String {
        switch self {
        case .leftShift: return "Left Shift"
        case .rightShift: return "Right Shift"
        case .leftControl: return "Left Control"
        case .rightControl: return "Right Control"
        case .leftOption: return "Left Option"
        case .rightOption: return "Right Option"
        case .leftCommand: return "Left Command"
        case .rightCommand: return "Right Command"
        case .capsLock: return "Caps Lock"
        case .fn: return "Fn"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        }
    }

    var isModifier: Bool {
        switch self {
        case .leftShift, .rightShift, .leftControl, .rightControl,
             .leftOption, .rightOption, .leftCommand, .rightCommand,
             .capsLock, .fn:
            return true
        default:
            return false
        }
    }
}

// Hotkey configuration
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt16
    var requiresModifiers: Bool // If true, requires additional modifiers
    var modifierFlags: UInt64   // CGEventFlags raw value

    var displayName: String {
        if let special = SpecialKeyCode(rawValue: keyCode) {
            return special.displayName
        }

        // Try to get character for regular keys
        if let char = keyCodeToString(keyCode) {
            var parts: [String] = []
            let flags = CGEventFlags(rawValue: modifierFlags)
            if flags.contains(.maskCommand) { parts.append("⌘") }
            if flags.contains(.maskShift) { parts.append("⇧") }
            if flags.contains(.maskAlternate) { parts.append("⌥") }
            if flags.contains(.maskControl) { parts.append("⌃") }
            parts.append(char.uppercased())
            return parts.joined()
        }

        return "Key \(keyCode)"
    }

    static var `default`: HotkeyConfig {
        HotkeyConfig(keyCode: SpecialKeyCode.rightCommand.rawValue, requiresModifiers: false, modifierFlags: 0)
    }
}

// Convert key code to string
private func keyCodeToString(_ keyCode: UInt16) -> String? {
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

// Main hotkey manager using CGEvent tap
@MainActor
class CustomHotkeyManager: ObservableObject {
    static let shared = CustomHotkeyManager()

    @Published var config: HotkeyConfig {
        didSet { saveConfig() }
    }
    @Published var isKeyDown = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastKeyDownTime: Date?

    // Callbacks
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private init() {
        // Load saved config
        if let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
           let saved = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            config = saved
        } else {
            config = .default
        }

        setupEventTap()
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfig")
        }
    }

    func setupEventTap() {
        // Remove existing tap if any
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }

        // Create event mask for key events and modifier changes
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)

        // Store self pointer for callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<CustomHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                Task { @MainActor in
                    manager.handleEvent(type: type, event: event)
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPointer
        ) else {
            print("Failed to create event tap - accessibility permission required")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Check if this is our configured key
        let isConfiguredKey: Bool

        if SpecialKeyCode(rawValue: config.keyCode)?.isModifier == true {
            // For modifier keys, check on flagsChanged
            if type == .flagsChanged && keyCode == config.keyCode {
                isConfiguredKey = true
            } else {
                isConfiguredKey = false
            }
        } else {
            // For regular keys, check keyDown/keyUp
            if (type == .keyDown || type == .keyUp) && keyCode == config.keyCode {
                // Check if required modifiers match
                if config.requiresModifiers {
                    let currentFlags = event.flags.rawValue & (CGEventFlags.maskCommand.rawValue |
                                                                CGEventFlags.maskShift.rawValue |
                                                                CGEventFlags.maskAlternate.rawValue |
                                                                CGEventFlags.maskControl.rawValue)
                    isConfiguredKey = currentFlags == config.modifierFlags
                } else {
                    isConfiguredKey = true
                }
            } else {
                isConfiguredKey = false
            }
        }

        guard isConfiguredKey else { return }

        // Determine if key is down or up
        let keyIsDown: Bool

        if type == .flagsChanged {
            // For modifier keys, check the flags
            let flags = event.flags
            switch SpecialKeyCode(rawValue: keyCode) {
            case .leftCommand, .rightCommand:
                keyIsDown = flags.contains(.maskCommand)
            case .leftShift, .rightShift:
                keyIsDown = flags.contains(.maskShift)
            case .leftOption, .rightOption:
                keyIsDown = flags.contains(.maskAlternate)
            case .leftControl, .rightControl:
                keyIsDown = flags.contains(.maskControl)
            case .capsLock:
                keyIsDown = flags.contains(.maskAlphaShift)
            case .fn:
                keyIsDown = flags.contains(.maskSecondaryFn)
            default:
                keyIsDown = false
            }
        } else {
            keyIsDown = type == .keyDown
        }

        // Handle state change
        if keyIsDown && !isKeyDown {
            isKeyDown = true
            lastKeyDownTime = Date()
            onKeyDown?()
        } else if !keyIsDown && isKeyDown {
            isKeyDown = false
            onKeyUp?()
        }
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
