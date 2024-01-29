//
//  FaceBoardApp.swift
//  FaceBoard
//

import SwiftUI
import StreamVideo
import StreamVideoSwiftUI

@main
struct FaceBoardApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                CallContainerSetup()
                FreeFormDrawingView(viewModel: CallViewModel())
            }
        }
    }
}
