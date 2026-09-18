import StreamVideo
import StreamVideoSwiftUI
import SwiftUI

/// Renders the local participant's camera track edge-to-edge using the Stream
/// Video renderer. Observes `CallState` directly so the view updates the moment
/// the track is published.
struct LocalCameraView: View {
    let call: Call
    let size: CGSize
    let isCameraOn: Bool

    @ObservedObject private var state: CallState

    init(call: Call, size: CGSize, isCameraOn: Bool) {
        self.call = call
        self.size = size
        self.isCameraOn = isCameraOn
        _state = ObservedObject(wrappedValue: call.state)
    }

    var body: some View {
        ZStack {
            if isCameraOn, let participant = state.localParticipant, participant.track != nil {
                VideoRendererView(
                    id: "\(participant.id)-live",
                    size: size,
                    contentMode: .scaleAspectFill
                ) { renderer in
                    renderer.handleViewRendering(for: participant) { _, _ in }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            } else {
                AuroraBackground()
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: isCameraOn ? "camera.aperture" : "video.slash.fill")
                                .font(.system(size: 34, weight: .medium))
                                .symbolEffect(.pulse, isActive: isCameraOn)
                            Text(isCameraOn ? "Starting camera…" : "Camera is off")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Aurora.textSecondary)
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: 0.3), value: isCameraOn)
    }
}
