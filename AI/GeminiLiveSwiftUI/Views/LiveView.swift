import Combine
import StreamVideo
import StreamVideoSwiftUI
import SwiftUI

/// The live screen: Stream Video camera feed edge-to-edge, Liquid Glass chrome
/// on top (mode menu, captions, Mute / Video / Transcript), Gemini in the loop.
struct LiveView: View {
    let onClose: () -> Void

    @StateObject private var callViewModel: CallViewModel
    @StateObject private var live: LiveSessionViewModel
    @State private var callId = StreamLiveConfig.makeCallId()
    @State private var hasJoined = false

    init(initialMode: GeminiLiveMode, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _callViewModel = StateObject(wrappedValue: CallViewModel(
            callSettings: CallSettings(audioOn: true, videoOn: true, speakerOn: true, cameraPosition: .back)
        ))
        let live = LiveSessionViewModel()
        live.mode = initialMode
        _live = StateObject(wrappedValue: live)
    }

    private var isCameraOn: Bool { callViewModel.callSettings.videoOn }
    private var isMuted: Bool { !callViewModel.callSettings.audioOn }

    var body: some View {
        chrome
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Camera + scrims live in the background so they fill the whole
            // screen while the chrome stays inside the safe area.
            .background {
                GeometryReader { proxy in
                    ZStack {
                        cameraLayer(size: proxy.size)
                        scrims
                    }
                }
                .ignoresSafeArea()
            }
            .preferredColorScheme(.dark)
            .onAppear(perform: joinIfNeeded)
            .onDisappear(perform: teardown)
            // `CallViewModel` publishes `.inCall` a beat before it assigns `call`,
            // so key off the call itself: it is only set once the join succeeded.
            .onReceive(callViewModel.$call.compactMap { $0 }) { call in
                live.attach(call: call)
            }
        .onReceive(callViewModel.$callSettings) { settings in
            live.micStateChanged(isOn: settings.audioOn)
            live.cameraStateChanged(isOn: settings.videoOn)
        }
        .sheet(isPresented: $live.isTranscriptPresented) {
            TranscriptSheet(model: live)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Call error",
            isPresented: Binding(
                get: { callViewModel.error != nil },
                set: { if !$0 { callViewModel.error = nil } }
            )
        ) {
            Button("OK") { callViewModel.error = nil }
        } message: {
            Text(callViewModel.error?.localizedDescription ?? "Unknown error")
        }
    }

    // MARK: Layers

    @ViewBuilder
    private func cameraLayer(size: CGSize) -> some View {
        if let call = callViewModel.call {
            LocalCameraView(call: call, size: size, isCameraOn: isCameraOn)
        } else {
            AuroraBackground()
                .overlay {
                    VStack(spacing: 12) {
                        ProgressView().tint(Aurora.textPrimary)
                        Text("Joining Stream call…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Aurora.textSecondary)
                    }
                }
        }
    }

    /// Soft scrims so the glass chrome reads over any camera image; the bottom
    /// one carries the Aurora periwinkle glow from the reference art.
    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Aurora.indigo900.opacity(0.35), location: 0.45),
                    .init(color: Aurora.periwinkle600.opacity(0.75), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .allowsHitTesting(false)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 6)
                .padding(.horizontal, 16)

            Spacer(minLength: 0)

            interruptPill
                .padding(.bottom, 14)

            LiveCaptionStrip(model: live)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            LiveControlsBar(
                isMuted: isMuted,
                isCameraOn: isCameraOn,
                transcriptCount: live.transcript.count,
                onToggleMute: { callViewModel.toggleMicrophoneEnabled() },
                onToggleCamera: { callViewModel.toggleCameraEnabled() },
                onFlipCamera: { Task { try? await callViewModel.call?.camera.flip() } },
                onTranscript: { live.isTranscriptPresented = true }
            )
            .padding(.bottom, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture { live.interrupt() }
        .overlay(alignment: .top) { toast.padding(.top, 58) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            modeMenu
            Spacer()
            settingsMenu
            GlassIconButton(systemName: "xmark", size: 42, accessibilityLabel: "End live session") {
                teardown()
                onClose()
            }
        }
    }

    private var modeMenu: some View {
        Menu {
            Picker("Model", selection: Binding(get: { live.mode }, set: { live.switchMode($0) })) {
                ForEach(GeminiLiveMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 8) {
                AuroraOrb(size: 22)
                Text(live.mode.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Aurora.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Aurora.textSecondary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 42)
        }
        .auroraGlassCapsule(interactive: true)
        .accessibilityLabel("Gemini model: \(live.mode.title). Tap to change.")
    }

    private var settingsMenu: some View {
        Menu {
            Toggle(isOn: $live.allowsVoiceInterruptions) {
                Label("Voice interruptions", systemImage: "waveform.badge.mic")
            }
            Button {
                Task { try? await callViewModel.call?.camera.flip() }
            } label: {
                Label("Flip camera", systemImage: "arrow.triangle.2.circlepath.camera")
            }
            Divider()
            Button(role: .destructive) {
                live.clearTranscript()
            } label: {
                Label("Clear transcript", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Aurora.textPrimary)
                .frame(width: 42, height: 42)
        }
        .auroraGlassCircle(interactive: true)
        .accessibilityLabel("Session options")
    }

    // MARK: Center + toast

    @ViewBuilder
    private var interruptPill: some View {
        if live.isModelSpeaking {
            Text("Tap to interrupt")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Aurora.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .auroraGlassCapsule(tint: Aurora.periwinkle600.opacity(0.25))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = live.toast {
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Aurora.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .auroraGlassCapsule()
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { live.toast = nil }
                }
        }
    }

    // MARK: Lifecycle

    private func joinIfNeeded() {
        guard !hasJoined else { return }
        hasJoined = true
        callViewModel.joinCall(callType: StreamLiveConfig.callType, callId: callId)
    }

    private func teardown() {
        live.stop()
        if callViewModel.callingState != .idle {
            callViewModel.hangUp()
        }
    }
}
