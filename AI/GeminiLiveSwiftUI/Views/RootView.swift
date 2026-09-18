import SwiftUI

/// Start screen -> full-screen live session. No Stream imports here; the
/// Video SDK is confined to `LiveView` / `LocalCameraView`, the AI components
/// to the caption strip and transcript sheet.
struct RootView: View {
    /// `--go-live` skips the start screen (handy for `simctl launch` testing).
    @State private var isLive = CommandLine.arguments.contains("--go-live")
    /// `--mode transcribe|liveThinking` picks the initial model (testing only).
    @State private var mode: GeminiLiveMode = {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--mode"), index + 1 < args.count else { return .live }
        return GeminiLiveMode(rawValue: args[index + 1]) ?? .live
    }()

    var body: some View {
        StartView(mode: $mode) { isLive = true }
            .fullScreenCover(isPresented: $isLive) {
                LiveView(initialMode: mode) { isLive = false }
            }
    }
}
