//
//  TextContextAnalyzer.swift
//  swar
//
//  Analyzes the focused text field context using Accessibility APIs
//

import Foundation
import AppKit
import ApplicationServices

/// Information about the currently focused text context
struct TextContext {
    // App info
    let appName: String?
    let appBundleID: String?
    let appPID: pid_t?

    // Window info
    let windowTitle: String?
    let documentPath: String?
    let documentURL: URL?

    // Element info
    let elementRole: String?
    let elementSubrole: String?
    let elementIdentifier: String?
    let isEnabled: Bool
    let isFocused: Bool

    // Text info
    let fullText: String?
    let selectedText: String?
    let cursorPosition: Int?        // Location in text
    let selectionLength: Int?       // Length of selection (0 if just cursor)
    let totalCharacters: Int?
    let insertionLineNumber: Int?
    let placeholderText: String?

    // Computed properties for convenience
    var hasSelection: Bool {
        return (selectionLength ?? 0) > 0
    }

    var hasText: Bool {
        return (fullText?.isEmpty == false)
    }

    var isAtStartOfDocument: Bool {
        return cursorPosition == 0
    }

    var isAtEndOfDocument: Bool {
        guard let pos = cursorPosition, let total = totalCharacters else { return false }
        return pos >= total
    }

    /// Character immediately before cursor (nil if at start)
    var characterBeforeCursor: Character? {
        guard let text = fullText,
              let pos = cursorPosition,
              pos > 0,
              pos <= text.count else { return nil }

        let index = text.index(text.startIndex, offsetBy: pos - 1)
        return text[index]
    }

    /// Character immediately after cursor (nil if at end)
    var characterAfterCursor: Character? {
        guard let text = fullText,
              let pos = cursorPosition,
              let len = selectionLength,
              pos + len < text.count else { return nil }

        let index = text.index(text.startIndex, offsetBy: pos + len)
        return text[index]
    }

    /// Whether cursor is at the start of a new sentence
    var isAtSentenceStart: Bool {
        guard let char = characterBeforeCursor else {
            return true // At start of document
        }
        // After sentence-ending punctuation followed by space
        let sentenceEnders: Set<Character> = [".", "!", "?", "\n", "\r"]
        if sentenceEnders.contains(char) {
            return true
        }
        // Check if previous char is space and char before that is sentence ender
        if char == " " || char == "\t" {
            guard let text = fullText,
                  let pos = cursorPosition,
                  pos > 1 else { return false }
            let prevIndex = text.index(text.startIndex, offsetBy: pos - 2)
            return sentenceEnders.contains(text[prevIndex])
        }
        return false
    }

    /// Whether we need to add a space before inserting text
    var needsLeadingSpace: Bool {
        // Don't add space if there's a selection (we're replacing)
        if hasSelection { return false }

        // Don't add space at start of document
        if isAtStartOfDocument { return false }

        guard let char = characterBeforeCursor else { return false }

        // Characters that don't need a space after them
        let noSpaceAfter: Set<Character> = [" ", "\t", "\n", "\r", "(", "[", "{", "\"", "'", "`", "/", "\\"]
        return !noSpaceAfter.contains(char)
    }

    /// Whether the app is a code editor (for potential special handling)
    var isCodeEditor: Bool {
        let codeEditorBundleIDs: Set<String> = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.sublimetext.3",
            "com.sublimetext.4",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
            "io.alacritty",
            "com.github.atom",
            "com.panic.Nova",
            "com.barebones.bbedit",
            "com.coteditor.CotEditor",
            "md.obsidian",
            "com.electron.cursor" // Cursor IDE
        ]
        return appBundleID.map { codeEditorBundleIDs.contains($0) } ?? false
    }

    /// Debug description
    var debugDescription: String {
        """
        TextContext:
          App: \(appName ?? "nil") (\(appBundleID ?? "nil"))
          Window: \(windowTitle ?? "nil")
          Element: \(elementRole ?? "nil") / \(elementSubrole ?? "nil")
          Text length: \(totalCharacters ?? 0)
          Cursor: \(cursorPosition ?? -1), Selection: \(selectionLength ?? 0)
          Has selection: \(hasSelection)
          Char before: \(characterBeforeCursor.map { String($0) } ?? "nil")
          Needs leading space: \(needsLeadingSpace)
          Is code editor: \(isCodeEditor)
        """
    }
}

/// Analyzes the currently focused text field using Accessibility APIs
class TextContextAnalyzer {
    static let shared = TextContextAnalyzer()

