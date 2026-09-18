import StreamVideo
import StreamVideoSwiftUI
import SwiftUI

@main
struct StreamLiveApp: App {
    @State private var streamVideo: StreamVideo
    @State private var streamVideoUI: StreamVideoUI

    init() {
        let user = User(
            id: StreamLiveConfig.userId,
            name: StreamLiveConfig.userName,
            imageURL: StreamLiveConfig.userImageURL,
            customData: [:]
        )
        let client = StreamVideo(
            apiKey: StreamLiveConfig.streamAPIKey,
            user: user,
            token: UserToken(rawValue: StreamLiveConfig.userToken)
        )
        _streamVideo = State(wrappedValue: client)
        _streamVideoUI = State(wrappedValue: StreamVideoUI(streamVideo: client))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Aurora.accent)
        }
    }
}
