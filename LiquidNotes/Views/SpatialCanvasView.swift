//
//  SpatialCanvasView.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI
import SwiftData

struct SpatialCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    let notes: [Note]
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onPin: (Note) -> Void
    
    private let canvasHeight: CGFloat = 3000
    @State private var draggedNote: Note?
    @State private var dragOffset: CGSize = .zero
    
    // Grid snapping
    private let gridSize: CGFloat = 220 // Note card width + spacing
    private let verticalSpacing: CGFloat = 170 // Note card height + spacing
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) { // Only vertical scrolling
            ZStack {
                // Canvas background constrained to screen width
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width, height: canvasHeight)
                
                // Spatially positioned notes
                ForEach(notes, id: \.id) { note in
                    SpatialNoteView(
                        note: note,
                        geometry: geometry,
                        draggedNote: $draggedNote,
                        dragOffset: $dragOffset,
                        onTap: onTap,
                        onDelete: onDelete,
                        onPin: onPin,
                        getInitialX: getInitialX,
                        getInitialY: getInitialY,
                        bringNoteToFront: bringNoteToFront,
                        snapToGrid: snapToGrid,
                        updateNotePosition: updateNotePosition
                    )
                }
            }
            .coordinateSpace(.named("canvas"))
        }
            .scrollIndicators(.hidden)
            .onAppear {
                initializeNotePositions(screenWidth: geometry.size.width)
            }
        }
    }
    
    private func initializeNotePositions(screenWidth: CGFloat) {
        let uninitializedNotes = notes.filter { $0.positionX == 0 && $0.positionY == 0 }
        let unindexedNotes = notes.filter { $0.zIndex == 0 }
        
        guard !uninitializedNotes.isEmpty || !unindexedNotes.isEmpty else { return }
        
        for (index, note) in notes.enumerated() {
            if note.positionX == 0 && note.positionY == 0 {
                note.positionX = getInitialX(for: note, screenWidth: screenWidth)
                note.positionY = getInitialY(for: note, screenWidth: screenWidth)
            }
            if note.zIndex == 0 {
                note.zIndex = index + 1
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save spatial positions: \(error)")
        }
    }
    
    private func bringNoteToFront(_ note: Note) {
        let maxZIndex = notes.lazy.map(\.zIndex).max() ?? 0
        note.zIndex = maxZIndex + 1
        note.updateModifiedDate()
        try? modelContext.save()
    }
    
    private func getInitialX(for note: Note, screenWidth: CGFloat) -> Float {
        // Calculate how many columns fit on screen
        let columns = Int(screenWidth / gridSize)
        let noteIndex = notes.firstIndex(where: { $0.id == note.id }) ?? 0
        let column = noteIndex % max(columns, 1)
        
        return Float(CGFloat(column) * gridSize + gridSize/2)
    }
    
    private func getInitialY(for note: Note, screenWidth: CGFloat) -> Float {
        // Stack notes vertically with spacing, starting from the top
        let noteIndex = notes.firstIndex(where: { $0.id == note.id }) ?? 0
        let columns = Int(screenWidth / gridSize)
        let row = noteIndex / max(columns, 1)
        
        // Start from top with safe area padding (120pt from top)
        let topPadding: CGFloat = 120
        return Float(topPadding + CGFloat(row) * verticalSpacing)
    }
    
    private func snapToGrid(_ position: CGPoint, screenWidth: CGFloat) -> CGPoint {
        let columns = Int(screenWidth / gridSize)
        let topPadding: CGFloat = 120
        
        // Snap to nearest grid position
        let column = min(max(0, Int(position.x / gridSize)), columns - 1)
        let adjustedY = max(topPadding, position.y - topPadding)
        let row = max(0, Int(adjustedY / verticalSpacing))
        
        return CGPoint(
            x: CGFloat(column) * gridSize + gridSize/2,
            y: topPadding + CGFloat(row) * verticalSpacing
        )
    }
    
    private func updateNotePosition(_ note: Note, to position: CGPoint) {
        note.positionX = Float(position.x)
        note.positionY = Float(position.y)
        note.updateModifiedDate()
        try? modelContext.save()
    }
}

// Separate view to handle individual note positioning and gestures
struct SpatialNoteView: View {
    let note: Note
    let geometry: GeometryProxy
    @Binding var draggedNote: Note?
    @Binding var dragOffset: CGSize
    
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onPin: (Note) -> Void
    let getInitialX: (Note, CGFloat) -> Float
    let getInitialY: (Note, CGFloat) -> Float
    let bringNoteToFront: (Note) -> Void
    let snapToGrid: (CGPoint, CGFloat) -> CGPoint
    let updateNotePosition: (Note, CGPoint) -> Void
    
    private var currentPosition: CGPoint {
        let x = note.positionX == 0 ? getInitialX(note, geometry.size.width) : note.positionX
        let y = note.positionY == 0 ? getInitialY(note, geometry.size.width) : note.positionY
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    private var displayPosition: CGPoint {
        let basePos = currentPosition
        if draggedNote?.id == note.id {
            return CGPoint(
                x: basePos.x + dragOffset.width,
                y: basePos.y + dragOffset.height
            )
        }
        return basePos
    }
    
    private var scaleValue: CGFloat {
        return draggedNote?.id == note.id ? 1.05 : 1.0
    }
    
    private var zIndexValue: Double {
        return draggedNote?.id == note.id ? 1000 : Double(note.zIndex)
    }
    
    var body: some View {
        NoteCardView(
            note: note,
            onTap: { onTap(note) },
            onDelete: { onDelete(note) },
            onPin: { onPin(note) }
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .position(displayPosition)
        .scaleEffect(scaleValue)
        .zIndex(zIndexValue)
        .gesture(createGesture())
        .animation(.bouncy(duration: 0.6), value: draggedNote?.id == note.id)
    }
    
    private func createGesture() -> some Gesture {
        createDragGesture()
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(coordinateSpace: .named("canvas"))
            .onChanged { value in
                if draggedNote == nil {
                    draggedNote = note
                    dragOffset = .zero
                    bringNoteToFront(note)
                }
                
                if draggedNote?.id == note.id {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                if draggedNote?.id == note.id {
                    withAnimation(.interactiveSpring) {
                        let finalPosition = CGPoint(
                            x: currentPosition.x + value.translation.width,
                            y: currentPosition.y + value.translation.height
                        )
                        let snappedPosition = snapToGrid(finalPosition, geometry.size.width)
                        updateNotePosition(note, snappedPosition)
                        draggedNote = nil
                        dragOffset = .zero
                    }
                }
            }
    }
}

#Preview {
    let sampleNotes = [
        Note(title: "Spatial Note 1", content: "This note can be moved around the canvas freely"),
        Note(title: "Another Note", content: "Drag and drop with physics-based animations"),
        Note(title: "Third Note", content: "Infinite canvas with native Apple animations")
    ]
    
    return SpatialCanvasView(
        notes: sampleNotes,
        onTap: { _ in },
        onDelete: { _ in },
        onPin: { _ in }
    )
    .modelContainer(DataContainer.previewContainer)
}