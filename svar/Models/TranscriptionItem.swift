//
//  TranscriptionItem.swift
//  swar
//

import Foundation

struct TranscriptionItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval

    init(text: String, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.duration = duration
    }
}
