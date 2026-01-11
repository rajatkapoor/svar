//
//  PhoneticMatcher.swift
//  svar
//
//  Double Metaphone algorithm and Levenshtein distance for phonetic matching.
//

import Foundation

class PhoneticMatcher {
    static let shared = PhoneticMatcher()

    private init() {}

    // MARK: - Public API

    /// Compute Double Metaphone codes for a word
    func computePhoneticCodes(for word: String) -> (primary: String?, secondary: String?) {
        let cleanWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanWord.count >= 3 else { return (nil, nil) }

        return doubleMetaphone(cleanWord)
    }

    /// Calculate Levenshtein edit distance between two strings
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Create distance matrix
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        // Initialize first column
        for i in 0...m {
            matrix[i][0] = i
        }

        // Initialize first row
        for j in 0...n {
            matrix[0][j] = j
        }

        // Fill in the rest of the matrix
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    /// Find vocabulary entries that phonetically match the given word
    func findPhoneticMatches(for word: String, in index: [String: [VocabularyEntry]]) -> [VocabularyEntry] {
        let (primary, secondary) = computePhoneticCodes(for: word)
        var candidates: Set<UUID> = []
        var results: [VocabularyEntry] = []

        // Look up by primary phonetic code
        if let primary = primary, let entries = index[primary] {
            for entry in entries where !candidates.contains(entry.id) {
                // Verify with Levenshtein distance
                let distance = levenshteinDistance(word.lowercased(), entry.word.lowercased())
                let threshold = max(2, entry.word.count / 3)
                if distance <= threshold {
                    candidates.insert(entry.id)
                    results.append(entry)
                }
            }
        }

        // Look up by secondary phonetic code
        if let secondary = secondary, let entries = index[secondary] {
            for entry in entries where !candidates.contains(entry.id) {
                let distance = levenshteinDistance(word.lowercased(), entry.word.lowercased())
                let threshold = max(2, entry.word.count / 3)
                if distance <= threshold {
                    candidates.insert(entry.id)
                    results.append(entry)
                }
            }
        }

        return results
    }

    // MARK: - Double Metaphone Implementation

