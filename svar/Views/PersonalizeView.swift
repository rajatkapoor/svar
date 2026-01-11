//
//  PersonalizeView.swift
//  svar
//

import SwiftUI

struct PersonalizeView: View {
    @State private var entries: [VocabularyEntry] = []
    @State private var showingAddSheet = false
    @State private var editingEntry: VocabularyEntry?
    @State private var hoveredEntryId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Page header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize")
                        .font(.system(size: 24, weight: .bold))
                    Text("Customize Svar to work better for you")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // Dictionary Section
                dictionarySection
            }
            .padding(20)
        }
        .onAppear { loadEntries() }
        .sheet(isPresented: $showingAddSheet) {
            AddVocabularySheet(existingEntry: nil) { entry in
                VocabularyManager.shared.addEntry(entry)
                loadEntries()
            }
        }
        .sheet(item: $editingEntry) { entry in
            AddVocabularySheet(existingEntry: entry) { updated in
                VocabularyManager.shared.updateEntry(updated)
                loadEntries()
            }
        }
    }

    // MARK: - Dictionary Section

    private var dictionarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with icon
            HStack(spacing: 8) {
                Image(systemName: "textformat.abc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SvarColors.accent)
                Text("Dictionary")
                    .font(.system(size: 15, weight: .semibold))
            }

            // Section content card
            VStack(alignment: .leading, spacing: 16) {
                // Explanation
                Text("Add words specific to your vocabulary that transcription often gets wrong. This helps Svar recognize names, technical terms, and domain-specific words.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().opacity(0.5)

                // Add word button
                HStack {
                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add Word")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(SvarColors.accent)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !entries.isEmpty {
                        Text("\(entries.count) word\(entries.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // Words table
                if !entries.isEmpty {
                    Divider().opacity(0.5)
                    wordsTable
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Words Table

    private var wordsTable: some View {
        VStack(spacing: 0) {
            // Table header
            HStack {
                Text("Word")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .leading)

                Text("Corrections")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Phonetic")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .center)

                // Actions column spacer
                Color.clear.frame(width: 60)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            // Table rows
            ForEach(entries) { entry in
                VocabularyRow(
                    entry: entry,
                    isHovered: hoveredEntryId == entry.id,
                    onEdit: { editingEntry = entry },
                    onDelete: {
                        VocabularyManager.shared.deleteEntry(entry)
                        loadEntries()
                    },
                    onHover: { hovering in
                        hoveredEntryId = hovering ? entry.id : nil
                    }
                )

                if entry.id != entries.last?.id {
                    Divider().opacity(0.2)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.02))
        )
    }

    private func loadEntries() {
        entries = VocabularyManager.shared.entries
    }
}

// MARK: - Vocabulary Row

struct VocabularyRow: View {
    let entry: VocabularyEntry
    let isHovered: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        HStack {
            // Word
            Text(entry.word)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)

            // Misspellings/Corrections
            Group {
                if entry.misspellings.isEmpty {
                    Text("—")
                        .foregroundColor(.secondary.opacity(0.5))
                } else {
                    Text(entry.misspellings.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)

            // Phonetic badge
            Group {
                if entry.usePhoneticMatching {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }
            .font(.system(size: 12))
            .frame(width: 60, alignment: .center)

            // Actions
            HStack(spacing: 4) {
                if isHovered {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(isHovered ? 0.03 : 0))
        )
        .contentShape(Rectangle())
        .onHover { onHover($0) }
    }
}
