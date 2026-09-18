import SwiftUI

/// The Gemini-Live-style bottom bar: Mute · Video · Transcript as Liquid Glass
/// circles with captions underneath.
struct LiveControlsBar: View {
    let isMuted: Bool
    let isCameraOn: Bool
    let transcriptCount: Int
    let onToggleMute: () -> Void
    let onToggleCamera: () -> Void
    let onFlipCamera: () -> Void
    let onTranscript: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 28) {
            HStack(alignment: .top, spacing: 28) {
                control(
                    title: isMuted ? "Unmute" : "Mute",
                    systemName: isMuted ? "mic.slash.fill" : "mic.fill",
                    tint: isMuted ? Aurora.haloRose.opacity(0.45) : nil,
                    action: onToggleMute
                )

                Menu {
                    Button(action: onFlipCamera) {
                        Label("Flip camera", systemImage: "arrow.triangle.2.circlepath.camera")
                    }
                    Button(action: onToggleCamera) {
                        Label(isCameraOn ? "Turn camera off" : "Turn camera on",
                              systemImage: isCameraOn ? "video.slash" : "video")
                    }
                } label: {
                    controlLabel(
                        title: "Video",
                        systemName: isCameraOn ? "video.fill" : "video.slash.fill",
                        tint: isCameraOn ? nil : Aurora.haloRose.opacity(0.45)
                    )
                } primaryAction: {
                    onFlipCamera()
                }

                control(
                    title: "Transcript",
                    systemName: "text.alignleft",
                    badge: transcriptCount,
                    action: onTranscript
                )
            }
        }
    }

    private func control(
        title: String,
        systemName: String,
        tint: Color? = nil,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            controlLabel(title: title, systemName: systemName, tint: tint, badge: badge)
        }
        .buttonStyle(.plain)
    }

    private func controlLabel(title: String, systemName: String, tint: Color? = nil, badge: Int = 0) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Aurora.textPrimary)
                .frame(width: 66, height: 66)
                .glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Aurora.indigo900)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(.white.opacity(0.9), in: Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
                .contentTransition(.symbolEffect(.replace))

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Aurora.textPrimary)
        }
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
