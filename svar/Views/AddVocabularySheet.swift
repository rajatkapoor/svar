//
//  AddVocabularySheet.swift
//  svar
//

import SwiftUI

struct AddVocabularySheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingEntry: VocabularyEntry?
    let onSave: (VocabularyEntry) -> Void

    @State private var word: String = ""
    @State private var enableMisspellings: Bool = false
    @State private var misspellings: [String] = []
    @State private var newMisspelling: String = ""
    @State private var usePhoneticMatching: Bool = true

    var isEditing: Bool { existingEntry != nil }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text(isEditing ? "Edit Word" : "Add Word")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }

            // Word input
            VStack(alignment: .leading, spacing: 8) {
                Text("Word")
                    .font(.system(size: 13, weight: .medium))
                TextField("e.g., Kubernetes", text: $word)
                    .textFieldStyle(.roundedBorder)
            }

            // Misspellings section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Correct specific misspellings", isOn: $enableMisspellings)
                    .font(.system(size: 13))

                if enableMisspellings {
                    Text("Add words that should be corrected to this word")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // Misspelling input
                    HStack {
                        TextField("Add misspelling...", text: $newMisspelling)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addMisspelling() }

                        Button("Add") { addMisspelling() }
                            .disabled(newMisspelling.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Misspelling tags
                    if !misspellings.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(misspellings, id: \.self) { misspelling in
                                MisspellingTag(text: misspelling) {
                                    misspellings.removeAll { $0 == misspelling }
                                }
                            }
                        }
                    }
                }
            }

            Divider().opacity(0.5)

            // Phonetic matching
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use phonetic matching", isOn: $usePhoneticMatching)
                    .font(.system(size: 13))

                Text("Phonetic matching corrects words that sound similar to this word")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button(isEditing ? "Save" : "Add Word") { save() }
                    .keyboardShortcut(.return)
                    .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 420)
        .onAppear { loadExistingEntry() }
    }

    private func loadExistingEntry() {
        guard let entry = existingEntry else { return }
        word = entry.word
        misspellings = entry.misspellings
        enableMisspellings = !entry.misspellings.isEmpty
        usePhoneticMatching = entry.usePhoneticMatching
    }

    private func addMisspelling() {
        let trimmed = newMisspelling.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !misspellings.contains(trimmed) else { return }
        misspellings.append(trimmed)
        newMisspelling = ""
    }

    private func save() {
        let trimmedWord = word.trimmingCharacters(in: .whitespaces)
        guard !trimmedWord.isEmpty else { return }

        var entry = existingEntry ?? VocabularyEntry(word: trimmedWord)
        entry.word = trimmedWord
        entry.misspellings = enableMisspellings ? misspellings : []
        entry.usePhoneticMatching = usePhoneticMatching

        onSave(entry)
        dismiss()
    }
}

// MARK: - Misspelling Tag

struct MisspellingTag: View {
    let text: String
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.primary.opacity(0.1))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (subview, offset) in zip(subviews, offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (size: CGSize, offsets: [CGPoint]) {
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), offsets)
    }
}
