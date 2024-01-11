//
//  ParticipantsView.swift

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct ParticipantsView: View {

    var call: Call
    var participants: [CallParticipant]
    var onChangeTrackVisibility: (CallParticipant?, Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            if !participants.isEmpty {
                ScrollView {
                    LazyVStack {
                        if participants.count == 1, let participant = participants.first {
                            makeCallParticipantView(participant, frame: proxy.frame(in: .global))
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        } else {
                            ForEach(participants) { participant in
                                makeCallParticipantView(participant, frame: proxy.frame(in: .global))
                                    .frame(width: proxy.size.width, height: proxy.size.height / 2)
                            }
                        }
                    }
                }
            } else {
                Color.black
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func makeCallParticipantView(_ participant: CallParticipant, frame: CGRect) -> some View {
        VideoCallParticipantView(
            participant: participant,
            availableFrame: frame,
            contentMode: .scaleAspectFit,
            customData: [:],
            call: call
        )
        .onAppear { onChangeTrackVisibility(participant, true) }
        .onDisappear{ onChangeTrackVisibility(participant, false) }
    }
}
