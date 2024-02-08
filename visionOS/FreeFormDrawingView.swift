//
//  ContentView.swift
//  PKDraw

import SwiftUI
import PencilKit

struct FreeFormDrawingView: View {
    
    @State private var canvas = PKCanvasView()
    @State private var isDrawing = true
    @State private var color: Color = .black
    @State private var pencilType: PKInkingTool.InkType = .pencil
    @State private var colorPicker = false
    @Environment(\.undoManager) private var undoManager
    
    @State private var isMessaging = false
    @State private var isVideoCalling = false
    @State private var isScreenSharing = false
    @State private var isRecording = false
    @Environment(\.dismiss) private var dismiss
    
   
   
    
    var body: some View {
        NavigationStack {
            // Drawing View
            DrawingView(canvas: $canvas, isDrawing: $isDrawing, pencilType: $pencilType, color: $color)
            //.navigationTitle("PKDraw")
                .navigationBarTitleDisplayMode(.inline)
                .ornament(attachmentAnchor: .scene(.top)) {
                    HStack(spacing: 64) {
                        Button {
                            //
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "message")
                                Text("Chat")
                                    .font(.caption2)
                            }
                        }
                        
                        Button {
                            //
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "video")
                                Text("Call")
                                    .font(.caption2)
                            }
                        }
                        