    private init() {}

    /// Analyze the current text context
    func analyze() -> TextContext? {
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef) == .success,
              let focusedApp = focusedAppRef else {
            print("TextContextAnalyzer: Could not get focused application")
            return nil
        }
        // AXUIElement is a CFTypeRef, we need to treat it as such
        let focusedAppElement = focusedApp as! AXUIElement

        // Get app info
        var pid: pid_t = 0
        AXUIElementGetPid(focusedAppElement, &pid)

        let runningApp = NSRunningApplication(processIdentifier: pid)
        let appName = runningApp?.localizedName
        let appBundleID = runningApp?.bundleIdentifier

        // Get focused UI element
        var focusedElementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
              let focusedElementValue = focusedElementRef else {
            print("TextContextAnalyzer: Could not get focused element")
            return nil
        }
        let focusedElement = focusedElementValue as! AXUIElement

        // Get window info
        let windowTitle: String? = {
            // Try to get window from focused element
            if let windowRef = getStringAttribute(focusedElement, kAXWindowAttribute as CFString) {
                let window = windowRef as! AXUIElement
                if let title = getStringAttribute(window, kAXTitleAttribute as CFString) as? String {
                    return title
                }
            }
            // Fallback: try to get focused window from app
            if let windowRef = getStringAttribute(focusedAppElement, kAXFocusedWindowAttribute as CFString) {
                let window = windowRef as! AXUIElement
                if let title = getStringAttribute(window, kAXTitleAttribute as CFString) as? String {
                    return title
                }
            }
            return nil
        }()

        let documentPath = getStringAttribute(focusedElement, kAXFilenameAttribute as CFString) as? String
        let documentURL = getURLAttribute(focusedElement, kAXURLAttribute as CFString)

        // Get element info
        let elementRole = getStringAttribute(focusedElement, kAXRoleAttribute as CFString) as? String
        let elementSubrole = getStringAttribute(focusedElement, kAXSubroleAttribute as CFString) as? String
        let elementIdentifier = getStringAttribute(focusedElement, kAXIdentifierAttribute as CFString) as? String
        let isEnabled = getBoolAttribute(focusedElement, kAXEnabledAttribute as CFString) ?? false
        let isFocused = getBoolAttribute(focusedElement, kAXFocusedAttribute as CFString) ?? false

        // Get text info
        let fullText = getStringAttribute(focusedElement, kAXValueAttribute as CFString) as? String
        let selectedText = getStringAttribute(focusedElement, kAXSelectedTextAttribute as CFString) as? String
        let placeholderText = getStringAttribute(focusedElement, kAXPlaceholderValueAttribute as CFString) as? String
        let totalCharacters = getIntAttribute(focusedElement, kAXNumberOfCharactersAttribute as CFString)
        let insertionLineNumber = getIntAttribute(focusedElement, kAXInsertionPointLineNumberAttribute as CFString)

        // Get cursor position and selection range
        var cursorPosition: Int?
        var selectionLength: Int?

        if let range = getRangeAttribute(focusedElement, kAXSelectedTextRangeAttribute as CFString) {
            cursorPosition = range.location
            selectionLength = range.length
        }

        return TextContext(
            appName: appName,
            appBundleID: appBundleID,
            appPID: pid,
            windowTitle: windowTitle,
            documentPath: documentPath,
            documentURL: documentURL,
            elementRole: elementRole,
            elementSubrole: elementSubrole,
            elementIdentifier: elementIdentifier,
            isEnabled: isEnabled,
            isFocused: isFocused,
            fullText: fullText,
            selectedText: selectedText,
            cursorPosition: cursorPosition,
            selectionLength: selectionLength,
            totalCharacters: totalCharacters,
            insertionLineNumber: insertionLineNumber,
            placeholderText: placeholderText
        )
    }

    // MARK: - Helper methods to get attributes

    private func getStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue
    }

    private func getIntAttribute(_ element: AXUIElement, _ attribute: CFString) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return (value as? Int) ?? (value as? NSNumber)?.intValue
    }

    private func getURLAttribute(_ element: AXUIElement, _ attribute: CFString) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        if let url = value as? URL {
            return url
        }
        if let urlString = value as? String {
            return URL(string: urlString)
        }
        return nil
    }

    private func getRangeAttribute(_ element: AXUIElement, _ attribute: CFString) -> (location: Int, length: Int)? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let axValue = value else { return nil }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue as! AXValue, .cfRange, &range) else { return nil }

        return (location: range.location, length: range.length)
    }
}
