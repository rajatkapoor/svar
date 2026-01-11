//
//  VocabularyPostProcessor.swift
//  svar
//
//  Three-tier post-processing for vocabulary corrections:
//  - Tier 1: Exact replacement for explicit misspellings
//  - Tier 2: Phonetic matching for similar-sounding words
//  - Tier 3: N-gram matching for split words (e.g., "type filly" → "typefully")
//

import Foundation

class VocabularyPostProcessor {
    static let shared = VocabularyPostProcessor()

    private init() {}

    func process(_ text: String) -> String {
        guard !VocabularyManager.shared.entries.isEmpty else { return text }

        var result = text

        // Tier 3: N-gram matching for split words (run first to rejoin before other processing)
        result = applyNgramMatching(result)

        // Tier 1: Exact replacements (misspelling -> correct word)
        result = applyExactReplacements(result)

        // Tier 2: Phonetic corrections
        result = applyPhoneticCorrections(result)

        return result
    }

    private func applyExactReplacements(_ text: String) -> String {
        var result = text
        let index = VocabularyManager.shared.misspellingIndex

        guard !index.isEmpty else { return text }

        // Match word boundaries
        let pattern = "\\b\\w+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process in reverse to maintain positions
        for match in matches.reversed() {
            let word = nsString.substring(with: match.range)
            if let replacement = index[word.lowercased()] {
                // Preserve original capitalization pattern
                let corrected = preserveCapitalization(original: word, replacement: replacement)
                result = (result as NSString).replacingCharacters(in: match.range, with: corrected)
            }
        }

        return result
    }

    private func applyPhoneticCorrections(_ text: String) -> String {
        var result = text
        let phoneticIndex = VocabularyManager.shared.phoneticIndex

        guard !phoneticIndex.isEmpty else { return text }

        let pattern = "\\b\\w+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            let word = nsString.substring(with: match.range)

            // Skip short words (too many false positives)
            guard word.count >= 3 else { continue }

            // Skip if already in misspelling index (handled by Tier 1)
            if VocabularyManager.shared.misspellingIndex[word.lowercased()] != nil {
                continue
            }

            // Find phonetic matches
            let candidates = PhoneticMatcher.shared.findPhoneticMatches(
                for: word,
                in: phoneticIndex
            )

            // Only replace if there's exactly one unambiguous match
            if candidates.count == 1, let entry = candidates.first {
                // Don't replace if the word already matches the target
                if word.lowercased() != entry.word.lowercased() {
                    let corrected = preserveCapitalization(original: word, replacement: entry.word)
                    result = (result as NSString).replacingCharacters(in: match.range, with: corrected)
                }
            }
        }

        return result
    }

    // MARK: - Tier 3: N-gram Matching for Split Words

    private func applyNgramMatching(_ text: String) -> String {
        let entries = VocabularyManager.shared.entries
        guard !entries.isEmpty else { return text }

        // Build a lookup of concatenated dictionary words for quick matching
        // Maps lowercase concatenated form -> (original word, entry)
        var concatenatedIndex: [String: VocabularyEntry] = [:]
        for entry in entries {
            concatenatedIndex[entry.word.lowercased()] = entry
        }

        // Extract words with their ranges
        let pattern = "\\b\\w+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        guard matches.count >= 2 else { return text }

        // Build list of (word, range) tuples
        var wordRanges: [(word: String, range: NSRange)] = []
        for match in matches {
            let word = nsString.substring(with: match.range)
            wordRanges.append((word, match.range))
        }

        // Find replacements (process trigrams first, then bigrams to prefer longer matches)
        var replacements: [(combinedRange: NSRange, replacement: String)] = []
        var usedIndices: Set<Int> = []

        // Check trigrams (3 consecutive words)
        for i in 0..<(wordRanges.count - 2) {
            if usedIndices.contains(i) || usedIndices.contains(i + 1) || usedIndices.contains(i + 2) {
                continue
            }

            let combined = wordRanges[i].word + wordRanges[i + 1].word + wordRanges[i + 2].word
            if let match = findNgramMatch(combined: combined, in: concatenatedIndex) {
                let startRange = wordRanges[i].range
                let endRange = wordRanges[i + 2].range
                let combinedRange = NSRange(
                    location: startRange.location,
                    length: endRange.location + endRange.length - startRange.location
                )
                let originalText = nsString.substring(with: combinedRange)
                let corrected = preserveCapitalization(original: originalText, replacement: match.word)
                replacements.append((combinedRange, corrected))
                usedIndices.insert(i)
                usedIndices.insert(i + 1)
                usedIndices.insert(i + 2)
            }
        }

        // Check bigrams (2 consecutive words)
        for i in 0..<(wordRanges.count - 1) {
            if usedIndices.contains(i) || usedIndices.contains(i + 1) {
                continue
            }

            let combined = wordRanges[i].word + wordRanges[i + 1].word
            if let match = findNgramMatch(combined: combined, in: concatenatedIndex) {
                let startRange = wordRanges[i].range
                let endRange = wordRanges[i + 1].range
                let combinedRange = NSRange(
                    location: startRange.location,
                    length: endRange.location + endRange.length - startRange.location
                )
                let originalText = nsString.substring(with: combinedRange)
                let corrected = preserveCapitalization(original: originalText, replacement: match.word)
                replacements.append((combinedRange, corrected))
                usedIndices.insert(i)
                usedIndices.insert(i + 1)
            }
        }

        // Apply replacements in reverse order to maintain positions
        var result = text
        for replacement in replacements.sorted(by: { $0.combinedRange.location > $1.combinedRange.location }) {
            result = (result as NSString).replacingCharacters(in: replacement.combinedRange, with: replacement.replacement)
        }

        return result
    }

    private func findNgramMatch(combined: String, in index: [String: VocabularyEntry]) -> VocabularyEntry? {
        let lowercased = combined.lowercased()

        // First try exact match
        if let entry = index[lowercased] {
            return entry
        }

        // Then try phonetic matching
        let phoneticIndex = VocabularyManager.shared.phoneticIndex
        guard !phoneticIndex.isEmpty else { return nil }

        // Skip if too short
        guard combined.count >= 4 else { return nil }

        let candidates = PhoneticMatcher.shared.findPhoneticMatches(
            for: combined,
            in: phoneticIndex
        )

        // Only return if there's exactly one unambiguous match
        if candidates.count == 1, let entry = candidates.first {
            // Verify the match makes sense (the combined form should be similar to the target)
            let distance = PhoneticMatcher.shared.levenshteinDistance(lowercased, entry.word.lowercased())
            // Allow slightly more edits for n-grams since we're joining words
            if distance <= 3 {
                return entry
            }
        }

        return nil
    }

    // MARK: - Capitalization Helper

    private func preserveCapitalization(original: String, replacement: String) -> String {
        guard !original.isEmpty else { return replacement }

        // All caps
        if original == original.uppercased() && original != original.lowercased() {
            return replacement.uppercased()
        }
        // Title case (first letter capitalized, rest lowercase)
        if let first = original.first, first.isUppercase {
            let rest = original.dropFirst()
            if rest == rest.lowercased() {
                return replacement.prefix(1).uppercased() + replacement.dropFirst().lowercased()
            }
        }
        // All lowercase
        if original == original.lowercased() {
            return replacement.lowercased()
        }
        // Default: use replacement as-is (preserves original casing of the dictionary word)
        return replacement
    }
}
