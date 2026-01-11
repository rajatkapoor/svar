//
//  AudioDeviceManager.swift
//  svar
//

import CoreAudio
import AVFoundation
import Combine

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }

    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

@MainActor
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    @Published var inputDevices: [AudioDevice] = []
    @Published var defaultDeviceUID: String = ""

    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?

    private init() {
        refreshDevices()
        setupDeviceChangeListener()
    }

    /// Refresh the list of available input devices
    func refreshDevices() {
        inputDevices = getInputDevices()
        defaultDeviceUID = getDefaultInputDeviceUID()
    }

    /// Get all audio input devices (microphones)
    private func getInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // Get all audio devices
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        ) == noErr else { return devices }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        ) == noErr else { return devices }

        // Filter for input devices only
        for deviceID in deviceIDs {
            if let device = getInputDevice(for: deviceID) {
                devices.append(device)
            }
        }

        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Check if a device has input channels and return its info
    private func getInputDevice(for deviceID: AudioDeviceID) -> AudioDevice? {
        // Check if device has input channels
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var inputSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr else {
            return nil
        }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(inputSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &inputSize, bufferListPointer) == noErr else {
            return nil
        }

        let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self).pointee
        guard bufferList.mNumberBuffers > 0 else {
            return nil
        }

        // Get device name
        guard let name = getDeviceName(for: deviceID) else { return nil }

        // Get device UID
        guard let uid = getDeviceUID(for: deviceID) else { return nil }

        return AudioDevice(id: deviceID, name: name, uid: uid)
    }

    /// Get device name
    private func getDeviceName(for deviceID: AudioDeviceID) -> String? {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr else {
            return nil
        }

        return name as String
    }

    /// Get device UID
    private func getDeviceUID(for deviceID: AudioDeviceID) -> String? {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid) == noErr else {
            return nil
        }

        return uid as String
    }

    /// Get the default input device UID
    private func getDefaultInputDeviceUID() -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        ) == noErr else { return "" }

        return getDeviceUID(for: deviceID) ?? ""
    }

    /// Get AudioDeviceID from UID
    func getDeviceID(for uid: String) -> AudioDeviceID? {
        if uid.isEmpty {
            // Return default device
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceID: AudioDeviceID = 0
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

            guard AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &deviceID
            ) == noErr else { return nil }

            return deviceID
        }

        // Find device by UID
        return inputDevices.first { $0.uid == uid }?.id
    }

    /// Set specific input device for AVAudioEngine
    func setInputDevice(_ deviceID: AudioDeviceID, for engine: AVAudioEngine) throws {
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw AudioDeviceError.noAudioUnit
        }

        var deviceIDCopy = deviceID

        // First, try to set the device directly on the audio unit
        var status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            print("AudioUnitSetProperty failed with status: \(status)")
            throw AudioDeviceError.failedToSetDevice(status)
        }

        // Verify the device was set correctly
        var currentDevice: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        status = AudioUnitGetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &currentDevice,
            &propertySize
        )

        if status == noErr {
            print("Device set verification: requested=\(deviceID), current=\(currentDevice)")
        }
    }

    // MARK: - Device Change Listener

    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        propertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            propertyListenerBlock!
        )
    }

    private func removeDeviceChangeListener() {
        guard let listenerBlock = propertyListenerBlock else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
    }
}

enum AudioDeviceError: LocalizedError {
    case noAudioUnit
    case failedToSetDevice(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noAudioUnit:
            return "Audio unit not available"
        case .failedToSetDevice(let status):
            return "Failed to set audio device (error \(status))"
        }
    }
}
