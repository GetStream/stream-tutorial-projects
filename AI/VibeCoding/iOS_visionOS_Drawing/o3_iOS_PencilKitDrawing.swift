//
//  o3PencilKitDrawing.swift
//  CoreSwiftUI
//
//  Created by Amos Gyamfi on 19.4.2025.
//

import SwiftUI
import PencilKit
import UIKit

struct o3PencilKitDrawing: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var importedImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var pdfURL: URL? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let importedImage = importedImage {
                    Image(uiImage: importedImage)
                        .resizable()
                        .scaledToFit()
                        .clipped()
                }

                CanvasRepresentable(canvasView: $canvasView, toolPicker: $toolPicker)
                    .onAppear {
                        toolPicker.setVisible(true, forFirstResponder: canvasView)
                        toolPicker.addObserver(canvasView)
                        canvasView.becomeFirstResponder()
                    }
            }
            .navigationTitle("o3Draw")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $importedImage)
            }
            .sheet(item: $pdfURL) { url in
                ActivityView(activityItems: [url])
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        exportDrawingAsPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "photo.badge.plus")
                    }
                    Menu {
                        Button {
                            // Save the current drawing to Photos
                            saveToPhotos()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            // Undo the last stroke
                            canvasView.undoManager?.undo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }

                        Button {
                            // Redo the last undone stroke
                            canvasView.undoManager?.redo()
                        } label: {
                            Label("Redo", systemImage: "arrow.uturn.forward")
                        }

                        Button {
                            // Clear the current drawing
                            canvasView.drawing = PKDrawing()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
            }
         }
    }

    // Save the current drawing to the Photos album
    private func saveToPhotos() {
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    // Export the current composition (background image + drawing) as a single‑page PDF
    private func exportDrawingAsPDF() {
        let bounds = canvasView.bounds
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            
            // Draw imported background image first, if any
            if let importedImage = importedImage {
                importedImage.draw(in: bounds)
            }
            
            // Draw the PencilKit strokes on top
            let drawingImage = canvasView.drawing.image(from: bounds, scale: UIScreen.main.scale)
            drawingImage.draw(in: bounds)
        }
        
        // Write to a temporary file so we can share a URL
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("o3Drawing.pdf")
        do {
            try data.write(to: tempURL)
            DispatchQueue.main.async {
                pdfURL = tempURL
            }
        } catch {
            print("Failed to write PDF: \(error)")
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No dynamic updates needed for the static canvas
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var image: UIImage?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true // enables built‑in cropping UI
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    o3PencilKitDrawing()
}
