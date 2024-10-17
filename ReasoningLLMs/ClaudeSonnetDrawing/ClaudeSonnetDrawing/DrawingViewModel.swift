import PencilKit
import SwiftUI

class DrawingViewModel: ObservableObject {
    @Published var canvasView = PKCanvasView()
    @Published var selectedTool: DrawingTool = .pencil
    @Published var selectedColor: Color = .black
    @Published var lineWidth: CGFloat = 5

    private var undoManager: UndoManager?

    init() {
        setupCanvasView()
    }

    private func setupCanvasView() {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
        canvasView.drawingPolicy = .anyInput
    }

    func updateTool() {
        let color = UIColor(selectedColor)

        switch selectedTool {
        case .pencil:
            canvasView.tool = PKInkingTool(.pencil, color: color, width: lineWidth)
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: color, width: lineWidth)
        case .monoline:
            canvasView.tool = PKInkingTool(.monoline, color: color, width: lineWidth)
        case .fountain:
            canvasView.tool = PKInkingTool(.fountainPen, color: color, width: lineWidth)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: color, width: lineWidth)
        case .crayon:
            canvasView.tool = PKInkingTool(.crayon, color: color, width: lineWidth)
        case .watercolor:
            canvasView.tool = PKInkingTool(.watercolor, color: color, width: lineWidth)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        case .ruler:
            // Implement ruler functionality
            break
        }
    }

    func undo() {
        canvasView.undoManager?.undo()
    }

    func redo() {
        canvasView.undoManager?.redo()
    }

    func clearCanvas() {
        canvasView.drawing = PKDrawing()
    }

    func cutDrawing() {
        // Implement cut drawing functionality
    }
}

enum DrawingTool: String, CaseIterable {
    case pencil, pen, monoline, fountain, marker, crayon, watercolor, eraser, ruler
}
