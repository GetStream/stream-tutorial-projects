import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var tool: PKTool
    @Binding var color: UIColor
    @Environment(\.undoManager) private var undoManager

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = tool
        canvas.alwaysBounceVertical = true

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        canvas.becomeFirstResponder()

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = tool
    }
}
