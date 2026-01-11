//
//  VocabularyEntry.swift
//  svar
//

import Foundation

struct VocabularyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var word: String
    var misspellings: [String]
    var usePhoneticMatching: Bool
    var phoneticPrimary: String?
    var phoneticSecondary: String?
    var createdAt: Date

    init(word: String, misspellings: [String] = [], usePhoneticMatching: Bool = true) {
        self.id = UUID()
        self.word = word
        self.misspellings = misspellings
        self.usePhoneticMatching = usePhoneticMatching
        self.phoneticPrimary = nil
        self.phoneticSecondary = nil
        self.createdAt = Date()
    }
}
