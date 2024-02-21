import SwiftUI
import TipKit
import StreamChat
import StreamChatSwiftUI

@main
struct VoiceChatApp: App {
    
    // Step 1: Create an instance of the low-level `chatClient` for SwiftUI.
    var chatClient: ChatClient = {
        //For the tutorial we use a hard coded api key and application group identifier
        var config = ChatClientConfig(apiKey: .init("8br4watad788"))
        config.isLocalStorageEnabled = true
        config.applicationGroupIdentifier = "group.io.getstream.iOS.ChatDemoAppSwiftUI"
        
        // The resulting config is passed into a new `ChatClient` instance.
        let client = ChatClient(config: config)
        return client
    }()
    
    // Step 2: Create a `StreamChat` instance.
    @State var streamChat: StreamChat?
    
    // Step 5: Assign the voice recording feature to a Swift utility class. This means the voice recording is a secondary priority task compared to the actual use case of the app, rich text messaging.
    let recordingPossible = Utils(
        composerConfig: ComposerConfig(isVoiceRecordingEnabled: true)
    )
    
    // Step 4: Use an `init` method to set the `StreamChat` instance and the user.
    init() {
        streamChat = StreamChat(chatClient: chatClient, utils: recordingPossible)
        connectUser()
    }
    
    var body: some Scene {
        WindowGroup {
            ChatChannelListView(viewFactory: CustomFactory.shared)
                .task {
                    do {
                        try Tips.configure([
                            .displayFrequency(.immediate),
                            .datastoreLocation(.applicationDefault)
                        ])
                    } catch {
                        print(error.localizedDescription)
                    }
                }
        }
    }
    
    // Step 3: Connect a user to the backend.
    private func connectUser() {
        // This is a hardcoded token valid on Stream's tutorial environment.
        let token = try! Token(rawValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibHVrZV9za3l3YWxrZXIifQ.kFSLHRB5X62t0Zlc7nwczWUfsQMwfkpylC6jCUZ6Mc0")
        
        // Call `connectUser` on our SDK to get started.
        chatClient.connectUser(
            userInfo: .init(
                id: "luke_skywalker",
                name: "Luke Skywalker",
                imageURL: URL(string: "https://vignette.wikia.nocookie.net/starwars/images/2/20/LukeTLJ.jpg")!
            ),
            token: token
        ) { error in
            if let error = error {
                // Some very basic error handling only logging the error.
                log.error("connecting the user failed \(error)")
                return
            }
        }
    }
}
