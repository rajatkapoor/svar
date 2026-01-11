//
//  HistoryManager.swift
//  swar
//

import Foundation

class HistoryManager {
    static let shared = HistoryManager()

    private let historyKey = "transcriptionHistory"

    private init() {}

    func load() -> [TranscriptionItem] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let items = try? JSONDecoder().decode([TranscriptionItem].self, from: data) else {
            return []
        }
        return items
    }

    @MainActor
    func save(_ items: [TranscriptionItem]) {
        let maxItems = AppState.shared.maxHistoryItems
        let itemsToSave = Array(items.prefix(maxItems))
        if let data = try? JSONEncoder().encode(itemsToSave) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
