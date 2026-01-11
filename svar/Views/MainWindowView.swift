//
//  MainWindowView.swift
//  svar
//

import SwiftUI

// MARK: - Navigation

enum NavItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case personalize = "Personalize"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .personalize: return "person.text.rectangle"
        case .settings: return "slider.horizontal.3"
        case .about: return "sparkles"
        }
    }
}

// MARK: - Design System

struct SvarColors {
    // Dark backgrounds (black/near-black)
    static let background = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.12) // #1F1F1F
    static let sidebarBackground = Color(red: 0.06, green: 0.06, blue: 0.06) // #0F0F0F

    // Default macOS blue accent
    static let accent = Color.accentColor

    // Warning/Error colors
    static let warning = Color.red
}

// MARK: - Main Window

struct MainWindowView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var selectedNav: NavItem = .home

    var body: some View {
        VStack(spacing: 0) {
            // Setup checklist at top (shows until all setup is complete)
            if !permissionManager.allPermissionsGranted || !TranscriptionEngine.shared.isModelLoaded {
                SetupChecklist(selectedNav: $selectedNav)
                    .padding(12)

                Divider().opacity(0.5)
            }

            // Main content with sidebar
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(NavItem.allCases) { item in
                        Button {
                            selectedNav = item
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 14))
                                    .frame(width: 20)
                                Text(item.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedNav == item ? Color.primary.opacity(0.1) : Color.clear)
                            )
                            .foregroundColor(selectedNav == item ? .primary : .secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Recording status at bottom of sidebar
                    if appState.isRecording || appState.isTranscribing {
                        recordingStatus
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 8)
                .frame(width: 160)
                .background(SvarColors.sidebarBackground)

                // Divider
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)

                // Content area
                Group {
                    switch selectedNav {
                    case .home:
                        HistoryView()
                    case .personalize:
                        PersonalizeView()
                    case .settings:
                        SettingsDetailView()
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(SvarColors.background)
        .onAppear { handleOnAppear() }
    }

    private var recordingStatus: some View {
        HStack(spacing: 6) {
            if appState.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("Recording")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            } else if appState.isTranscribing {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Processing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(appState.isRecording ? Color.red.opacity(0.15) : Color.primary.opacity(0.05))
        )
    }

    private func handleOnAppear() {
        Task { @MainActor in
            if appState.shouldOpenHome {
                appState.shouldOpenHome = false
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// MARK: - Home View

struct HistoryView: View {
    @StateObject private var appState = AppState.shared
    @State private var copiedItemId: UUID?
    @State private var hoveredItemId: UUID?
    @State private var showAllTranscriptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Welcome Section
                welcomeSection

                // Stats Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Words Dictated")
                        .font(.system(size: 14, weight: .semibold))
                    statsCard
                }

                // History Card
                historyCard
            }
            .padding(20)
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.isFirstLaunch ? "Welcome" : "Welcome back")
                .font(.system(size: 24, weight: .bold))
            Text("Your voice-to-text assistant is ready")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            // Today
            StatItem(
                icon: "sun.max",
                value: formatNumber(appState.dailyWordsCount),
                label: "Today"
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 12)

            // This Week
            StatItem(
                icon: "calendar",
                value: formatNumber(appState.weeklyWordsCount),
                label: "This Week"
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 12)

            // This Month
            StatItem(
                icon: "calendar.badge.clock",
                value: formatNumber(appState.monthlyWordsCount),
                label: "This Month"
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 12)

            // All Time
            StatItem(
                icon: "infinity",
                value: formatNumber(appState.totalWordsCount),
                label: "All Time"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - History Card

    private var sortedHistory: [TranscriptionItem] {
        appState.transcriptionHistory.sorted { $0.timestamp > $1.timestamp }
    }

    private var displayedHistory: [TranscriptionItem] {
        if showAllTranscriptions {
            return sortedHistory
        } else {
            return Array(sortedHistory.prefix(5))
        }
    }

    private var hasMoreItems: Bool {
        sortedHistory.count > 5
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(showAllTranscriptions ? "All Transcriptions" : "Recent Transcriptions")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !appState.transcriptionHistory.isEmpty {
                    Button {
                        Task { @MainActor in
                            appState.transcriptionHistory.removeAll()
                            HistoryManager.shared.save(appState.transcriptionHistory)
                            showAllTranscriptions = false
                        }
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Content
            if appState.transcriptionHistory.isEmpty {
                emptyHistoryState
            } else {
                VStack(spacing: 8) {
                    ForEach(displayedHistory) { item in
                        TranscriptionRow(
                            item: item,
                            isCopied: copiedItemId == item.id,
                            isHovered: hoveredItemId == item.id,
                            onCopy: { copyToClipboard(item) },
                            onDelete: { deleteItem(item) },
                            onHover: { hovering in
                                hoveredItemId = hovering ? item.id : nil
                            }
                        )
                    }

                    // View All / Show Less button
                    if hasMoreItems {
                        Button {
                            showAllTranscriptions.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllTranscriptions ? "Show Less" : "View All (\(sortedHistory.count))")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: showAllTranscriptions ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(SvarColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var emptyHistoryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No transcriptions yet")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("Press your hotkey to start")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helper Functions

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000)
        }
        return "\(num)"
    }

    private func copyToClipboard(_ item: TranscriptionItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedItemId = item.id
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if copiedItemId == item.id {
                        copiedItemId = nil
                    }
                }
            }
        }
    }

    private func deleteItem(_ item: TranscriptionItem) {
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                if let index = appState.transcriptionHistory.firstIndex(where: { $0.id == item.id }) {
                    appState.transcriptionHistory.remove(at: index)
                    HistoryManager.shared.save(appState.transcriptionHistory)
                }
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(SvarColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Transcription Row

struct TranscriptionRow: View {
    let item: TranscriptionItem
    let isCopied: Bool
    let isHovered: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text(formatDuration(item.duration))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(isCopied ? .green : .secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
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
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isHovered ? 0.04 : 0.02))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Transcription Card

struct TranscriptionCard: View {
    let item: TranscriptionItem
    let isCopied: Bool
    let isHovered: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text content
            Text(item.text)
                .font(.system(size: 14))
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            // Metadata row
            HStack(spacing: 16) {
                // Time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)

                // Duration badge
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text(formatDuration(item.duration))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    // Expand/Collapse
                    if item.text.count > 150 {
                        ActionButton(
                            icon: isExpanded ? "chevron.up" : "chevron.down",
                            label: isExpanded ? "Less" : "More",
                            color: .secondary
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                    }

                    // Copy
                    ActionButton(
                        icon: isCopied ? "checkmark" : "doc.on.doc",
                        label: isCopied ? "Copied!" : "Copy",
                        color: isCopied ? .green : SvarColors.accent
                    ) {
                        onCopy()
                    }

                    // Delete
                    ActionButton(
                        icon: "trash",
                        label: nil,
                        color: .red.opacity(0.7)
                    ) {
                        onDelete()
                    }
                }
                .opacity(isHovered ? 1 : 0.6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.005 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String?
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(isHovered ? 0.15 : 0.1))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Settings View

struct SettingsDetailView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // General Section
                SettingsSection(title: "General", icon: "slider.horizontal.3") {
                    VStack(spacing: 20) {
                        // Hotkey
                        SettingsRow(title: "Hotkey", subtitle: "Trigger recording with a keyboard shortcut") {
                            HotkeyRecorderView()
                        }

                        Divider().opacity(0.5)

                        // Recording Mode
                        SettingsRow(title: "Recording Mode", subtitle: appState.recordingMode == .pushToTalk
                            ? "Hold to record, release to transcribe"
                            : "Press to start, press again to stop") {
                            Picker("", selection: $appState.recordingMode) {
                                ForEach(RecordingMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        Divider().opacity(0.5)

                        // Output Mode
                        SettingsRow(title: "Output", subtitle: "What happens after transcription") {
                            Picker("", selection: $appState.outputMode) {
                                ForEach(OutputMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .frame(width: 220)
                        }

                        Divider().opacity(0.5)

                        // Launch at Login
                        LaunchAtLoginRow()

                        Divider().opacity(0.5)

                        // Max History Items
                        SettingsRow(title: "History Limit", subtitle: "Maximum transcriptions to keep") {
                            Picker("", selection: $appState.maxHistoryItems) {
                                Text("10").tag(10)
                                Text("50").tag(50)
                                Text("100").tag(100)
                            }
                            .frame(width: 100)
                        }

                        Divider().opacity(0.5)

                        // Dictation Indicator
                        SettingsRow(title: "Dictation Indicator", subtitle: "Show floating bar while recording") {
                            Toggle("", isOn: $appState.showDictationIndicator)
                                .toggleStyle(.switch)
                        }
                    }
                }

                // Models Section
                SettingsSection(title: "Models", icon: "cpu") {
                    VStack(spacing: 12) {
                        ForEach(ParakeetModel.allCases, id: \.self) { model in
                            ModelCard(model: model)
                        }
                    }
                }

                #if DEBUG
                // Debug Section
                SettingsSection(title: "Debug", icon: "hammer") {
                    Button("Reset All App Data") {
                        resetAllAppData()
                    }
                    .foregroundColor(.red)
                }
                #endif
            }
            .padding(24)
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
        .onChange(of: appState.recordingMode) { _, _ in
            Task { @MainActor in appState.saveSettings() }
        }
        .onChange(of: appState.outputMode) { _, _ in
            Task { @MainActor in appState.saveSettings() }
        }
        .onChange(of: appState.maxHistoryItems) { _, newValue in
            Task { @MainActor in
                appState.saveSettings()
                // Trim history if it exceeds the new limit
                if appState.transcriptionHistory.count > newValue {
                    appState.transcriptionHistory = Array(appState.transcriptionHistory.prefix(newValue))
                    HistoryManager.shared.save(appState.transcriptionHistory)
                }
            }
        }
        .onChange(of: appState.showDictationIndicator) { _, _ in
            Task { @MainActor in appState.saveSettings() }
        }
    }

    #if DEBUG
    private func resetAllAppData() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Clear transcription history
        HistoryManager.shared.clear()
        AppState.shared.transcriptionHistory = []

        // Reset word counts
        AppState.shared.dailyWordsCount = 0
        AppState.shared.weeklyWordsCount = 0
        AppState.shared.monthlyWordsCount = 0
        AppState.shared.totalWordsCount = 0

        // Reset hotkey to default (right Command)
        CustomHotkeyManager.shared.config = .default
        CustomHotkeyManager.shared.setupEventTap()

        // Note: Transcription model is NOT unloaded - only unloads on app quit
    }
    #endif
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SvarColors.accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Content

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            control
        }
    }
}

struct LaunchAtLoginRow: View {
    @State private var launchAtLogin = false

    var body: some View {
        SettingsRow(title: "Launch at Login", subtitle: "Start Svar when you log in") {
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    Task { @MainActor in
                        LaunchAtLoginManager.shared.setLaunchAtLogin(newValue)
                    }
                }
        }
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.shared.isLaunchAtLoginEnabled
        }
    }
}

struct ModelCard: View {
    let model: ParakeetModel
    @StateObject private var appState = AppState.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared
    @State private var isHovered = false

    private var isSelected: Bool { appState.selectedModel == model }
    private var isDownloaded: Bool { transcriptionEngine.isModelDownloaded(model) }
    private var isDownloading: Bool { transcriptionEngine.downloadingModel == model }
    private var isLoaded: Bool { transcriptionEngine.loadedModelVersion == model }

    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? SvarColors.accent : Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)

                if isSelected {
                    Circle()
                        .fill(SvarColors.accent)
                        .frame(width: 10, height: 10)
                }
            }

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .semibold))

                    if isLoaded {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.green.opacity(0.15))
                            )
                    }
                }

                Text(model.tagline)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status/Action
            if isDownloading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("\(Int(transcriptionEngine.downloadProgress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            } else {
                Button {
                    Task { @MainActor in
                        await transcriptionEngine.downloadModel(model, loadAfterDownload: isSelected)
                    }
                } label: {
                    Text("Download")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(SvarColors.accent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? SvarColors.accent.opacity(0.5) : Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Task { @MainActor in
                appState.selectedModel = model
                appState.saveSettings()
                if isDownloaded {
                    await transcriptionEngine.switchModel(model)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(SvarColors.accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 35)

                // App Icon (uses Icon Composer icon via system)
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
            }

            // App name and version
            VStack(spacing: 8) {
                Image("SvarLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Tagline
            Text("Voice-to-text, privately on your Mac")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            // Features
            HStack(spacing: 24) {
                AboutFeature(icon: "desktopcomputer", title: "On Device")
                AboutFeature(icon: "lock.shield.fill", title: "Private")
                AboutFeature(icon: "bolt.fill", title: "Fast")
                AboutFeature(icon: "globe", title: "Multilingual")
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            // Credits
            VStack(spacing: 3) {
                Text("Built with FluidAudio SDK")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Link(destination: URL(string: "https://x.com/rajatkapoor")!) {
                    Text("Made with ♥ by Rajat Kapoor")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct AboutFeature: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(SvarColors.accent)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Permissions Banner

struct SetupChecklist: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared
    @Binding var selectedNav: NavItem

    var body: some View {
        HStack(spacing: 12) {
            // Step 1: Microphone
            SetupStep(
                number: 1,
                title: "Microphone",
                description: "Record your voice",
                icon: "mic.fill",
                isComplete: permissionManager.hasMicrophonePermission,
                buttonTitle: "Grant Access",
                action: {
                    permissionManager.requestMicrophonePermission()
                }
            )

            // Step 2: Accessibility
            SetupStep(
                number: 2,
                title: "Accessibility",
                description: "Paste text & hotkeys",
                icon: "hand.tap.fill",
                isComplete: permissionManager.hasAccessibilityPermission,
                buttonTitle: "Open Settings",
                action: {
                    permissionManager.openAccessibilitySettings()
                }
            )

            // Step 3: Download Model
            SetupStep(
                number: 3,
                title: "Download Model",
                description: "AI speech recognition",
                icon: "arrow.down.circle.fill",
                isComplete: transcriptionEngine.isModelLoaded,
                buttonTitle: "Select Model",
                action: {
                    selectedNav = .settings
                }
            )
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let isComplete: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Icon or checkmark
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.2) : Color.primary.opacity(0.08))
                    .frame(width: 40, height: 40)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(SvarColors.accent)
                }
            }

            // Title and description
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isComplete ? Color.primary.opacity(0.5) : Color.primary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Action button or Done - same height for both states
            if !isComplete {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(SvarColors.accent)
                        )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("Complete")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SvarColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isComplete ? Color.green.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
