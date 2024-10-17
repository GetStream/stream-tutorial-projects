import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: DrawingViewModel
    @State private var showColorPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(DrawingTool.allCases, id: \.self) { tool in
                    Button(action: {
                        viewModel.selectedTool = tool
                        viewModel.updateTool()
                    }) {
                        Image(systemName: symbolForTool(tool))
                            .foregroundColor(viewModel.selectedTool == tool ? .blue : .primary)
                    }
                }

                Button(action: { showColorPicker.toggle() }) {
                    Image(systemName: "eyedropper")
                        .foregroundColor(.primary)
                }

                Button(action: viewModel.undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(.primary)
                }

                Button(action: viewModel.redo) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(.primary)
                }

                Button(action: viewModel.cutDrawing) {
                    Image(systemName: "scissors")
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(15)
        }
        .padding()
        .sheet(isPresented: $showColorPicker) {
            ColorPicker("Select Color", selection: $viewModel.selectedColor)
                .padding()
                .presentationDetents([.height(200)])
        }
    }

    func symbolForTool(_ tool: DrawingTool) -> String {
        switch tool {
        case .pencil: return "pencil"
        case .pen: return "pen"
        case .monoline: return "line.diagonal"
        case .fountain: return "fountain.pen"
        case .marker: return "highlighter"
        case .crayon: return "scribble"
        case .watercolor: return "paintbrush"
        case .eraser: return "eraser"
        case .ruler: return "ruler"
        }
    }
}
