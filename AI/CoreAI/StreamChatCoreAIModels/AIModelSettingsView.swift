#if os(iOS)
// AIModelSettingsView.swift
// Model picker sheet, opened from the trailing toolbar button on the
// messages screen. Three sections:
//
//   * Speech to text  — SpeechAnalyzer (default) or Whisper large-v3-turbo,
//                       downloadable in-app from Hugging Face.
//   * Text refinement — Apple Intelligence (default) or Core AI zoo language
//                       bundles, downloadable in-app from Hugging Face.
//   * Vision (photo Q&A) — MiniCPM-V 4.6, downloadable in-app from Hugging
//                       Face. Attach a photo, ask, stream the answer.
//
// Every non-default model has a prebuilt Core AI export hosted on Hugging
// Face, so a single Get tap downloads and installs it on device.

import SwiftUI

struct AIModelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferences = AIModelPreferences.shared
    @State private var downloader = ModelDownloader()
    /// id of the ASR / image model currently downloading (zoo text models
    /// report through `downloader.activeModelID` instead).
    @State private var activeDownloadID: String?

    var body: some View {
        NavigationStack {
            List {
                if case .failed(let message) = downloader.phase {
                    Section {
                        Label {
                            Text("Download failed: \(message)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                speechSection
                textSection
                visionSection
            }
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Speech to text

    private var speechSection: some View {
        Section {
            ForEach(SpeechToTextModel.allCases) { model in
                HStack(spacing: 10) {
                    Button {
                        preferences.speechModel = model
                    } label: {
                        modelRow(
                            title: model.displayName,
                            badge: model.badge,
                            detail: model.detail,
                            isSelected: preferences.speechModel == model,
                            isInstalled: model.isInstalled
                        )
                    }
                    .buttonStyle(.plain)

                    if !model.isInstalled, let download = model.download {
                        downloadAccessory(
                            id: model.id,
                            download: download,
                            destination: CoreAIModelStore.asrDirectory
                        )
                    }
                }
            }
        } header: {
            Text("Speech to Text (ASR)")
        } footer: {
            Text("SpeechAnalyzer streams text live while you speak. Whisper downloads its Core AI model, then records a clip and transcribes when you stop.")
        }
    }

    // MARK: - Text refinement

    private var textSection: some View {
        Section {
            ForEach(AIModelPreferences.textChoices) { choice in
                textModelRow(choice)
            }
        } header: {
            Text("Text Refinement & Style")
        } footer: {
            Text("Used by the Refine, Summarize, Grammar, and Style buttons above the composer. Zoo models download from Hugging Face and run fully on-device.")
        }
    }

    @ViewBuilder
    private func textModelRow(_ choice: ChatModelChoice) -> some View {
        let installed = isTextModelInstalled(choice)
        HStack(spacing: 10) {
            Button {
                preferences.textModel = choice
            } label: {
                modelRow(
                    title: choice.displayName,
                    badge: badge(for: choice),
                    detail: detail(for: choice),
                    isSelected: preferences.textModel == choice,
                    isInstalled: installed
                )
            }
            .buttonStyle(.plain)

            if case .zoo(let zoo) = choice, !installed {
                if downloader.busy, downloader.activeModelID == zoo.id {
                    downloadProgress
                } else {
                    getButton {
                        Task {
                            await downloader.fetch(model: zoo)
                            preferences.installVersion += 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Download accessory (ASR + diffusion exports)

    @ViewBuilder
    private func downloadAccessory(
        id: String,
        download: CoreAIModelDownload,
        destination: URL
    ) -> some View {
        if downloader.busy, activeDownloadID == id {
            downloadProgress
        } else {
            getButton {
                Task {
                    activeDownloadID = id
                    defer { activeDownloadID = nil }
                    switch download.kind {
                    case .subtree(let remotePath):
                        await downloader.fetch(
                            repo: download.repo,
                            items: [.init(remote: remotePath, local: download.localName)],
                            into: destination
                        )
                    case .subtrees(let remotePaths):
                        await downloader.fetch(
                            repo: download.repo,
                            items: remotePaths.map {
                                .init(remote: $0, local: ($0 as NSString).lastPathComponent)
                            },
                            into: destination
                        )
                    case .repoRoot(let prefixes):
                        await downloader.fetchBundleRoot(
                            repo: download.repo,
                            local: download.localName,
                            including: prefixes,
                            into: destination
                        )
                    }
                    preferences.installVersion += 1
                }
            }
        }
    }

    // NOTE: must be `.plain` — in a List row that contains more than one
    // button, only plain/borderless buttons receive their own taps. With
    // `.buttonStyle(.glass)` the List swallowed the tap and the row's
    // selection button fired instead. The glass look is applied manually.
    private func getButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Get", systemImage: "arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(downloader.busy)
    }

    private var downloadProgress: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ProgressView(value: downloader.fraction)
                .frame(width: 72)
            Text(downloader.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func isTextModelInstalled(_ choice: ChatModelChoice) -> Bool {
        _ = preferences.installVersion
        switch choice {
        case .appleFoundationModel: return true
        case .zoo(let zoo): return ZooModelCatalog.isInstalled(zoo)
        }
    }

    private func badge(for choice: ChatModelChoice) -> String {
        switch choice {
        case .appleFoundationModel: "Default"
        case .zoo(let zoo): zoo.approximateSize
        }
    }

    private func detail(for choice: ChatModelChoice) -> String {
        switch choice {
        case .appleFoundationModel:
            "Apple Intelligence Foundation Models. On-device, instant, private."
        case .zoo(let zoo):
            zoo.detail
        }
    }

    // MARK: - Vision (photo Q&A)

    private var visionSection: some View {
        Section {
            ForEach(VisionLanguageModel.allCases) { model in
                HStack(spacing: 10) {
                    Button {
                        preferences.visionModel = model
                    } label: {
                        modelRow(
                            title: model.displayName,
                            badge: model.badge,
                            detail: model.detail,
                            isSelected: preferences.visionModel == model,
                            isInstalled: isVisionModelInstalled(model)
                        )
                    }
                    .buttonStyle(.plain)

                    if !isVisionModelInstalled(model), let download = model.download {
                        downloadAccessory(
                            id: model.id,
                            download: download,
                            destination: CoreAIModelStore.visionDirectory
                        )
                    }
                }
            }
        } header: {
            Text("Vision — Ask About Photos")
        } footer: {
            Text("Attach a photo from your library, type a question, and send. MiniCPM-V looks at the photo on-device and streams its answer into the chat. Downloads its Core AI bundles on first Get.")
        }
    }

    private func isVisionModelInstalled(_ model: VisionLanguageModel) -> Bool {
        _ = preferences.installVersion
        return model.isInstalled
    }

    // MARK: - Shared row

    private func modelRow(
        title: String,
        badge: String,
        detail: String,
        isSelected: Bool,
        isInstalled: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                    if !isInstalled {
                        Text("Not installed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
#endif
