//
//  VocabularyManager.swift
//  svar
//

import Foundation

class VocabularyManager {
    static let shared = VocabularyManager()

    private let vocabularyKey = "vocabularyEntries"
    private(set) var entries: [VocabularyEntry] = []
    private(set) var misspellingIndex: [String: String] = [:]  // lowercase misspelling -> correct word
    private(set) var phoneticIndex: [String: [VocabularyEntry]] = [:]  // phonetic code -> entries

    private init() {
        entries = load()
        rebuildIndexes()
    }

    func load() -> [VocabularyEntry] {
        guard let data = UserDefaults.standard.data(forKey: vocabularyKey),
              let items = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
            return []
        }
        return items
    }

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: vocabularyKey)
        }
        rebuildIndexes()
    }

    func addEntry(_ entry: VocabularyEntry) {
        var newEntry = entry
        if entry.usePhoneticMatching {
            let (primary, secondary) = PhoneticMatcher.shared.computePhoneticCodes(for: entry.word)
            newEntry.phoneticPrimary = primary
            newEntry.phoneticSecondary = secondary
        }
        entries.insert(newEntry, at: 0)
        save()
    }

    func updateEntry(_ entry: VocabularyEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            var updated = entry
            if entry.usePhoneticMatching {
                let (primary, secondary) = PhoneticMatcher.shared.computePhoneticCodes(for: entry.word)
                updated.phoneticPrimary = primary
                updated.phoneticSecondary = secondary
            } else {
                updated.phoneticPrimary = nil
                updated.phoneticSecondary = nil
            }
            entries[index] = updated
            save()
        }
    }

    func deleteEntry(_ entry: VocabularyEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: vocabularyKey)
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        misspellingIndex.removeAll()
        phoneticIndex.removeAll()

        for entry in entries {
            // Build misspelling index
            for misspelling in entry.misspellings {
                misspellingIndex[misspelling.lowercased()] = entry.word
            }
            // Build phonetic index
            if entry.usePhoneticMatching {
                if let primary = entry.phoneticPrimary {
                    phoneticIndex[primary, default: []].append(entry)
                }
                if let secondary = entry.phoneticSecondary, secondary != entry.phoneticPrimary {
                    phoneticIndex[secondary, default: []].append(entry)
                }
            }
        }
    }
}
