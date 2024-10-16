import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var tool: PKInkingTool?

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = tool ?? PKInkingTool(.pen, color: .black, width: 5)
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let tool = tool {
            uiView.tool = tool
        }
    }
}
