//
//  TextInserter.swift
//  swar
//

import AppKit
import Carbon.HIToolbox
import UserNotifications

class TextInserter {
    static let shared = TextInserter()

    private init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func insertText(_ text: String, mode: OutputMode) {
        // Analyze context and prepare text
        let processedText = prepareText(text)

        switch mode {
        case .paste:
            pasteText(processedText, restoreClipboard: true)
        case .clipboard:
            copyToClipboard(processedText)
            showNotification(text: processedText)
        case .pasteAndClipboard:
            pasteText(processedText, restoreClipboard: false)
        }
    }

    /// Analyze context and prepare text with smart spacing
    private func prepareText(_ text: String) -> String {
        var processedText = text
        let punctuationAndWhitespace: Set<Character> = [".", ",", "!", "?", ";", ":", ")", "]", "}", "'", "\"", " ", "\t", "\n", "\r"]

        print("TextInserter: Preparing text: '\(text)'")

        // Analyze the current text context
        if let context = TextContextAnalyzer.shared.analyze() {
            // Log context for debugging
            print(context.debugDescription)

            // Debug the spacing decision
            print("TextInserter: hasSelection=\(context.hasSelection), isAtStart=\(context.isAtStartOfDocument)")
            print("TextInserter: charBefore='\(context.characterBeforeCursor.map { String($0) } ?? "nil")'")
            print("TextInserter: needsLeadingSpace=\(context.needsLeadingSpace)")
            print("TextInserter: fullText length=\(context.fullText?.count ?? -1), cursorPosition=\(context.cursorPosition ?? -1)")

            // Smart spacing: add leading space if needed
            if context.needsLeadingSpace && !processedText.isEmpty {
                // Don't add space if transcription starts with punctuation
                let firstChar = processedText.first!
                let punctuation: Set<Character> = [".", ",", "!", "?", ";", ":", ")", "]", "}", "'", "\""]
                if !punctuation.contains(firstChar) {
                    processedText = " " + processedText
                    print("TextInserter: ✅ Added leading space, result: '\(processedText)'")
                } else {
                    print("TextInserter: Skipped space - text starts with punctuation")
                }
            } else if context.fullText == nil || context.cursorPosition == nil || context.characterBeforeCursor == nil {
                // Fallback: if we couldn't read the text context properly, add space unless:
                // - transcription starts with punctuation/whitespace
                // - we're at the start of the document
                // - cursor position is out of range (characterBeforeCursor is nil but we have text)
                print("TextInserter: ⚠️ Could not read char before cursor, using fallback logic")
                if !context.isAtStartOfDocument && !processedText.isEmpty, let firstChar = processedText.first, !punctuationAndWhitespace.contains(firstChar) {
                    processedText = " " + processedText
                    print("TextInserter: ✅ Added leading space (fallback), result: '\(processedText)'")
                }
            } else {
                print("TextInserter: No leading space needed")
            }

            // If there's selected text, we'll be replacing it
            if context.hasSelection {
                print("TextInserter: Will replace selection of \(context.selectionLength ?? 0) characters")
            }
        } else {
            // Complete fallback: couldn't even get a context object
            print("TextInserter: ❌ Could not analyze context, using fallback logic")
            // Add space by default unless transcription starts with punctuation/whitespace
            if !processedText.isEmpty, let firstChar = processedText.first, !punctuationAndWhitespace.contains(firstChar) {
                processedText = " " + processedText
                print("TextInserter: ✅ Added leading space (complete fallback), result: '\(processedText)'")
            }
        }

        print("TextInserter: Final text: '\(processedText)'")
        return processedText
    }

    private func pasteText(_ text: String, restoreClipboard: Bool) {
        guard PermissionManager.shared.hasAccessibilityPermission else {
            copyToClipboard(text)
            showNotification(text: text, fallback: true)
            return
        }

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Copy text to clipboard
        copyToClipboard(text)

        // Small delay to ensure clipboard is updated
        usleep(50000) // 50ms

        // Simulate Cmd+V
        simulatePaste()

        // Restore clipboard if needed
        if restoreClipboard, let previous = previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)

        // Key up: Cmd+V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func showNotification(text: String, fallback: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = fallback ? "Copied to Clipboard (Paste Failed)" : "Copied to Clipboard"
        content.body = String(text.prefix(100)) + (text.count > 100 ? "..." : "")

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
