import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

class CustomViewFactory: ViewFactory {
    public func makeCallControlsView(viewModel: CallViewModel) -> some View {
        CallControlsView(viewModel: viewModel)
    }
}
