//
//  AppState.swift
//  swar
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscription: String?
    @Published var transcriptionHistory: [TranscriptionItem] = []
    @Published var selectedModel: ParakeetModel = .v2
    @Published var recordingMode: RecordingMode = .pushToTalk
    @Published var outputMode: OutputMode = .pasteAndClipboard
    @Published var isModelDownloaded = false
    @Published var modelDownloadProgress: Double = 0
    @Published var showPermissionsTab = false
    @Published var shouldOpenHome = false
    @Published var maxHistoryItems: Int = 50
    @Published var showDictationIndicator: Bool = true
    @Published var dictationIndicatorStyle: DictationIndicatorStyle = .floatingBar
    @Published var isFirstLaunch: Bool = true

    // Word count stats
    @Published var dailyWordsCount: Int = 0
    @Published var weeklyWordsCount: Int = 0
    @Published var monthlyWordsCount: Int = 0
    @Published var totalWordsCount: Int = 0

    private var lastDayTracked: Int = 0
    private var lastWeekTracked: Int = 0
    private var lastMonthTracked: Int = 0

    private init() {
        loadSettings()
        loadStats()
    }

    // Update word count asynchronously (doesn't block transcription)
    func updateWordCountAsync(newText: String) {
        Task.detached(priority: .background) {
            let wordCount = newText.split(separator: " ").count
            await MainActor.run {
                self.checkAndResetPeriods()
                self.dailyWordsCount += wordCount
                self.weeklyWordsCount += wordCount
                self.monthlyWordsCount += wordCount
                self.totalWordsCount += wordCount
                self.saveStats()
            }
        }
    }

    private func checkAndResetPeriods() {
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // Reset daily count if it's a new day
        if currentDay != lastDayTracked {
            dailyWordsCount = 0
            lastDayTracked = currentDay
        }

        // Reset weekly count if it's a new week
        if currentWeek != lastWeekTracked {
            weeklyWordsCount = 0
            lastWeekTracked = currentWeek
        }

        // Reset monthly count if it's a new month
        if currentMonth != lastMonthTracked {
            monthlyWordsCount = 0
            lastMonthTracked = currentMonth
        }
    }

    private func loadStats() {
        totalWordsCount = UserDefaults.standard.integer(forKey: "totalWordsCount")
        dailyWordsCount = UserDefaults.standard.integer(forKey: "dailyWordsCount")
        weeklyWordsCount = UserDefaults.standard.integer(forKey: "weeklyWordsCount")
        monthlyWordsCount = UserDefaults.standard.integer(forKey: "monthlyWordsCount")
        lastDayTracked = UserDefaults.standard.integer(forKey: "lastDayTracked")
        lastWeekTracked = UserDefaults.standard.integer(forKey: "lastWeekTracked")
        lastMonthTracked = UserDefaults.standard.integer(forKey: "lastMonthTracked")

        // Check if periods need resetting on app launch
        checkAndResetPeriods()
    }

    private func saveStats() {
        UserDefaults.standard.set(totalWordsCount, forKey: "totalWordsCount")
        UserDefaults.standard.set(dailyWordsCount, forKey: "dailyWordsCount")
        UserDefaults.standard.set(weeklyWordsCount, forKey: "weeklyWordsCount")
        UserDefaults.standard.set(monthlyWordsCount, forKey: "monthlyWordsCount")
        UserDefaults.standard.set(lastDayTracked, forKey: "lastDayTracked")
        UserDefaults.standard.set(lastWeekTracked, forKey: "lastWeekTracked")
        UserDefaults.standard.set(lastMonthTracked, forKey: "lastMonthTracked")
    }

    func loadSettings() {
        // Load from UserDefaults
        if let modeRaw = UserDefaults.standard.string(forKey: "recordingMode"),
           let mode = RecordingMode(rawValue: modeRaw) {
            recordingMode = mode
        }
        if let outputRaw = UserDefaults.standard.string(forKey: "outputMode"),
           let output = OutputMode(rawValue: outputRaw) {
            outputMode = output
        }
        if let modelRaw = UserDefaults.standard.string(forKey: "selectedModel"),
           let model = ParakeetModel(rawValue: modelRaw) {
            selectedModel = model
        }
        let savedMaxHistory = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        if savedMaxHistory > 0 {
            maxHistoryItems = savedMaxHistory
        }
        if UserDefaults.standard.object(forKey: "showDictationIndicator") != nil {
            showDictationIndicator = UserDefaults.standard.bool(forKey: "showDictationIndicator")
        }
        if let styleRaw = UserDefaults.standard.string(forKey: "dictationIndicatorStyle"),
           let style = DictationIndicatorStyle(rawValue: styleRaw) {
            dictationIndicatorStyle = style
        }

        // Check if this is first launch
        if UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            isFirstLaunch = false
        } else {
            isFirstLaunch = true
            // Mark as launched for next time
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(recordingMode.rawValue, forKey: "recordingMode")
        UserDefaults.standard.set(outputMode.rawValue, forKey: "outputMode")
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
        UserDefaults.standard.set(maxHistoryItems, forKey: "maxHistoryItems")
        UserDefaults.standard.set(showDictationIndicator, forKey: "showDictationIndicator")
        UserDefaults.standard.set(dictationIndicatorStyle.rawValue, forKey: "dictationIndicatorStyle")
    }
}

enum ParakeetModel: String, CaseIterable {
    case v2 = "v2"
    case v3 = "v3"

    var displayName: String {
        switch self {
        case .v2: return "Parakeet V2"
        case .v3: return "Parakeet V3"
        }
    }

    var tagline: String {
        switch self {
        case .v2: return "Best for English"
        case .v3: return "Best for Multilingual"
        }
    }

    var description: String {
        switch self {
        case .v2: return "Optimized for English transcription with fast performance"
        case .v3: return "Supports 25 European languages including English"
        }
    }
}

enum RecordingMode: String, CaseIterable {
    case pushToTalk = "pushToTalk"
    case toggle = "toggle"

    var displayName: String {
        switch self {
        case .pushToTalk: return "Push to Talk"
        case .toggle: return "Toggle"
        }
    }
}

enum OutputMode: String, CaseIterable {
    case paste = "paste"
    case clipboard = "clipboard"
    case pasteAndClipboard = "pasteAndClipboard"

    var displayName: String {
        switch self {
        case .paste: return "Paste to focused field"
        case .clipboard: return "Copy to clipboard only"
        case .pasteAndClipboard: return "Paste and copy to clipboard"
        }
    }
}

enum DictationIndicatorStyle: String, CaseIterable {
    case floatingBar = "floatingBar"

    var displayName: String {
        switch self {
        case .floatingBar: return "Floating Bar"
        }
    }
}

