//
//  CustomLivestreamPlayer.swift
//  LivestreamSample

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct CustomLivestreamPlayer: View {

    @Injected(\.streamVideo) var streamVideo

    @State var call: Call
    @ObservedObject var state: CallState

    public init(
        type: String,
        id: String
    ) {
        let call = InjectedValues[\.streamVideo].call(callType: type, callId: id)
        self.call = call
        _state = ObservedObject(wrappedValue: call.state)
    }

    public var body: some View {
        ZStack {
            GeometryReader { reader in
                if let participant = state.participants.first {
                    VideoCallParticipantView(
                        participant: participant,
                        availableFrame: reader.frame(in: .global),
                        contentMode: .scaleAspectFit,
                        customData: [:],
                        call: call
                    )
                } else {
                    Text("No livestream available")
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "eye")
                    Text("\(state.participantCount)")
                        .font(.headline)
                }
                .foregroundColor(Color.blue)
                .padding(.all, 8)
                .cornerRadius(8)
                .padding()
            }
        )
        .onAppear {
            Task {
                try await call.join(callSettings: CallSettings(audioOn: false, videoOn: false))
            }
        }
        .onDisappear {
            call.leave()
        }
    }
}