    /// Double Metaphone algorithm - generates primary and secondary phonetic codes
    /// Based on Lawrence Philips' algorithm
    private func doubleMetaphone(_ word: String) -> (String?, String?) {
        var primary = ""
        var secondary = ""
        let maxLength = 4

        let chars = Array(word.uppercased())
        let length = chars.count
        var current = 0

        // Pad the word for easier boundary checking
        let last = length - 1

        // Helper functions
        func isVowel(_ c: Character) -> Bool {
            return "AEIOU".contains(c)
        }

        func charAt(_ index: Int) -> Character {
            guard index >= 0 && index < length else { return " " }
            return chars[index]
        }

        func stringAt(_ start: Int, _ len: Int, _ strings: [String]) -> Bool {
            guard start >= 0 && start + len <= length else { return false }
            let substring = String(chars[start..<(start + len)])
            return strings.contains(substring)
        }

        func isSlavoGermanic() -> Bool {
            let str = String(chars)
            return str.contains("W") || str.contains("K") || str.contains("CZ") || str.contains("WITZ")
        }

        // Skip initial silent letters
        if stringAt(0, 2, ["GN", "KN", "PN", "WR", "PS"]) {
            current += 1
        }

        // Initial 'X' is pronounced 'Z'
        if charAt(0) == "X" {
            primary += "S"
            secondary += "S"
            current += 1
        }

        // Main loop
        while current < length && (primary.count < maxLength || secondary.count < maxLength) {
            let ch = charAt(current)

            switch ch {
            case "A", "E", "I", "O", "U", "Y":
                if current == 0 {
                    primary += "A"
                    secondary += "A"
                }
                current += 1

            case "B":
                primary += "P"
                secondary += "P"
                current += (charAt(current + 1) == "B") ? 2 : 1

            case "Ç":
                primary += "S"
                secondary += "S"
                current += 1

            case "C":
                // Various Germanic sounds
                if current > 1 && !isVowel(charAt(current - 2)) &&
                    stringAt(current - 1, 3, ["ACH"]) &&
                    (charAt(current + 2) != "I" && (charAt(current + 2) != "E" || stringAt(current - 2, 6, ["BACHER", "MACHER"]))) {
                    primary += "K"
                    secondary += "K"
                    current += 2
                } else if current == 0 && stringAt(current, 6, ["CAESAR"]) {
                    primary += "S"
                    secondary += "S"
                    current += 2
                } else if stringAt(current, 2, ["CH"]) {
                    // CH handling
                    if current > 0 && stringAt(current, 4, ["CHAE"]) {
                        primary += "K"
                        secondary += "X"
                        current += 2
                    } else if current == 0 && (stringAt(current + 1, 5, ["HARAC", "HARIS"]) ||
                                               stringAt(current + 1, 3, ["HOR", "HYM", "HIA", "HEM"])) &&
                                !stringAt(0, 5, ["CHORE"]) {
                        primary += "K"
                        secondary += "K"
                        current += 2
                    } else if stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"]) ||
                              stringAt(current - 2, 6, ["ORCHES", "ARCHIT", "ORCHID"]) ||
                              stringAt(current + 2, 1, ["T", "S"]) ||
                              ((stringAt(current - 1, 1, ["A", "O", "U", "E"]) || current == 0) &&
                               stringAt(current + 2, 1, ["L", "R", "N", "M", "B", "H", "F", "V", "W", " "])) {
                        primary += "K"
                        secondary += "K"
                        current += 2
                    } else {
                        if current > 0 {
                            if stringAt(0, 2, ["MC"]) {
                                primary += "K"
                                secondary += "K"
                            } else {
                                primary += "X"
                                secondary += "K"
                            }
                        } else {
                            primary += "X"
                            secondary += "X"
                        }
                        current += 2
                    }
                } else if stringAt(current, 2, ["CZ"]) && !stringAt(current - 2, 4, ["WICZ"]) {
                    primary += "S"
                    secondary += "X"
                    current += 2
                } else if stringAt(current + 1, 3, ["CIA"]) {
                    primary += "X"
                    secondary += "X"
                    current += 3
                } else if stringAt(current, 2, ["CC"]) && !(current == 1 && charAt(0) == "M") {
                    if stringAt(current + 2, 1, ["I", "E", "H"]) && !stringAt(current + 2, 2, ["HU"]) {
                        if (current == 1 && charAt(current - 1) == "A") ||
                            stringAt(current - 1, 5, ["UCCEE", "UCCES"]) {
                            primary += "KS"
                            secondary += "KS"
                        } else {
                            primary += "X"
                            secondary += "X"
                        }
                        current += 3
                    } else {
                        primary += "K"
                        secondary += "K"
                        current += 2
                    }
                } else if stringAt(current, 2, ["CK", "CG", "CQ"]) {
                    primary += "K"
                    secondary += "K"
                    current += 2
                } else if stringAt(current, 2, ["CI", "CE", "CY"]) {
                    if stringAt(current, 3, ["CIO", "CIE", "CIA"]) {
                        primary += "S"
                        secondary += "X"
                    } else {
                        primary += "S"
                        secondary += "S"
                    }
                    current += 2
                } else {
                    primary += "K"
                    secondary += "K"
                    if stringAt(current + 1, 2, [" C", " Q", " G"]) {
                        current += 3
                    } else if stringAt(current + 1, 1, ["C", "K", "Q"]) && !stringAt(current + 1, 2, ["CE", "CI"]) {
                        current += 2
                    } else {
                        current += 1
                    }
                }

            case "D":
                if stringAt(current, 2, ["DG"]) {
                    if stringAt(current + 2, 1, ["I", "E", "Y"]) {
                        primary += "J"
                        secondary += "J"
                        current += 3
                    } else {
                        primary += "TK"
                        secondary += "TK"
                        current += 2
                    }
                } else if stringAt(current, 2, ["DT", "DD"]) {
                    primary += "T"
                    secondary += "T"
                    current += 2
                } else {
                    primary += "T"
                    secondary += "T"
                    current += 1
                }

            case "F":
                primary += "F"
                secondary += "F"
                current += (charAt(current + 1) == "F") ? 2 : 1

            case "G":
                if charAt(current + 1) == "H" {
                    if current > 0 && !isVowel(charAt(current - 1)) {
                        primary += "K"
                        secondary += "K"
                        current += 2
                    } else if current == 0 {
                        if charAt(current + 2) == "I" {
                            primary += "J"
                            secondary += "J"
                        } else {
                            primary += "K"
                            secondary += "K"
                        }
                        current += 2
                    } else if (current > 1 && stringAt(current - 2, 1, ["B", "H", "D"])) ||
                              (current > 2 && stringAt(current - 3, 1, ["B", "H", "D"])) ||
                              (current > 3 && stringAt(current - 4, 1, ["B", "H"])) {
                        current += 2
                    } else {
                        if current > 2 && charAt(current - 1) == "U" &&
                            stringAt(current - 3, 1, ["C", "G", "L", "R", "T"]) {
                            primary += "F"
                            secondary += "F"
                        } else if current > 0 && charAt(current - 1) != "I" {
                            primary += "K"
                            secondary += "K"
                        }
                        current += 2
                    }
                } else if charAt(current + 1) == "N" {
                    if current == 1 && isVowel(charAt(0)) && !isSlavoGermanic() {
                        primary += "KN"
                        secondary += "N"
                    } else {
                        if !stringAt(current + 2, 2, ["EY"]) && charAt(current + 1) != "Y" && !isSlavoGermanic() {
                            primary += "N"
                            secondary += "KN"
                        } else {
                            primary += "KN"
                            secondary += "KN"
                        }
                    }
                    current += 2
                } else if stringAt(current + 1, 2, ["LI"]) && !isSlavoGermanic() {
                    primary += "KL"
                    secondary += "L"
                    current += 2
                } else if current == 0 && (charAt(current + 1) == "Y" ||
                                           stringAt(current + 1, 2, ["ES", "EP", "EB", "EL", "EY", "IB", "IL", "IN", "IE", "EI", "ER"])) {
                    primary += "K"
                    secondary += "J"
                    current += 2
                } else if (stringAt(current + 1, 2, ["ER"]) || charAt(current + 1) == "Y") &&
                          !stringAt(0, 6, ["DANGER", "RANGER", "MANGER"]) &&
                          !stringAt(current - 1, 1, ["E", "I"]) &&
                          !stringAt(current - 1, 3, ["RGY", "OGY"]) {
                    primary += "K"
                    secondary += "J"
                    current += 2
                } else if stringAt(current + 1, 1, ["E", "I", "Y"]) || stringAt(current - 1, 4, ["AGGI", "OGGI"]) {
                    if stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"]) || stringAt(current + 1, 2, ["ET"]) {
                        primary += "K"
                        secondary += "K"
                    } else {
                        if stringAt(current + 1, 4, ["IER "]) {
                            primary += "J"
                            secondary += "J"
                        } else {
                            primary += "J"
                            secondary += "K"
                        }
                    }
                    current += 2
                } else {
                    primary += "K"
                    secondary += "K"
                    current += (charAt(current + 1) == "G") ? 2 : 1
                }

            case "H":
                if (current == 0 || isVowel(charAt(current - 1))) && isVowel(charAt(current + 1)) {
                    primary += "H"
                    secondary += "H"
                    current += 2
                } else {
                    current += 1
                }

            case "J":
                if stringAt(current, 4, ["JOSE"]) || stringAt(0, 4, ["SAN "]) {
                    if (current == 0 && charAt(current + 4) == " ") || stringAt(0, 4, ["SAN "]) {
                        primary += "H"
                        secondary += "H"
                    } else {
                        primary += "J"
                        secondary += "H"
                    }
                    current += 1
                } else {
                    if current == 0 && !stringAt(current, 4, ["JOSE"]) {
                        primary += "J"
                        secondary += "A"
                    } else {
                        if isVowel(charAt(current - 1)) && !isSlavoGermanic() && (charAt(current + 1) == "A" || charAt(current + 1) == "O") {
                            primary += "J"
                            secondary += "H"
                        } else if current == last {
                            primary += "J"
                            secondary += ""
                        } else if !stringAt(current + 1, 1, ["L", "T", "K", "S", "N", "M", "B", "Z"]) &&
                                  !stringAt(current - 1, 1, ["S", "K", "L"]) {
                            primary += "J"
                            secondary += "J"
                        }
                    }
                    current += (charAt(current + 1) == "J") ? 2 : 1
                }

            case "K":
                primary += "K"
                secondary += "K"
                current += (charAt(current + 1) == "K") ? 2 : 1

            case "L":
                if charAt(current + 1) == "L" {
                    if (current == length - 3 && stringAt(current - 1, 4, ["ILLO", "ILLA", "ALLE"])) ||
                        ((stringAt(last - 1, 2, ["AS", "OS"]) || stringAt(last, 1, ["A", "O"])) &&
                         stringAt(current - 1, 4, ["ALLE"])) {
                        primary += "L"
                        secondary += ""
                        current += 2
                    } else {
                        primary += "L"
                        secondary += "L"
                        current += 2
                    }
                } else {
                    primary += "L"
                    secondary += "L"
                    current += 1
                }

            case "M":
                primary += "M"
                secondary += "M"
                if stringAt(current - 1, 3, ["UMB"]) && (current + 1 == last || stringAt(current + 2, 2, ["ER"])) {
                    current += 2
                } else {
                    current += (charAt(current + 1) == "M") ? 2 : 1
                }

            case "N":
                primary += "N"
                secondary += "N"
                current += (charAt(current + 1) == "N") ? 2 : 1

            case "Ñ":
                primary += "N"
                secondary += "N"
                current += 1

            case "P":
                if charAt(current + 1) == "H" {
                    primary += "F"
                    secondary += "F"
                    current += 2
                } else {
                    primary += "P"
                    secondary += "P"
                    current += stringAt(current + 1, 1, ["P", "B"]) ? 2 : 1
                }

            case "Q":
                primary += "K"
                secondary += "K"
                current += (charAt(current + 1) == "Q") ? 2 : 1

            case "R":
                if current == last && !isSlavoGermanic() &&
                    stringAt(current - 2, 2, ["IE"]) && !stringAt(current - 4, 2, ["ME", "MA"]) {
                    primary += ""
                    secondary += "R"
                } else {
                    primary += "R"
                    secondary += "R"
                }
                current += (charAt(current + 1) == "R") ? 2 : 1

            case "S":
                if stringAt(current - 1, 3, ["ISL", "YSL"]) {
                    current += 1
                } else if current == 0 && stringAt(current, 5, ["SUGAR"]) {
                    primary += "X"
                    secondary += "S"
                    current += 1
                } else if stringAt(current, 2, ["SH"]) {
                    if stringAt(current + 1, 4, ["HEIM", "HOEK", "HOLM", "HOLZ"]) {
                        primary += "S"
                        secondary += "S"
                    } else {
                        primary += "X"
                        secondary += "X"
                    }
                    current += 2
                } else if stringAt(current, 3, ["SIO", "SIA"]) || stringAt(current, 4, ["SIAN"]) {
                    if !isSlavoGermanic() {
                        primary += "S"
                        secondary += "X"
                    } else {
                        primary += "S"
                        secondary += "S"
                    }
                    current += 3
                } else if (current == 0 && stringAt(current + 1, 1, ["M", "N", "L", "W"])) || stringAt(current + 1, 1, ["Z"]) {
                    primary += "S"
                    secondary += "X"
                    current += stringAt(current + 1, 1, ["Z"]) ? 2 : 1
                } else if stringAt(current, 2, ["SC"]) {
                    if charAt(current + 2) == "H" {
                        if stringAt(current + 3, 2, ["OO", "ER", "EN", "UY", "ED", "EM"]) {
                            if stringAt(current + 3, 2, ["ER", "EN"]) {
                                primary += "X"
                                secondary += "SK"
                            } else {
                                primary += "SK"
                                secondary += "SK"
                            }
                            current += 3
                        } else {
                            if current == 0 && !isVowel(charAt(3)) && charAt(3) != "W" {
                                primary += "X"
                                secondary += "S"
                            } else {
                                primary += "X"
                                secondary += "X"
                            }
                            current += 3
                        }
                    } else if stringAt(current + 2, 1, ["I", "E", "Y"]) {
                        primary += "S"
                        secondary += "S"
                        current += 3
                    } else {
                        primary += "SK"
                        secondary += "SK"
                        current += 3
                    }
                } else {
                    if current == last && stringAt(current - 2, 2, ["AI", "OI"]) {
                        primary += ""
                        secondary += "S"
                    } else {
                        primary += "S"
                        secondary += "S"
                    }
                    current += stringAt(current + 1, 1, ["S", "Z"]) ? 2 : 1
                }

            case "T":
                if stringAt(current, 4, ["TION"]) {
                    primary += "X"
                    secondary += "X"
                    current += 3
                } else if stringAt(current, 3, ["TIA", "TCH"]) {
                    primary += "X"
                    secondary += "X"
                    current += 3
                } else if stringAt(current, 2, ["TH"]) || stringAt(current, 3, ["TTH"]) {
                    if stringAt(current + 2, 2, ["OM", "AM"]) || stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"]) {
                        primary += "T"
                        secondary += "T"
                    } else {
                        primary += "0"  // Using '0' to represent 'TH' sound
                        secondary += "T"
                    }
                    current += 2
                } else {
                    primary += "T"
                    secondary += "T"
                    current += stringAt(current + 1, 1, ["T", "D"]) ? 2 : 1
                }

            case "V":
                primary += "F"
                secondary += "F"
                current += (charAt(current + 1) == "V") ? 2 : 1

            case "W":
                if stringAt(current, 2, ["WR"]) {
                    primary += "R"
                    secondary += "R"
                    current += 2
                } else if current == 0 && (isVowel(charAt(current + 1)) || stringAt(current, 2, ["WH"])) {
                    if isVowel(charAt(current + 1)) {
                        primary += "A"
                        secondary += "F"
                    } else {
                        primary += "A"
                        secondary += "A"
                    }
                    current += 1
                } else if (current == last && isVowel(charAt(current - 1))) ||
                          stringAt(current - 1, 5, ["EWSKI", "EWSKY", "OWSKI", "OWSKY"]) ||
                          stringAt(0, 3, ["SCH"]) {
                    primary += ""
                    secondary += "F"
                    current += 1
                } else if stringAt(current, 4, ["WICZ", "WITZ"]) {
                    primary += "TS"
                    secondary += "FX"
                    current += 4
                } else {
                    current += 1
                }

            case "X":
                if !(current == last && (stringAt(current - 3, 3, ["IAU", "EAU"]) || stringAt(current - 2, 2, ["AU", "OU"]))) {
                    primary += "KS"
                    secondary += "KS"
                }
                current += stringAt(current + 1, 1, ["C", "X"]) ? 2 : 1

            case "Z":
                if charAt(current + 1) == "H" {
                    primary += "J"
                    secondary += "J"
                    current += 2
                } else {
                    if stringAt(current + 1, 2, ["ZO", "ZI", "ZA"]) ||
                        (isSlavoGermanic() && (current > 0 && charAt(current - 1) != "T")) {
                        primary += "S"
                        secondary += "TS"
                    } else {
                        primary += "S"
                        secondary += "S"
                    }
                    current += (charAt(current + 1) == "Z") ? 2 : 1
                }

            default:
                current += 1
            }
        }

        // Truncate to max length
        if primary.count > maxLength {
            primary = String(primary.prefix(maxLength))
        }
        if secondary.count > maxLength {
            secondary = String(secondary.prefix(maxLength))
        }

        let primaryResult = primary.isEmpty ? nil : primary
        let secondaryResult = secondary.isEmpty ? nil : (secondary == primary ? nil : secondary)

        return (primaryResult, secondaryResult)
    }
}
