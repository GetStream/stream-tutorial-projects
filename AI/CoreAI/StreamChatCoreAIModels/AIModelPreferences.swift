// AIModelPreferences.swift
// User-selectable AI models for the chat app, persisted across launches:
//
//   * Speech-to-text  — SpeechAnalyzer (Apple, default) and Whisper
//                       large-v3-turbo (Core AI export).
//   * Text refinement — Apple Intelligence / Foundation Models (default) or a
//                       Core AI zoo LanguageBundle (Qwen3.5, LFM2.5, Granite).
//   * Vision (VQA)    — MiniCPM-V 4.6 (Core AI export): attach a photo, ask
//                       about it, and the answer streams into the chat.
//
// Every non-default model here has a prebuilt Core AI `.aimodel` export hosted
// on Hugging Face, so it installs in-app with a single Get tap (see
// `CoreAIModelDownload` + `ModelDownloader`).

import Foundation
import Observation

// MARK: - Downloadable Core AI exports

/// A ready-made Core AI export hosted on Hugging Face that the app can
/// download in place of a manual Mac-side export.
struct CoreAIModelDownload: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// A single directory inside the repo (e.g. an `.aimodel` folder).
        case subtree(remotePath: String)
        /// Several directories inside the repo, each installed side by side
        /// under the destination using its last path component as the name
        /// (e.g. a VLM's decoder + vision-encoder bundles).
        case subtrees(remotePaths: [String])
        /// Selected paths at the repo root, kept together as one folder
        /// (e.g. a full diffusion pipeline export).
        case repoRoot(prefixes: [String])
    }

    /// Hugging Face repo, `org/name`.
    let repo: String
    let kind: Kind
    /// Name of the folder created under the destination directory.
    let localName: String
    let approximateSize: String
}

enum CoreAIModelStore {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where downloaded / dropped ASR `.aimodel` exports live.
    static var asrDirectory: URL {
        documentsDirectory.appendingPathComponent("models/asr")
    }

    /// Where downloaded vision-language `.aimodel` bundles live.
    static var visionDirectory: URL {
        documentsDirectory.appendingPathComponent("models/vlm")
    }
}

// MARK: - Speech to text

enum SpeechToTextModel: String, CaseIterable, Identifiable, Sendable {
    case speechAnalyzer = "speech-analyzer"
    case whisperLargeV3Turbo = "whisper-large-v3-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .speechAnalyzer: "SpeechAnalyzer"
        case .whisperLargeV3Turbo: "Whisper large-v3-turbo"
        }
    }

    var detail: String {
        switch self {
        case .speechAnalyzer:
            "Apple's on-device Speech framework with the default SpeechTranscriber model. Live streaming results."
        case .whisperLargeV3Turbo:
            "OpenAI Whisper via Apple's Core AI export recipe (809M). Records, then transcribes."
        }
    }

    var badge: String {
        switch self {
        case .speechAnalyzer: "Default"
        case .whisperLargeV3Turbo: "809M"
        }
    }

    /// File-name prefix of the exported `.aimodel` bundle.
    var exportFilePrefix: String? {
        switch self {
        case .speechAnalyzer: nil
        case .whisperLargeV3Turbo: "whisper-large-v3-turbo"
        }
    }

    /// In-app download for this engine, when a prebuilt Core AI export is
    /// hosted on Hugging Face.
    var download: CoreAIModelDownload? {
        switch self {
        case .whisperLargeV3Turbo:
            // The repo folder is named `.aimodel`, but its contents are an AOT-compiled
            // bundle (main-h18p.mlirb + MPSGraph delegates), so it must be installed
            // under a `.aimodelc` name for Core AI to load it.
            CoreAIModelDownload(
                repo: "mlboydaisuke/whisper-large-v3-turbo-CoreAI-official",
                kind: .subtree(
                    remotePath: "ios/whisper-large-v3-turbo_float16_fixed128.aimodel"
                ),
                localName: "whisper-large-v3-turbo_float16_fixed128.h18p.aimodelc",
                approximateSize: "3.2 GB"
            )
        case .speechAnalyzer:
            nil
        }
    }

    /// True when the engine can run right now (SpeechAnalyzer is always
    /// available; Core AI engines need their export installed).
    var isInstalled: Bool {
        if self == .speechAnalyzer { return true }
        return installedModelURL != nil
    }

    /// Locates the installed `.aimodel` / `.aimodelc` export for this engine,
    /// searching `Documents/models/asr/` and the Documents root (Finder drops).
    var installedModelURL: URL? {
        guard let prefix = exportFilePrefix else { return nil }
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let searchDirs = [docs.appendingPathComponent("models/asr"), docs]
        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            if let match = entries.first(where: {
                $0.lastPathComponent.hasPrefix(prefix)
                    && ($0.pathExtension == "aimodel" || $0.pathExtension == "aimodelc")
            }) {
                return match
            }
        }
        return nil
    }

    /// Repairs a mislabeled Whisper install. The Hugging Face repo ships the iOS
    /// bundle under an `.aimodel` folder name even though it is AOT-compiled (its
    /// graph is `main-h18p.mlirb`; there is no JIT `main.mlirb`), so Core AI
    /// refuses to load it until the folder carries a `.aimodelc` extension.
    /// Renames any such already-downloaded bundle in place, avoiding a 3.2 GB
    /// re-download.
    static func repairMislabeledWhisperInstall() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for dir in [docs.appendingPathComponent("models/asr"), docs] {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries where entry.lastPathComponent.hasPrefix("whisper-large-v3-turbo")
                && entry.pathExtension == "aimodel" {
                let isJIT = fm.fileExists(atPath: entry.appendingPathComponent("main.mlirb").path)
                let isAOT = fm.fileExists(atPath: entry.appendingPathComponent("main-h18p.mlirb").path)
                guard !isJIT, isAOT else { continue }
                let baseName = entry.deletingPathExtension().lastPathComponent
                let fixed = dir.appendingPathComponent("\(baseName).h18p.aimodelc")
                try? fm.removeItem(at: fixed)
                try? fm.moveItem(at: entry, to: fixed)
            }
        }
    }
}

