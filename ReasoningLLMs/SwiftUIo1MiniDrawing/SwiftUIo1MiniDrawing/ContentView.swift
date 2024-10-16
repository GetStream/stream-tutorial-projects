//
//  ContentView.swift
//  SwiftUIo1MiniDrawing
//
//  Created by Amos Gyamfi on 14.10.2024.
//

import SwiftUI
import PencilKit

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @State private var selectedTool: DrawingTool = .pencil
    @State private var selectedColor: Color = .black

    var body: some View {
        VStack {
            DrawingCanvasView(canvasView: $canvasView, tool: (currentPKTool() as! PKInkingTool))
                .edgesIgnoringSafeArea(.all)
            ToolBar(selectedTool: $selectedTool, selectedColor: $selectedColor, onToolSelected: { tool in
                selectTool(tool)
            }, onColorSelected: { color in
                selectColor(color)
            })
        }
    }

    func currentPKTool() -> PKTool? { // Changed return type from PKInkingTool? to PKTool?
        if let inkType = selectedTool.toolType, selectedTool != .eraser {
            return PKInkingTool(inkType, color: UIColor(selectedColor), width: 5)
        } else if selectedTool == .eraser {
            return PKEraserTool(.vector)
        }
        return nil
    }

    func selectTool(_ tool: DrawingTool) {
        if tool == .undo {
            canvasView.undoManager?.undo()
        } else if tool == .redo {
            canvasView.undoManager?.redo()
        } else if tool == .cut {
            // Implement cut functionality
        } else {
            canvasView.tool = currentPKTool()!
        }
    }

    func selectColor(_ color: Color) {
        canvasView.tool = currentPKTool()!
    }
}

#Preview {
    ContentView()
}
