//
//  AudioRecorder.swift
//  svar
//

import AVFoundation
import Combine
import AppKit
import CoreAudio

@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var recordingStartTime: Date?
    private var tapInstalled = false
    private var bufferCount = 0

    private let targetSampleRate: Double = 16000 // Parakeet requirement

    private init() {}

    func startRecording() throws {
        guard !isRecording else { return }
        guard PermissionManager.shared.hasMicrophonePermission else {
            throw RecordingError.noMicrophonePermission
        }

        audioBuffer = []
        recordingStartTime = Date()
        bufferCount = 0

        // Create fresh audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecordingError.engineInitFailed
        }

        let inputNode = audioEngine.inputNode

        // Set the selected input device if specified
        let selectedUID = AppState.shared.selectedMicrophoneUID
        if !selectedUID.isEmpty {
            if let deviceID = AudioDeviceManager.shared.getDeviceID(for: selectedUID) {
                do {
                    try AudioDeviceManager.shared.setInputDevice(deviceID, for: audioEngine)
                    print("[AudioRecorder] Set input device to: \(selectedUID)")
                } catch {
                    print("[AudioRecorder] Failed to set input device: \(error). Using default.")
                }
            } else {
                print("[AudioRecorder] Device not found for UID: \(selectedUID), using default")
            }
        } else {
            print("[AudioRecorder] Using system default input device")
        }

        // Get the native format from the input node
        // Use nil format in installTap to let the system use the native format
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        print("[AudioRecorder] Native format: \(nativeFormat.sampleRate) Hz, \(nativeFormat.channelCount) ch, \(nativeFormat.commonFormat.rawValue)")

        // Validate the format
        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            print("[AudioRecorder] Invalid native format!")
            throw RecordingError.formatError
        }

        // Create target format for Parakeet (16kHz mono Float32)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecordingError.formatError
        }

        // Create converter
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            print("[AudioRecorder] Failed to create converter from \(nativeFormat) to \(targetFormat)")
            throw RecordingError.converterError
        }
        print("[AudioRecorder] Converter created successfully")

        // Install tap with the native format
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, time in
            self?.processAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }
        tapInstalled = true

        do {
            try audioEngine.start()
            print("[AudioRecorder] Audio engine started")
        } catch {
            print("[AudioRecorder] Failed to start engine: \(error)")
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
            throw RecordingError.engineInitFailed
        }

        isRecording = true
        AppState.shared.isRecording = true
    }

    func stopRecording() -> (samples: [Float], duration: TimeInterval)? {
        guard isRecording else { return nil }

        print("[AudioRecorder] Stopping recording. Buffers received: \(bufferCount), samples: \(audioBuffer.count)")

        audioEngine?.stop()
        if tapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine = nil
        isRecording = false

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let samples = audioBuffer
        audioBuffer = []

        AppState.shared.isRecording = false

        print("[AudioRecorder] Recording stopped. Duration: \(duration)s, samples: \(samples.count)")
        return (samples: samples, duration: duration)
    }

    private func processAudio(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        bufferCount += 1

        // Log first few buffers for debugging
        if bufferCount <= 3 {
            print("[AudioRecorder] Buffer #\(bufferCount): \(buffer.frameLength) frames at \(buffer.format.sampleRate) Hz")
        }

        guard buffer.frameLength > 0 else {
            print("[AudioRecorder] Empty buffer received")
            return
        }

        // Calculate output frame count based on sample rate conversion
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard frameCount > 0 else {
            print("[AudioRecorder] Invalid frame count: \(frameCount)")
            return
        }

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            print("[AudioRecorder] Failed to create converted buffer")
            return
        }

        var error: NSError?
        var inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("[AudioRecorder] Conversion error: \(error)")
            return
        }

        if status == .error {
            print("[AudioRecorder] Conversion failed with status: error")
            return
        }

        guard convertedBuffer.frameLength > 0 else {
            if bufferCount <= 3 {
                print("[AudioRecorder] Converted buffer is empty")
            }
            return
        }

        if let channelData = convertedBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))

            DispatchQueue.main.async { [weak self] in
                self?.audioBuffer.append(contentsOf: samples)

                // Calculate audio level for visualization
                if !samples.isEmpty {
                    let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                    self?.audioLevel = min(1.0, rms * 10)
                }
            }
        }
    }
}

enum RecordingError: LocalizedError {
    case noMicrophonePermission
    case engineInitFailed
    case formatError
    case converterError

    var errorDescription: String? {
        switch self {
        case .noMicrophonePermission:
            return "Microphone permission not granted"
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .formatError:
            return "Failed to create audio format"
        case .converterError:
            return "Failed to create audio converter"
        }
    }
}
