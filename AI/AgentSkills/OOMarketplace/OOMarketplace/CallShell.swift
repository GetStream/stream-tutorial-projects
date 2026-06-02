//
//  CallShell.swift
//  OOMarketplace
//
//  File isolation: imports StreamVideoSwiftUI for `CallModifier` / `CallViewModel`.
//  Listens for `AppEvents.startCall` posted by other (Chat / Discover / Listing) files
//  so those files do NOT need to import StreamVideo.
//

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct CallShell: View {
    @StateObject private var callViewModel = CallViewModel()
    @State private var pendingListingTitle: String?

    var body: some View {
        RootView()
            .modifier(CallModifier(viewModel: callViewModel))
            .onReceive(NotificationCenter.default.publisher(for: AppEvents.startCall)) { note in
                guard let request = note.object as? StartCallRequest else { return }
                start(request: request)
            }
            .onChange(of: callViewModel.error?.localizedDescription) { _, _ in
                if let apiError = callViewModel.error as? APIError {
                    print("[Video] APIError code=\(apiError.code) status=\(apiError.statusCode) message=\(apiError.message)")
                } else if let error = callViewModel.error {
                    print("[Video] Error: \(error)")
                }
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
                Text(callErrorMessage(callViewModel.error))
            }
    }

    private func callErrorMessage(_ error: Error?) -> String {
        guard let error else { return "Unknown error" }
        if let apiError = error as? APIError {
            return "\(apiError.message) (code \(apiError.code))"
        }
        return error.localizedDescription
    }

    // MARK: - Outgoing call orchestration

    /// Joins a fresh call immediately so the in-call UI renders without waiting on
    /// APNs / VoIP push. Ringing is intentionally disabled - it requires CallKit +
    /// APNs which aren't available on the simulator.
    private func start(request: StartCallRequest) {
        pendingListingTitle = request.listingTitle

        // Pre-toggle camera to match the audio/video intent. `toggleCameraEnabled()`
        // mutates `callSettings` directly while no call is active, so the lobby /
        // joining view shows the correct camera state from the first frame.
        if request.audioOnly, callViewModel.callSettings.videoOn {
            callViewModel.toggleCameraEnabled()
        } else if !request.audioOnly, !callViewModel.callSettings.videoOn {
            callViewModel.toggleCameraEnabled()
        }

        // Build the member list - the SDK auto-adds the current user. We add the
        // peer so they could join the same call ID from another device.
        let members = VideoService.members(from: [request.calleeId])

        callViewModel.startCall(
            callType: .default,
            callId: UUID().uuidString,
            members: members,
            ring: false
        )
    }
}
