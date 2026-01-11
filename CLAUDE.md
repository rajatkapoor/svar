# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Svar is a native macOS menu bar app for voice-to-text transcription using NVIDIA Parakeet models (V2/V3). All processing happens on-device via Apple Neural Engine - no data leaves the device. Apple Silicon only.

## Build Commands

```bash
# Build the app
xcodebuild -scheme svar -destination 'platform=macOS' build

# Build and run with permission reset (recommended for development)
./dev-run.sh

# Build release archive
xcodebuild -project svar.xcodeproj -scheme svar -configuration Release archive

# Clear icon cache (useful after icon changes)
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "/path/to/svar.app"
killall Dock && killall Finder
```

## Architecture

### App Structure
- **Menu bar app** using `MenuBarExtra` with a dropdown menu
- **Main window** (800x600) with left sidebar navigation (Home, Personalize, Settings, About)
- **Floating dictation indicator** - translucent pill at bottom of screen during recording
- **Dynamic Dock visibility** - appears in Dock/Cmd+Tab only when main window is open
- Uses SwiftUI with `@NSApplicationDelegateAdaptor` for AppDelegate integration

### Core Flow
1. User presses configurable hotkey (default: right Command)
2. `HotkeyManager` triggers `AudioRecorder` to start recording
3. `DictationIndicatorWindowController` shows floating indicator with waveform animation
4. On key release (push-to-talk) or second press (toggle mode), recording stops
5. Audio samples passed to `TranscriptionEngine` (FluidAudio SDK wrapper)
6. `VocabularyPostProcessor` applies custom word corrections
7. `TextInserter` pastes result into focused text field via CGEvent simulation
8. Word count stats updated (daily/weekly/monthly/total)
9. Transcription saved to history

### Key Singletons (all `@MainActor`)
- `AppState.shared` - Central state management, settings persistence via UserDefaults
- `AudioRecorder.shared` - AVAudioEngine-based recording at 16kHz for Parakeet compatibility
- `TranscriptionEngine.shared` - FluidAudio SDK integration, model download/loading
- `CustomHotkeyManager.shared` - CGEvent tap for global hotkey detection (supports single modifier keys like right Command)
- `HotkeyManager.shared` - Coordinates recording flow based on hotkey events
- `TextInserter.shared` - Text output via clipboard and CGEvent Cmd+V simulation
- `PermissionManager.shared` - Microphone and Accessibility permission management
- `HistoryManager.shared` - Transcription history persistence (configurable max items)
- `DictationIndicatorWindowController.shared` - Floating recording indicator window
- `VocabularyManager.shared` - Custom vocabulary/dictionary management
- `VocabularyPostProcessor.shared` - Applies vocabulary corrections to transcriptions
- `PhoneticMatcher.shared` - Phonetic matching for vocabulary corrections

### Dependencies (Swift Package Manager)
- **FluidAudio** - NVIDIA Parakeet model integration for on-device transcription
- **KeyboardShortcuts** - Hotkey recording UI (not used for actual hotkey detection)

### Required Permissions
- **Microphone** - For voice recording
- **Accessibility** - For CGEvent tap (global hotkey detection) and text pasting

### Entitlements
- App Sandbox disabled (required for CGEvent access)
- Bundle ID: `com.ubiqapps.svar`

## Features

### Recording Modes
- **Push to Talk** - Hold hotkey to record, release to transcribe
- **Toggle** - Press hotkey to start, press again to stop and transcribe

### Output Modes
- **Paste to focused field** - Pastes text and restores clipboard
- **Copy to clipboard only** - Just copies, shows notification
- **Paste and copy to clipboard** - Pastes and keeps in clipboard

### Dictation Indicator
- Floating translucent pill at bottom of screen (above Dock, at `.screenSaver` window level)
- Shows: red mic icon, animated waveform (recording) or spinner (transcribing), stop button
- Translucent border for visibility
- Stop button cancels recording without transcribing
- Can be enabled/disabled in settings

### Word Count Statistics
- Tracks words dictated: Today, This Week, This Month, All Time
- Automatically resets daily/weekly/monthly counts
- Displayed on Home screen

### Transcription History
- Shows recent transcriptions with timestamps and duration
- Home screen shows last 5 with "View All" option
- Configurable max history items (10, 50, 100) - default: 50
- Click to copy, swipe to delete
- Auto-trims when limit is reduced

### Smart Text Insertion
- `TextContextAnalyzer` detects cursor position and surrounding text
- Automatically adds leading space when needed
- Handles text selection replacement

### Custom Vocabulary (Personalize)
- User-configurable dictionary for word corrections
- Supports misspelling variants (e.g., "svar", "swar" → "Svar")
- Optional phonetic matching for sound-alike corrections
- Managed via VocabularyManager with persistent storage

### Setup Checklist
- Horizontal card layout showing setup progress
- Three steps: Permissions, Model Download, Hotkey Configuration
- Automatically hides when all setup is complete

### Dynamic Dock/Cmd+Tab Visibility
- App uses `.accessory` activation policy by default (menu bar only)
- Switches to `.regular` when main window opens (shows in Dock/Cmd+Tab)
- Switches back to `.accessory` when main window closes

### First Launch Detection
- Shows "Welcome" on first launch, "Welcome back" on subsequent launches
- Tracked via `hasLaunchedBefore` UserDefaults key

## File Organization

