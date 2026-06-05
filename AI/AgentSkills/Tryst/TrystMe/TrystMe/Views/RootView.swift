//
//  RootView.swift
//  TrystMe
//
//  ISOLATED Stream Video file (StreamVideo + StreamVideoSwiftUI only).
//  Owns the single CallViewModel for the whole session and applies CallModifier,
//  which renders incoming/outgoing/active call overlays automatically.
//  Outgoing calls are triggered through the neutral AppModel.pendingCall.
//

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var callViewModel = CallViewModel()

    var body: some View {
        MainTabView()
            .modifier(CallModifier(viewModel: callViewModel))
            .onChange(of: appModel.pendingCall) { _, request in
                guard let request else { return }
                start(request)
                appModel.pendingCall = nil
            }
            .alert(
                "Call Error",
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

    private func start(_ request: CallRequest) {
        let members = request.memberIds.map { Member(userId: $0) }
        callViewModel.startCall(
            callType: "default",
            callId: request.callId,
            members: members,
            ring: true,
            video: request.video
        )
    }
}
