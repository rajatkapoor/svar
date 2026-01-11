# Svar

**On-device voice-to-text for macOS, powered by NVIDIA Parakeet**

Svar is a native macOS menu bar app that transcribes your voice to text using NVIDIA's Parakeet speech recognition models. All processing happens locally on your Mac using Apple Neural Engine - your voice never leaves your device.

## Features

- **Fully On-Device** - No internet required, no data sent to servers
- **Private** - Your voice recordings stay on your Mac
- **Fast** - ~110x realtime transcription on Apple Silicon
- **Multilingual** - Supports 25 European languages (Parakeet V3)

### How It Works

1. Press a hotkey (default: Right Command)
2. Speak
3. Release the hotkey
4. Text appears in your focused application

### Additional Features

- **Custom Dictionary** - Add words the transcription often gets wrong
- **Multiple Recording Modes** - Push-to-talk or toggle mode
- **Flexible Output** - Paste directly, copy to clipboard, or both
- **Transcription History** - View and copy past transcriptions
- **Word Count Stats** - Track your daily, weekly, monthly, and all-time dictation

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- ~1GB disk space for models
- ~800MB RAM during transcription

## Installation

### Download and Install

1. Download `Svar-x.x.zip` from the [latest release](https://github.com/rajatkapoor/svar/releases)
2. Double-click to unzip
3. Drag `Svar.app` to your **Applications** folder
4. Right-click on `Svar.app` and select **Open** (required for first launch since the app is not notarized)
5. Click **Open** in the security dialog

### Grant Permissions

Svar requires two permissions to work:

**Microphone Access:**
1. When prompted, click **OK** to allow microphone access
2. Or manually enable in **System Settings → Privacy & Security → Microphone → Svar**

**Accessibility Access:**
1. Svar will prompt you to grant Accessibility access
2. Click **Open System Settings** (or go to **System Settings → Privacy & Security → Accessibility**)
3. Click the **+** button and add Svar from your Applications folder
4. Enable the toggle next to Svar
5. You may need to restart Svar after granting this permission

### First-Time Setup

1. Open the main window by clicking the Svar icon in your menu bar and selecting **Open Svar**
2. Follow the setup checklist:
   - ✅ Grant permissions (as above)
   - ✅ Download a model (V2 for English, V3 for multilingual)
   - ✅ Configure your hotkey (default: right Command key)
3. Start dictating!

## Building from Source

### Prerequisites

- Xcode 15 or later
- macOS 14.0 or later

### Build

```bash
# Clone the repository
git clone https://github.com/rajatkapoor/svar.git
cd svar

# Build
xcodebuild -scheme svar -destination 'platform=macOS' build

# Or open in Xcode
open svar.xcodeproj
```

### Development

Open in Xcode and CMd+r to run

## Models

Svar uses NVIDIA's Parakeet models via the [FluidAudio SDK](https://github.com/FluidInference/FluidAudio):

| Model           | Languages    | Best For                             |
| --------------- | ------------ | ------------------------------------ |
| **Parakeet V2** | English      | English-only transcription (default) |
| **Parakeet V3** | Multilingual | Multilingual transcription           |

Both models run entirely on-device using Apple Neural Engine.

## Permissions

Svar requires two permissions to function:

- **Microphone Access** - To record your voice
- **Accessibility Access** - To detect global hotkeys and paste text into other apps

These permissions are requested on first launch. You can manage them in System Settings → Privacy & Security.

## Privacy

Svar is designed with privacy as a core principle:

- All speech recognition happens on-device
- No audio or transcriptions are sent to any server
- No analytics or telemetry
- No account required

## Configuration

### Recording Modes

- **Push to Talk** - Hold the hotkey while speaking, release to transcribe
- **Toggle** - Press once to start recording, press again to stop and transcribe

### Output Modes

- **Paste to focused field** - Automatically pastes text where your cursor is
- **Copy to clipboard only** - Just copies to clipboard
- **Paste and copy** - Does both

### Custom Dictionary

Add words that transcription often gets wrong in the Personalize tab. You can specify:

- The correct word
- Common misspellings/variants
- Enable phonetic matching for sound-alike corrections

## Troubleshooting

### App doesn't respond to hotkey

- Check that Accessibility permission is granted in System Settings
- Try re-granting the permission by removing and re-adding Svar

### No transcription output

- Check that Microphone permission is granted
- Ensure a model is downloaded in Settings → Models
- Check that the recording indicator appears when you press the hotkey

### Text not pasting

- Ensure Accessibility permission is granted
- Some apps may block automated text insertion

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

[MIT License](LICENSE)

## Credits

- Built with [FluidAudio SDK](https://github.com/FluidInference/FluidAudio) for on-device transcription
- Uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for hotkey UI
- NVIDIA Parakeet models for speech recognition

## Author

Made with ♥ by [Rajat Kapoor](https://x.com/rajatkapoor)
