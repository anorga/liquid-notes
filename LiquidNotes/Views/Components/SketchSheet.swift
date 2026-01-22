import SwiftUI
import PencilKit

struct SketchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onInsert: (UIImage, Data) -> Void

    @State private var drawing = PKDrawing()
    @State private var canvasSize: CGSize = .zero
    @State private var toolIsEraser = false
    @State private var strokeIsLight = true
    @State private var showingEmptyWarning = false

    private var hasContent: Bool {
        !drawing.bounds.isEmpty && drawing.strokes.count > 0
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.clear.ignoresSafeArea()
                SketchCanvasRepresentable(drawing: $drawing, canvasSize: $canvasSize, toolIsEraser: $toolIsEraser, strokeIsLight: $strokeIsLight)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: UI.Corner.m, style: .continuous))
                    .padding(UI.Space.m)
            }
            .navigationTitle("Sketch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        if hasContent {
                            insertAndDismiss()
                        } else {
                            showingEmptyWarning = true
                        }
                    }
                    .bold()
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Picker("Tool", selection: $toolIsEraser) {
                        Image(systemName: "pencil.tip").tag(false)
                        Image(systemName: "eraser").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Picker("Tone", selection: $strokeIsLight) {
                        Text("Light").tag(true)
                        Text("Dark").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                    Button("Clear") { drawing = PKDrawing() }
                }
            }
            .alert("Empty Sketch", isPresented: $showingEmptyWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please draw something before inserting.")
            }
        }
    }

    private func insertAndDismiss() {
        guard hasContent else { return }
        let scale = UIScreen.main.scale
        let bounds = drawing.bounds
        let paddedBounds = bounds.insetBy(dx: -20, dy: -20)
        let drawingImage = drawing.image(from: paddedBounds, scale: scale)

        let backgroundColor: UIColor = strokeIsLight ? UIColor.darkGray : UIColor.white
        let size = drawingImage.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let composited = renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            drawingImage.draw(at: .zero)
        }

        if let data = composited.pngData() {
            onInsert(composited, data)
        }
        dismiss()
    }
}

private struct SketchCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var canvasSize: CGSize
    @Binding var toolIsEraser: Bool
    @Binding var strokeIsLight: Bool

    final class Coordinator {
        var toolPicker: PKToolPicker?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput

        // Create and keep a strong reference to the tool picker (iOS 14+ API)
        // Use our custom toolbar controls; avoid showing the default picker to fit iPhone layout better
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing { uiView.drawing = drawing }
        DispatchQueue.main.async { canvasSize = uiView.bounds.size }
        if toolIsEraser {
            uiView.tool = PKEraserTool(.vector)
        } else {
            let color = strokeIsLight ? UIColor.white : UIColor.black
            uiView.tool = PKInkingTool(.pen, color: color, width: 4)
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.removeObserver(uiView)
    }
}
