import PencilKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DrawingViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                DrawingCanvasView(canvasView: $viewModel.canvasView)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    ToolbarView(viewModel: viewModel)
                }
            }
            .navigationTitle("Drawing App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.clearCanvas) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
