import SwiftUI

/// Landing screen: the Aurora orb, a one-line pitch, model picker and Go Live.
struct StartView: View {
    @Binding var mode: GeminiLiveMode
    let onStart: () -> Void

    private var hasGeminiKey: Bool { !StreamLiveConfig.geminiAPIKey.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                AuroraOrb(size: 132)

                Text("Stream Live")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .foregroundStyle(Aurora.textPrimary)

                Text("Point your camera at anything and talk. Gemini sees what you see, answers out loud, and captions the conversation in real time.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Aurora.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                modePicker

                Button(action: onStart) {
                    Label("Go live", systemImage: "waveform.and.mic")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.plain)
                .auroraGlassCapsule(tint: Aurora.periwinkle600.opacity(0.9), interactive: true)
                .disabled(!hasGeminiKey)

                if !hasGeminiKey {
                    Label("Add GEMINI_API_KEY to ~/.zprofile and regenerate Secrets.swift", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(Aurora.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                    Text("Camera + mic by Stream Video")
                    Text("·")
                    Image(systemName: "sparkles")
                    Text("Voice by Gemini")
                }
                .font(.caption2)
                .foregroundStyle(Aurora.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuroraBackground().ignoresSafeArea())
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(GeminiLiveMode.allCases) { candidate in
                Button {
                    withAnimation(.snappy) { mode = candidate }
                } label: {
                    Label(candidate.shortTitle, systemImage: candidate.symbol)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(mode == candidate ? Aurora.indigo900 : Aurora.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity)
                        .background {
                            if mode == candidate {
                                Capsule().fill(.white.opacity(0.55))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .auroraGlassCapsule()
        .accessibilityLabel("Gemini model: \(mode.title)")
    }
}

#Preview {
    StartView(mode: .constant(.live)) {}
}
