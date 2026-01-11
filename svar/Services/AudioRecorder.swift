//
//  AudioRecorder.swift
//  swar
//

import AVFoundation
import Combine
import AppKit

@MainActor
class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var recordingStartTime: Date?

    private let targetSampleRate: Double = 16000 // Parakeet requirement

    private init() {}

    func startRecording() throws {
        guard !isRecording else { return }
        guard PermissionManager.shared.hasMicrophonePermission else {
            throw RecordingError.noMicrophonePermission
        }

        audioBuffer = []
        recordingStartTime = Date()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecordingError.engineInitFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Convert to 16kHz mono for Parakeet
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecordingError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecordingError.converterError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }

        try audioEngine.start()
        isRecording = true

        // Update app state
        AppState.shared.isRecording = true
    }

    func stopRecording() -> (samples: [Float], duration: TimeInterval)? {
        guard isRecording else { return nil }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isRecording = false

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let samples = audioBuffer
        audioBuffer = []

        // Update app state
        AppState.shared.isRecording = false

        return (samples: samples, duration: duration)
    }

    private func processAudio(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / buffer.format.sampleRate)

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            return
        }

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let channelData = convertedBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))

            DispatchQueue.main.async { [weak self] in
                self?.audioBuffer.append(contentsOf: samples)

                // Calculate audio level for visualization
                let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                self?.audioLevel = min(1.0, rms * 10)
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
