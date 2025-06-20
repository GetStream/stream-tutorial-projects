import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

@main
struct LivestreamSampleApp: App {
    
    @State var streamVideo: StreamVideo
    @State var call: Call
    
    init() {
        let apiKey = "mmhfdzb5evj2"
        let userId = "Shmi_Skywalker"
        let userToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL3Byb250by5nZXRzdHJlYW0uaW8iLCJzdWIiOiJ1c2VyL1NobWlfU2t5d2Fsa2VyIiwidXNlcl9pZCI6IlNobWlfU2t5d2Fsa2VyIiwidmFsaWRpdHlfaW5fc2Vjb25kcyI6NjA0ODAwLCJpYXQiOjE3NTAzMzM4MjYsImV4cCI6MTc1MDkzODYyNn0.Bg0DhsEVqGVojjcoIBfxN9AMdFvoAKqNbWFfAzfKq64"
        let callId = "wXP5qZWcj5uf"
        
        let user = User(id: userId, name: "tutorial")
        
        let streamVideo = StreamVideo(
            apiKey: apiKey,
            user: user,
            token: .init(rawValue: userToken)
        )
        self.streamVideo = streamVideo
        let call = streamVideo.call(callType: "livestream", callId: callId)
        self.call = call
        Task {
            try await call.join(create: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            LivestreamView(call: call)
        }
    }
}

struct LivestreamView: View {
    
    @Injected(\.streamVideo) var streamVideo
    
    let call: Call
    
    @StateObject var state: CallState
    
    let formatter = DateComponentsFormatter()
    
    init(call: Call) {
        self.call = call
        _state = StateObject(wrappedValue: call.state)
        formatter.unitsStyle = .abbreviated
    }
    
    var duration: String? {
        guard call.state.duration > 0  else { return nil }
        return formatter.string(from: call.state.duration)
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { reader in
                if let first = state.participants.first {
                    
                    VideoRendererView(id: first.id, size: reader.size) { renderer in
                        renderer.handleViewRendering(for: first) { size, participant in }
                    }
                    .ignoresSafeArea()
                } else {
                    Color(UIColor.secondarySystemBackground)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let duration {
                        HStack {
                            Text("Live: \(duration)")
                                .bold()
                                .font(.headline)
                                .monospacedDigit()
                                .padding(.horizontal)
                            
                            Text("Live \(state.participantCount)")
                                .bold()
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(.red.gradient)
                                .opacity(call.state.backstage ? 0 : 1)
                                .padding(.horizontal)
                        }
                        .padding()
                        .glassEffect()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    ZStack {
                        if call.state.backstage {
                            Button {
                                Task {
                                    try await call.goLive()
                                }
                            } label: {
                                Image(systemName: "play.circle.fill")
                            }
                            .font(.system(size: 64))
                            .buttonStyle(.glass)
                            
                        } else {
                            Button {
                                Task {
                                    try await call.stopLive()
                                }
                            } label: {
                                Image(systemName: "pause.circle.fill")
                            }
                            .font(.system(size: 64))
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
    }
}