```
svar/
├── svarApp.swift              # App entry point, MenuBarExtra, AppDelegate, window observers
├── AppIcon.icon/              # Icon Composer icon (Xcode 15+)
│   ├── Assets/1024.png        # Source icon image
│   └── icon.json              # Icon Composer configuration
├── Assets.xcassets/
│   ├── AccentColor.colorset/  # Default macOS blue accent
│   ├── MenuBarIcon.imageset/  # Menu bar waveform icon
│   └── SvarLogo.imageset/     # App logo SVG
├── Models/
│   ├── AppState.swift         # Central state, enums, word count tracking, settings
│   ├── TranscriptionItem.swift
│   └── VocabularyEntry.swift  # Dictionary entry model
├── Services/
│   ├── AudioRecorder.swift       # AVAudioEngine → 16kHz Float32 samples
│   ├── TranscriptionEngine.swift # FluidAudio AsrManager wrapper
│   ├── TextInserter.swift        # CGEvent paste + smart spacing
│   ├── CustomHotkeyManager.swift # CGEvent tap for hotkey detection
│   ├── PermissionManager.swift
│   ├── TextContextAnalyzer.swift # Analyzes text field context for smart spacing
│   ├── VocabularyPostProcessor.swift # Applies vocabulary corrections
│   └── PhoneticMatcher.swift     # Sound-alike matching algorithm
├── Managers/
│   ├── HotkeyManager.swift       # Coordinates record→transcribe→paste flow
│   ├── HistoryManager.swift      # Transcription history persistence
│   ├── LaunchAtLoginManager.swift
│   └── VocabularyManager.swift   # Dictionary CRUD operations
└── Views/
    ├── MenuBarView.swift         # Menu bar dropdown (Home, model selection, quit)
    ├── MainWindowView.swift      # Main window with sidebar, SetupChecklist, all pages
    ├── PersonalizeView.swift     # Dictionary/vocabulary management UI
    ├── SettingsView.swift        # Settings sections (General, Models, Permissions)
    ├── AddVocabularySheet.swift  # Add/edit vocabulary entry modal
    ├── HotkeyRecorderView.swift  # Hotkey configuration UI
    ├── DictationIndicatorWindow.swift # Floating recording indicator
    └── OnboardingView.swift      # (Legacy - not currently used)
```

## Settings (UserDefaults)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `recordingMode` | String | "pushToTalk" | "pushToTalk" or "toggle" |
| `outputMode` | String | "pasteAndClipboard" | "paste", "clipboard", or "pasteAndClipboard" |
| `selectedModel` | String | "v2" | "v2" or "v3" |
| `maxHistoryItems` | Int | 50 | Max transcriptions to store (10, 50, or 100) |
| `showDictationIndicator` | Bool | true | Show floating indicator during recording |
| `dictationIndicatorStyle` | String | "floatingBar" | Indicator style |
| `hotkeyConfig` | Data | - | Encoded HotkeyConfig struct |
| `transcriptionHistory` | Data | - | Encoded [TranscriptionItem] array |
| `totalWordsCount` | Int | 0 | All-time word count |
| `dailyWordsCount` | Int | 0 | Today's word count |
| `weeklyWordsCount` | Int | 0 | This week's word count |
| `monthlyWordsCount` | Int | 0 | This month's word count |
| `lastDayTracked` | Int | - | Day of year for reset detection |
| `lastWeekTracked` | Int | - | Week number for reset detection |
| `lastMonthTracked` | Int | - | Month number for reset detection |
| `customVocabulary` | Data | - | Encoded vocabulary entries |
| `hasLaunchedBefore` | Bool | false | First launch detection |

## UI Design

### Color Scheme (SvarColors)
- `background` - Dark background (#141414)
- `cardBackground` - Card background (#1F1F1F)
- `sidebarBackground` - Sidebar background (#0F0F0F)
- `accent` - Default macOS blue (Color.accentColor)
- `warning` - Red for errors/warnings

### Main Window
- Size: 800x600 (min)
- Window style: `.titleBar` with `.contentSize` resizability
- **Sidebar**: Home, Personalize, Settings, About navigation
- **Home**: Welcome message, word count stats card, recent transcriptions (last 5)
- **Personalize**: Custom dictionary management with table view
- **Settings**:
  - General: Recording mode, output mode, hotkey, history limit, dictation indicator toggle
  - Models: Download/select Parakeet V2 or V3
  - Permissions: Microphone and Accessibility status with deep links
- **About**: App icon, version, tagline, 4 feature highlights (horizontal), credits with link

### Dictation Indicator (NSPanel)
- Floating window at `.screenSaver` level (appears above Dock)
- Positioned 50px from bottom center of screen's visible frame
- Translucent background (30% black opacity) with white border
- Contains: red mic icon, animated waveform/spinner, stop button
- Shows during recording and transcribing states

### App Icon
- Uses Xcode Icon Composer format (`AppIcon.icon`)
- Blue gradient background with black waveform
- Automatically generates all required sizes
- Proper macOS sizing with padding for Dock/Cmd+Tab display

## Models

### Parakeet V2
- Optimized for English transcription
- Fast performance (~110x realtime on M4 Pro)
- Default model

### Parakeet V3
- Supports 25 European languages including English
- Same performance as V2

## Unused/Legacy Files

- `svar/Views/OnboardingView.swift` - Legacy onboarding view, replaced by SetupChecklist in MainWindowView
- `thoughts/shared/plans/` - Planning documents from development

## Development Notes

### Icon Changes
When updating the app icon:
1. Use Xcode's Icon Composer to create/edit `AppIcon.icon`
2. Place at same level as `Assets.xcassets` (not inside it)
3. Remove any old `AppIcon.appiconset` from Assets.xcassets to avoid conflicts
4. Don't manually set `NSApp.applicationIconImage` - let the system use Icon Composer output
5. Clear icon cache after changes: `lsregister -f` + restart Dock/Finder

### Window Visibility
The app dynamically switches between `.accessory` and `.regular` activation policies to control Dock/Cmd+Tab visibility. This is handled in AppDelegate's window observers.
