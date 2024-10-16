import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    var onColorSelected: (Color) -> Void

    let colors: [Color] = [.black, .red, .blue, .green, .yellow, .orange, .purple, .brown]

    var body: some View {
        HStack {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .onTapGesture {
                        self.selectedColor = color
                        onColorSelected(color)
                    }
            }
        }
    }
}
