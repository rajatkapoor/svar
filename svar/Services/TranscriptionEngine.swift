//
//  TranscriptionEngine.swift
//  swar
//

import Foundation
import Combine
import FluidAudio

@MainActor
class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()

    @Published var isModelLoaded = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var isTranscribing = false
    @Published var loadedModelVersion: ParakeetModel?

    private var asrManager: AsrManager?

    private let downloadedModelsKey = "downloadedModels"
    @Published var downloadingModel: ParakeetModel?

    private init() {}

    /// Get all downloaded models
    var downloadedModels: Set<ParakeetModel> {
        guard let savedModels = UserDefaults.standard.stringArray(forKey: downloadedModelsKey) else {
            return []
        }
        return Set(savedModels.compactMap { ParakeetModel(rawValue: $0) })
    }

    /// Mark a model as downloaded
    private func markModelAsDownloaded(_ model: ParakeetModel) {
        var models = downloadedModels
        models.insert(model)
        UserDefaults.standard.set(models.map { $0.rawValue }, forKey: downloadedModelsKey)
    }

    /// Check if a specific model is downloaded
    func isModelDownloaded(_ model: ParakeetModel) -> Bool {
        return downloadedModels.contains(model)
    }

    /// Check if a model was previously downloaded and load it automatically
    func initializeOnStartup() async {
        // Load the user's selected model if it's downloaded
        let selectedModel = AppState.shared.selectedModel
        if isModelDownloaded(selectedModel) {
            await loadModelIfExists(selectedModel)
        } else {
            // Try to load any downloaded model
            if let anyDownloaded = downloadedModels.first {
                await loadModelIfExists(anyDownloaded)
            }
        }
    }

    /// Try to load model if it exists on disk (without downloading)
    func loadModelIfExists(_ model: ParakeetModel) async {
        guard !isModelLoaded && !isDownloading else { return }

        do {
            let version: AsrModelVersion = model == .v2 ? .v2 : .v3

            // downloadAndLoad will check if model exists and skip download
            // This is fast if model is already cached
            let models = try await AsrModels.downloadAndLoad(version: version)

            asrManager = AsrManager(config: .default)
            try await asrManager?.initialize(models: models)

            loadedModelVersion = model
            isModelLoaded = true
            AppState.shared.isModelDownloaded = true
            AppState.shared.selectedModel = model

            print("Model \(model.displayName) loaded successfully")
        } catch {
            print("Failed to load model: \(error)")
            // Model probably doesn't exist, user needs to download it
        }
    }

    func downloadModel(_ model: ParakeetModel, loadAfterDownload: Bool = true) async {
        guard !isDownloading else { return }

        isDownloading = true
        downloadingModel = model
        downloadProgress = 0

        do {
            let version: AsrModelVersion = model == .v2 ? .v2 : .v3
            let models = try await AsrModels.downloadAndLoad(version: version)

            // Mark as downloaded
            markModelAsDownloaded(model)

            if loadAfterDownload {
                asrManager = AsrManager(config: .default)
                try await asrManager?.initialize(models: models)

                loadedModelVersion = model
                isModelLoaded = true
                AppState.shared.isModelDownloaded = true
            }

            isDownloading = false
            downloadingModel = nil
            downloadProgress = 1.0

            print("Model \(model.displayName) downloaded\(loadAfterDownload ? " and loaded" : "")")
        } catch {
            print("Failed to download model: \(error)")
            isDownloading = false
            downloadingModel = nil
            downloadProgress = 0
        }
    }

    /// Switch to a different model (if already downloaded)
    func switchModel(_ model: ParakeetModel) async {
        // If switching to same model, do nothing
        if loadedModelVersion == model && isModelLoaded {
            return
        }

        // Unload current model
        unloadModel()

        // Try to load the new model
        await loadModelIfExists(model)

        // If model wasn't loaded (not downloaded), user needs to download it
        if !isModelLoaded {
            print("Model \(model.displayName) not found, needs download")
        }
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let asrManager = asrManager, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        isTranscribing = true
        AppState.shared.isTranscribing = true

        defer {
            isTranscribing = false
            Task { @MainActor in
                AppState.shared.isTranscribing = false
            }
        }

        let result = try await asrManager.transcribe(samples, source: .system)
        return result.text
    }

    func unloadModel() {
        asrManager?.cleanup()
        asrManager = nil
        isModelLoaded = false
        loadedModelVersion = nil
        AppState.shared.isModelDownloaded = false
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model not loaded. Please download a model first."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
