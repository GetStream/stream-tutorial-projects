import StreamChatSwiftUI
import SwiftUI

class CustomFactory: ViewFactory {
    
    @Injected(\.chatClient) public var chatClient
    
    private init() {}
    
    public static let shared = CustomFactory()
    
    public func makeComposerRecordingTipView() -> some View {
        CustomRecordingTipView()
    }
}