// MARK: - Vision language (photo Q&A)

enum VisionLanguageModel: String, CaseIterable, Identifiable, Sendable {
    case miniCPMV46 = "minicpm-v-4-6"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .miniCPMV46: "MiniCPM-V 4.6"
        }
    }

    var badge: String {
        switch self {
        case .miniCPMV46: "1.3B"
        }
    }

    var detail: String {
        switch self {
        case .miniCPMV46:
            "OpenBMB MiniCPM-V 4.6 vision-language model (Core AI zoo export). "
                + "Attach a photo, ask about it, and the answer streams into the chat — fully on-device."
        }
    }

    /// Decoder LanguageBundle directory name (as installed on device).
    var decoderBundleName: String {
        switch self {
        case .miniCPMV46: "minicpmv46_vlm_decode_int8hu"
        }
    }

    /// Vision-encoder directory name; contains `<name>.aimodel`.
    var visionDirectoryName: String {
        switch self {
        case .miniCPMV46: "minicpmv46_vision_int8lin"
        }
    }

    /// In-app download of the prebuilt Core AI bundles hosted on Hugging Face.
    var download: CoreAIModelDownload? {
        switch self {
        case .miniCPMV46:
            CoreAIModelDownload(
                repo: "mlboydaisuke/MiniCPM-V-4.6-CoreAI",
                kind: .subtrees(remotePaths: [
                    "gpu-pipelined/minicpmv46_vlm_decode_int8hu",
                    "gpu-pipelined/minicpmv46_vision_int8lin"
                ]),
                localName: decoderBundleName,
                approximateSize: "2.0 GB"
            )
        }
    }

    var isInstalled: Bool {
        decoderBundleURL != nil && visionModelURL != nil
    }

    /// Installed decoder LanguageBundle directory, if present.
    var decoderBundleURL: URL? {
        locate(directory: decoderBundleName)
    }

    /// Installed vision-encoder `.aimodel`, if present.
    var visionModelURL: URL? {
        guard let dir = locate(directory: visionDirectoryName) else { return nil }
        let url = dir.appendingPathComponent("\(visionDirectoryName).aimodel")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Searches `Documents/models/vlm/` and the Documents root (Finder drops).
    private func locate(directory name: String) -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for dir in [CoreAIModelStore.visionDirectory, docs] {
            let candidate = dir.appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - Preferences store

/// App-wide model selection, persisted in UserDefaults. Views observe it to
/// react when the user switches models in the settings sheet.
@MainActor
@Observable
final class AIModelPreferences {
    static let shared = AIModelPreferences()

    /// Bumped by the settings screen after installs may have changed.
    var installVersion = 0

    var speechModel: SpeechToTextModel {
        didSet {
            UserDefaults.standard.set(speechModel.rawValue, forKey: Self.speechKey)
        }
    }

    var textModel: ChatModelChoice {
        didSet {
            UserDefaults.standard.set(textModel.id, forKey: Self.textKey)
        }
    }

    var visionModel: VisionLanguageModel {
        didSet {
            UserDefaults.standard.set(visionModel.rawValue, forKey: Self.visionKey)
        }
    }

    private static let speechKey = "coreai.chat.speechModel"
    private static let textKey = "coreai.chat.textModel"
    private static let visionKey = "coreai.chat.visionModel"

    private init() {
        let defaults = UserDefaults.standard
        speechModel = defaults.string(forKey: Self.speechKey)
            .flatMap(SpeechToTextModel.init(rawValue:)) ?? .speechAnalyzer
        visionModel = defaults.string(forKey: Self.visionKey)
            .flatMap(VisionLanguageModel.init(rawValue:)) ?? .miniCPMV46
        let savedTextID = defaults.string(forKey: Self.textKey)
        textModel = Self.textChoices.first { $0.id == savedTextID } ?? .appleFoundationModel
    }

    /// All selectable text-refinement models: Apple Intelligence plus the
    /// Core AI zoo language bundles.
    static var textChoices: [ChatModelChoice] {
        [.appleFoundationModel] + ZooModelCatalog.all.map { .zoo($0) }
    }
}
