//
//  ContentView.swift
//  FaceBoard
//
//  Created by Gyamfi from getstream.io
//

import SwiftUI
import PencilKit
import StreamVideo
import StreamVideoSwiftUI
import StreamChat
import StreamChatSwiftUI

struct FreeFormDrawingView: View {
    
    @ObservedObject var viewModel: CallViewModel
    // Define a state variable to capture touches from the user's finger and Apple pencil.
    @State private var canvas = PKCanvasView()
    @State private var isDrawing = true
    @State private var color: Color = .black
    @State private var pencilType: PKInkingTool.InkType = .pencil
    @State private var colorPicker = false
    
    @State private var isMessaging = false
    @State private var isVideoCalling = false
    @State private var isScreenSharing = false
    @State private var isRecording = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        NavigationStack {
            // Drawing View
            DrawingView(canvas: $canvas, isDrawing: $isDrawing, pencilType: $pencilType, color: $color)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
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
                        
                        Divider()
                            .rotationEffect(.degrees(90))
                        
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
                        
                        Spacer()
                        
                        // Drawing Tools
                        Button {
                            // Pencil
                            isDrawing = true
                            pencilType = .pencil
                        } label: {
                            Label("Pencil", systemImage: "pencil.and.scribble")
                        }
                        
                        Button {
                            // Pen
                            isDrawing = true
                            pencilType = .pen
                        } label: {
                            Label("Pen", systemImage: "applepencil.tip")
                        }
                        
                        Button {
                            // Monoline
                            isDrawing = true
                            pencilType = .monoline
                        } label: {
                            Label("Monoline", systemImage: "pencil.line")
                        }
                        
                        Button {
                            // Fountain: Variable scribbling
                            isDrawing = true
                            pencilType = .fountainPen
                        } label: {
                            Label("Fountain", systemImage: "scribble.variable")
                        }
                        
                        Button {
                            // Marker
                            isDrawing = true
                            pencilType = .marker
                        } label: {
                            Label("Marker", systemImage: "paintbrush.pointed")
                        }
                        
                        Button {
                            // Crayon
                            isDrawing = true
                            pencilType = .crayon
                        } label: {
                            Label("Crayon", systemImage: "paintbrush")
                        }
                        
                        Button {
                            // Water Color
                            isDrawing = true
                            pencilType = .watercolor
                        } label: {
                            Label("Watercolor", systemImage: "eyedropper.halffull")
                        }
                        
                        Divider()
                            .rotationEffect(.degrees(90))
                        
                        // Color picker
                        Button {
                            // Pick a color
                            colorPicker.toggle()
                        } label: {
                            Label("Color", systemImage: "paintpalette")
                        }
                        
                        Button {
                            // Set ruler as active
                            canvas.isRulerActive.toggle()
                        } label: {
                            Image(systemName: "pencil.and.ruler.fill")
                        }
                    }
                    
                    // Collaboration tools
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Chat messaging
                        Button {
                            isMessaging.toggle()
                        } label: {
                            VStack {
                                Image(systemName: "message")
                                Text("Chat")
                                    .font(.caption2)
                            }
                        }
                        .sheet(isPresented: $isMessaging, content: ChatSetup.init)
                        
                        // Video calling
                        Button {
                            isVideoCalling.toggle()
                        } label: {
                            VStack {
                                Image(systemName: "video")
                                Text("Call")
                                    .font(.caption2)
                            }
                        }
                        .sheet(isPresented: $isVideoCalling, content: CallContainerSetup.init)
                        
                        // Screen sharing
                        Button {
                            isScreenSharing ? viewModel.stopScreensharing() : viewModel.startScreensharing(type: .inApp)
                            isScreenSharing.toggle()
                        } label: {
                            VStack {
                                Image(systemName: isScreenSharing ? "shared.with.you.slash" : "shared.with.you")
                                    .foregroundStyle(isScreenSharing ? .red : .blue)
                                    .contentTransition(.symbolEffect(.replace))
                                    .contentTransition(.interpolate)
                                withAnimation {
                                    Text(isScreenSharing ? "Stop" : "Share")
                                        .font(.caption2)
                                        .foregroundStyle(isScreenSharing ? .red : .blue)
                                        .contentTransition(.interpolate)
                                }
                            }
                        }
                        
                        // Screen recording
                        Button {
                            isRecording.toggle()
                        } label: {
                            //Image(systemName: "rectangle.dashed.badge.record")
                            VStack {
                                Image(systemName: isRecording ? "rectangle.inset.filled.badge.record" : "rectangle.dashed.badge.record")
                                    .foregroundStyle(isRecording ? .red : .blue)
                                    .contentTransition(.symbolEffect(.replace))
                                    .contentTransition(.interpolate)
                                withAnimation {
                                    Text(isRecording ? "Stop" : "Record")
                                        .font(.caption2)
                                        .foregroundStyle(isRecording ? .red : .blue)
                                        .contentTransition(.interpolate)
                                }
                            }
                        }
                        
                        
                        Divider()
                            .rotationEffect(.degrees(90))
                        
                        // Save your creativity
                        Button {
                            saveDrawing()
                            
                        } label: {
                            VStack {
                                Image(systemName: "square.and.arrow.down.on.square")
                                Text("Save")
                                    .font(.caption2)
                            }
                        }
                    }
                }
        }
    }
    
    // Save drawings to Photos
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
        // Eraser tool
        canvas.tool = isDrawing ? ink : eraser
        canvas.alwaysBounceVertical = true
        
        // Toolpicker
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

