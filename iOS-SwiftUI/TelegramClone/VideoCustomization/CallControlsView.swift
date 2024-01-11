//
//  MessengerControlsView.swift

import SwiftUI
import StreamVideoSwiftUI

struct CallControlsView: View {
    
    @ObservedObject var viewModel: CallViewModel
    @State private var longPressed = false
    let bottomBarHeights = stride(from: 0.1, through: 1.0, by: 0.1).map { PresentationDetent.fraction($0) }
    @State private var isShowingReactions = false
    @State private var isVideo = true
    @State private var isAudio = true
    @State private var isFront = true
    
    var body: some View {
        HStack(spacing: 32) {
            Button {
                viewModel.toggleCameraEnabled()
                isVideo.toggle()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: isVideo ? "video.fill" : "video.slash.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(height: 48)
                    
                    withAnimation {
                        Text(isVideo ? "Video on" : "Video off")
                            .font(.caption)
                            .contentTransition(.interpolate)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 54)
            
            Button {
                viewModel.toggleMicrophoneEnabled()
                isAudio.toggle()
            } label: {
                VStack(spacing: 6) {
                    //Image(systemName: isAudio ? "mic.fill" : "mic.slash.fill")
                    Image(systemName: isAudio ? "mic.fill" : "mic.slash.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(height: 48)
                    
                    withAnimation {
                        Text(isAudio ? "Mute" : "Unmute")
                            .font(.caption)
                            .monospacedDigit()
                            .contentTransition(.interpolate)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 48)
            
            Button {
                viewModel.toggleCameraPosition()
                isFront.toggle()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: isFront ? "camera.on.rectangle.fill" : "camera.metering.matrix")
                        .frame(height: 48)
                        .contentTransition(.interpolate)
                    
                    withAnimation {
                        Text(isFront ? "Front" : "Back")
                            .font(.caption)
                            .contentTransition(.interpolate)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 42)
            
            Button {
                isShowingReactions.toggle()
            } label: {
                VStack(spacing: 12) {
                    Text("🥰")
                        .font(.largeTitle)
                    Text("Reactions")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingReactions) {
                ReactionsView()
                //.presentationDetents([.fraction(0.25)])
                    .presentationDetents(Set(bottomBarHeights))
            }
            
            HangUpIconView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .padding(.bottom)
        .background(.quaternary)
    }
    
}

