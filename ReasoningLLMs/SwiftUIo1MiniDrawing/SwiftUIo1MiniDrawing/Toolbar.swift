import SwiftUI
import PencilKit

struct ToolBar: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    var onToolSelected: (DrawingTool) -> Void
    var onColorSelected: (Color) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(DrawingTool.allCases) { tool in
                    Button(action: {
                        self.selectedTool = tool
                        onToolSelected(tool)
                    }) {
                        Image(systemName: tool.symbolName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding()
                            .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
                ColorPickerView(selectedColor: $selectedColor, onColorSelected: onColorSelected)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground).shadow(radius: 2))
    }
}