                        // Screen sharing
                        Button {
                            //
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: isScreenSharing ? "shared.with.you.slash" : "shared.with.you")
                                withAnimation {
                                    Text(isScreenSharing ? "Stop" : "Share")
                                        .font(.caption2)
                                }
                            }
                        }
                        // Screen recording
                        Button {
                            isRecording.toggle()
                        } label: {
                            //Image(systemName: "rectangle.dashed.badge.record")
                            VStack(spacing: 8) {
                                Image(systemName: isRecording ? "rectangle.inset.filled.badge.record" : "rectangle.dashed.badge.record")
                                withAnimation {
                                    Text(isRecording ? "Stop" : "Record")
                                        .font(.caption2)
                                }
                            }
                        }
                    }.padding(.horizontal)
                    .padding(12)
                    .glassBackgroundEffect()
                    .buttonStyle(.plain)
                }
                .ornament(attachmentAnchor: .scene(.leading)) {
                    // Modify Tools
                    VStack(spacing: 32) {
                        Button {
                            // Clear the canvas. Reset the drawing
                            canvas.drawing = PKDrawing()
                        } label: {
                            Image(systemName: "scissors")
                        }
                        
                        Button {
                            // Undo drawing
                            undoManager?.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        
                        Button {
                            // Redo drawing
                            undoManager?.redo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        
                        Button {
                            // Erase tool
                            isDrawing = false
                        } label: {
                            Image(systemName: "eraser.line.dashed")
                        }
                        .foregroundStyle(
                            LinearGradient(gradient: Gradient(colors: [.white, .yellow]), startPoint: .leading, endPoint: .top)
                        )
                    } // Modify tools
                    .padding(12)
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
                }
                .toolbar {
                    // Bottom Ornament
                    ToolbarItemGroup(placement: .bottomOrnament) {
                        HStack { // Drawing Tools
                            Button {
                                // Pencil
                                isDrawing = true
                                pencilType = .pencil
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "pencil.and.scribble")
                                    Text("Pencil")
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                // Pen
                                isDrawing = true
                                pencilType = .pen
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "applepencil.tip")
                                    Text("Pen")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Button {
                                // Monoline
                                isDrawing = true
                                pencilType = .monoline
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "pencil.line")
                                    Text("Monoline")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Button {
                                // Fountain: Variable scribbling
                                isDrawing = true
                                pencilType = .fountainPen
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "scribble.variable")
                                    Text("Fountain")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Button {
                                // Marker
                                isDrawing = true
                                pencilType = .marker
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "paintbrush.pointed")
                                    Text("Marker")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Button {
                                // Crayon
                                isDrawing = true
                                pencilType = .crayon
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "paintbrush")
                                    Text("Crayon")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Button {
                                // Water Color
                                isDrawing = true
                                pencilType = .watercolor
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "eyedropper.halffull")
                                    Text("Watercolor")
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            // Color picker
                            Button {
                                // Pick a color
                                colorPicker.toggle()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "paintpalette")
                                    Text("Colorpicker")
                                        .foregroundStyle(.white)
                                }
                            }
                        } // Drawing Tools
                        .padding(.horizontal)
                        .foregroundStyle(
                            LinearGradient(gradient: Gradient(colors: [.green, .yellow]), startPoint: .leading, endPoint: .bottom)
                        )
                    }  // Bottom Ornament
                }
                .ornament(attachmentAnchor: .scene(.trailing)) {
                    VStack(spacing: 32) {
                        Button {
                            // Set ruler as active
                            canvas.isRulerActive.toggle()
                        } label: {
                            Image(systemName: "pencil.and.ruler.fill")
                        }
                        Button {
                            // Tool picker
                            //let toolPicker = PKToolPicker.init()
                            @State var toolPicker = PKToolPicker()
                            toolPicker.setVisible(true, forFirstResponder: canvas)
                            toolPicker.addObserver(canvas)
                            canvas.becomeFirstResponder()
                        } label: {
                            Image(systemName: "pencil.tip.crop.circle.badge.plus")
                        }
                        
                        // Menu for pencil types and color
                        Menu {
                            Button {
                                // Menu: Pick a color
                                colorPicker.toggle()
                            } label: {
                                Label("Color", systemImage: "paintpalette")
                            }
                            
                            Button {
                                // Menu: Pencil
                                isDrawing = true
                                pencilType = .pencil
                            } label: {
                                Label("Pencil", systemImage: "pencil")
                            }
                            
                            Button {
                                // Menu: pen
                                isDrawing = true
                                pencilType = .pen
                            } label: {
                                Label("Pen", systemImage: "pencil.tip")
                            }
                            
                            Button {
                                // Menu: Marker
                                isDrawing = true
                                pencilType = .marker
                            } label: {
                                Label("Marker", systemImage: "paintbrush.pointed")
                            }
                            
                            Button {
                                // Menu: Monoline
                                isDrawing = true
                                pencilType = .monoline
                            } label: {
                                Label("Monoline", systemImage: "pencil.line")
                            }
                            
                            Button {
                                // Menu: pen
                                isDrawing = true
                                pencilType = .fountainPen
                            } label: {
                                Label("Fountain", systemImage: "paintbrush.pointed.fill")
                            }
                            
                            Button {
                                // Menu: Watercolor
                                isDrawing = true
                                pencilType = .watercolor
                            } label: {
                                Label("Watercolor", systemImage: "eyedropper.halffull")
                            }
                            
                            Button {
                                // Menu: Crayon
                                isDrawing = true
                                pencilType = .crayon
                            } label: {
                                Label("Crayon", systemImage: "pencil.tip")
                            }
                            
                        } label: {
                            Image(systemName: "hand.draw")
                        }
                        .sheet(isPresented: $colorPicker) {
                            ColorPicker("Pick color", selection: $color)
                                .padding()
                        }
                    }.padding(12)
                        .buttonStyle(.plain)
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
                }
        }
    }
    
    func saveDrawing() {
        // Get the drawing image from the canvas
        let drawingImage = canvas.drawing.image(from: canvas.drawing.bounds, scale: 1.0)
        
        // Save drawings to the Photos Album
        UIImageWriteToSavedPhotosAlbum(drawingImage, nil, nil, nil)
    }
}

struct DrawingView: UIViewRepresentable {
    // Capture drawings for saving in the photos library
    @Binding var canvas: PKCanvasView
    @Binding var isDrawing: Bool
    // Ability to switch a pencil
    @Binding var pencilType: PKInkingTool.InkType
    // Ability to change a pencil color
    @Binding var color: Color
    
    
    //let ink = PKInkingTool(.pencil, color: .black)
    // Update ink type
    var ink: PKInkingTool {
        PKInkingTool(pencilType, color: UIColor(color))
    }
    
    let eraser = PKEraserTool(.bitmap)
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Allow finger and pencil drawing
        canvas.drawingPolicy = .anyInput
        
        canvas.tool = isDrawing ? ink : eraser
        canvas.isRulerActive = true
        canvas.backgroundColor = .init(red: 1, green: 1, blue: 0, alpha: 0.1)

        
        // From Brian Advent: Show the default toolpicker
        canvas.alwaysBounceVertical = true
        
        let toolPicker = PKToolPicker.init()
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas) // Notify when the picker configuration changes
        canvas.becomeFirstResponder()
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update tool whenever the main view updates
        uiView.tool = isDrawing ? ink : eraser
    }
}


#Preview {
    FreeFormDrawingView()
}
