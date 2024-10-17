import PencilKit
import SwiftUI

struct ContentView: View {
    @State private var canvas = PKCanvasView()
    @State private var selectedToolType: PKInkingTool.InkType = .pencil
    @State private var selectedColor: UIColor = .black
    @State private var tool: PKTool = PKInkingTool(.pencil, color: .black)

    var body: some View {
        VStack {
            DrawingView(canvas: $canvas, tool: $tool, color: $selectedColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

            HStack {
                Button(action: {
                    selectedToolType = .pencil
                    tool = PKInkingTool(.pencil, color: selectedColor)
                }) {
                    Image(systemName: "pencil")
                }
                Button(action: {
                    selectedToolType = .pen
                    tool = PKInkingTool(.pen, color: selectedColor)
                }) {
                    Image(systemName: "pencil.tip")
                }
                Button(action: {
                    selectedToolType = .marker
                    tool = PKInkingTool(.marker, color: selectedColor)
                }) {
                    Image(systemName: "highlighter")
                }
                Button(action: {
                    selectedToolType = .crayon
                    tool = PKInkingTool(.crayon, color: selectedColor)
                }) {
                    Image(systemName: "scribble")
                }
                Button(action: {
                    selectedToolType = .watercolor
                    tool = PKInkingTool(.watercolor, color: selectedColor)
                }) {
                    Image(systemName: "paintbrush")
                }
                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: {
                            Color(selectedColor)
                        },
                        set: { newColor in
                            selectedColor = UIColor(newColor)
                            tool = PKInkingTool(selectedToolType, color: selectedColor)
                        }))
                Button(action: { canvas.undoManager?.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                Button(action: { canvas.undoManager?.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                Button(action: { canvas.tool = PKEraserTool(.bitmap) }) {
                    Image(systemName: "eraser")
                }
            }
            .padding()
        }
    }
}
