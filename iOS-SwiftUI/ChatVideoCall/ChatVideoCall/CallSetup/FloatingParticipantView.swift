//
//  FloatingParticipantView.swift
//  VideoConferencingSwiftUI
//
//  Created by amos.gyamfi@getstream.io on 18.9.2023.
//

import Foundation
import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

struct FloatingParticipantView: View {

    var participant: CallParticipant?
    var size: CGSize = .init(width: 140, height: 180)

    var body: some View {
        if let participant = participant {
            VStack {
                HStack {
                    Spacer()

                    VideoRendererView(id: participant.id, size: size) { videoRenderer in
                        videoRenderer.handleViewRendering(for: participant, onTrackSizeUpdate: { _, _ in })
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .frame(width: size.width, height: size.height)
                }
                Spacer()
            }
            .padding()
        }
    }
}
