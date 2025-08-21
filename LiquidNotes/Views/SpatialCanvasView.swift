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
    let folders: [Folder]
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onFavorite: (Note) -> Void
    let onFolderTap: ((Folder) -> Void)?
    let onFolderDelete: ((Folder) -> Void)?
    let onFolderFavorite: ((Folder) -> Void)?
    
    private let canvasHeight: CGFloat = 3000
    @State private var draggedNote: Note?
    @State private var draggedFolder: Folder?
    @State private var dragOffset: CGSize = .zero
    @State private var showingContextMenu: Note?
    @State private var contextMenuPosition: CGPoint = .zero
    
    // Grid snapping - more flexible with fractional positioning
    private let gridSize: CGFloat = 80 // Smaller grid for more flexibility
    private let verticalSpacing: CGFloat = 60 // Smaller vertical spacing
    private let noteWidth: CGFloat = 160 // Smaller note width for better screen fit
    private let noteHeight: CGFloat = 120 // Smaller note height for better screen fit
    
    var body: some View {
        GeometryReader { geometry in
            canvasContent(geometry: geometry)
        }
    }
    
    private func canvasContent(geometry: GeometryProxy) -> some View {
        ScrollView(.vertical) {
            canvasZStack(geometry: geometry)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            initializeNotePositions(screenWidth: geometry.size.width)
        }
    }
    
    private func canvasZStack(geometry: GeometryProxy) -> some View {
        ZStack {
            canvasBackground(geometry: geometry)
            notesLayer(geometry: geometry)
            
            // Custom context menu overlay
            if let menuNote = showingContextMenu {
                CustomContextMenuView(
                    note: menuNote,
                    position: contextMenuPosition,
                    onFavorite: {
                        onFavorite(menuNote)
                        showingContextMenu = nil
                    },
                    onDelete: {
                        onDelete(menuNote)
                        showingContextMenu = nil
                    },
                    onDismiss: {
                        showingContextMenu = nil
                    }
                )
                .zIndex(2000) // Above all notes
            }
        }
        .gesture(canvasDragGesture(geometry: geometry))
        .onTapGesture { location in
            handleCanvasTap(location: location, geometry: geometry)
        }
        .coordinateSpace(.named("canvas"))
    }
    
    private func canvasBackground(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: geometry.size.width, height: canvasHeight)
    }
    
    private func notesLayer(geometry: GeometryProxy) -> some View {
        ForEach(notes.sorted { $0.zIndex < $1.zIndex }, id: \.id) { note in
            SpatialNoteView(
                note: note,
                geometry: geometry,
                draggedNote: $draggedNote,
                dragOffset: $dragOffset,
                showingContextMenu: $showingContextMenu,
                contextMenuPosition: $contextMenuPosition,
                onTap: onTap,
                onDelete: onDelete,
                onFavorite: onFavorite,
                getInitialX: getInitialX,
                getInitialY: getInitialY,
                bringNoteToFront: bringNoteToFront,
                snapToGrid: { position, screenWidth, excludeNote in
                    snapToGrid(position, screenWidth: screenWidth, excludeNote: excludeNote)
                },
                updateNotePosition: { note, position, screenWidth in updateNotePosition(note, to: position, screenWidth: screenWidth) },
                getStackedNotes: getStackedNotes
            )
            .allowsHitTesting(draggedNote?.id == note.id || (draggedNote == nil && showingContextMenu == nil))
        }
    }
    
    private func canvasDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                handleDragChanged(value: value, geometry: geometry)
            }
            .onEnded { value in
                handleDragEnded(value: value, geometry: geometry)
            }
    }
    
    private func handleCanvasTap(location: CGPoint, geometry: GeometryProxy) {
        // Dismiss context menu if it's open
        if showingContextMenu != nil {
            showingContextMenu = nil
            return
        }
        
        if let touchedNote = findNoteAtPosition(location, in: geometry) {
            HapticManager.shared.noteSelected()
            onTap(touchedNote)
        }
    }
    
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // Prevent dragging when context menu is open
        guard showingContextMenu == nil else { return }
        
        // Only start dragging if we have significant movement to avoid conflicts with context menu
        let dragThreshold: CGFloat = 8
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        
        if draggedNote == nil && dragDistance > dragThreshold {
            if let touchedNote = findNoteAtPosition(value.startLocation, in: geometry) {
                draggedNote = touchedNote
                dragOffset = value.translation
                bringNoteToFront(touchedNote)
            }
        }
        
        if draggedNote != nil {
            dragOffset = value.translation
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // Prevent drag ending when context menu is open
        guard showingContextMenu == nil else { return }
        guard let currentNote = draggedNote else { return }
        
        let currentPos = getCurrentPosition(for: currentNote, geometry: geometry)
        let finalPosition = CGPoint(
            x: currentPos.x + value.translation.width,
            y: currentPos.y + value.translation.height
        )
        
        let snappedPosition = snapToGrid(finalPosition, screenWidth: geometry.size.width, excludeNote: currentNote)
        
        withAnimation(.interactiveSpring) {
            updateNotePosition(currentNote, to: snappedPosition, screenWidth: geometry.size.width)
            draggedNote = nil
            dragOffset = .zero
        }
    }
    
    private func initializeNotePositions(screenWidth: CGFloat) {
        let uninitializedNotes = notes.filter { $0.positionX == 0 && $0.positionY == 0 }
        let unindexedNotes = notes.filter { $0.zIndex == 0 }
        
        guard !uninitializedNotes.isEmpty || !unindexedNotes.isEmpty else { return }
        
        print("🆕 Initializing \(uninitializedNotes.count) new notes (never moving existing ones)")
        
        // ONLY initialize notes that have never been positioned (positionX == 0 && positionY == 0)
        for note in uninitializedNotes {
            print("🆕 Positioning new note: \(note.title.prefix(20))")
            note.positionX = getInitialX(for: note, screenWidth: screenWidth)
            note.positionY = getInitialY(for: note, screenWidth: screenWidth)
        }
        
        // Assign z-index to any notes that don't have one (without changing positions)
        for note in unindexedNotes {
            let maxZIndex = notes.lazy.map(\.zIndex).max() ?? 0
            note.zIndex = maxZIndex + 1
            print("🔢 Assigned z-index \(note.zIndex) to note: \(note.title.prefix(20))")
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save spatial positions: \(error)")
        }
    }
    
    private func bringNoteToFront(_ note: Note) {
        let maxZIndex = notes.lazy.map(\.zIndex).max() ?? 0
        
        // Only update if this note isn't already at the front
        if note.zIndex < maxZIndex {
            note.zIndex = maxZIndex + 1
            note.updateModifiedDate()
            try? modelContext.save()
        }
    }
    
    private func getStackedNotes(at position: CGPoint) -> [Note] {
        let threshold: CGFloat = 50 // Distance to consider notes as stacked
        
        return notes.filter { note in
            let notePos = CGPoint(x: CGFloat(note.positionX), y: CGFloat(note.positionY))
            let distance = sqrt(pow(position.x - notePos.x, 2) + pow(position.y - notePos.y, 2))
            return distance < threshold
        }.sorted { $0.zIndex > $1.zIndex } // Highest z-index first
    }
    
    private func assignInitialZIndex(to note: Note) {
        // For new notes, ensure they start with the highest z-index
        let maxZIndex = notes.lazy.map(\.zIndex).max() ?? 0
        note.zIndex = maxZIndex + 1
    }
    
    private func getInitialX(for note: Note, screenWidth: CGFloat) -> Float {
        // SIMPLE initial positioning - just place notes in a basic grid
        let noteIndex = notes.firstIndex(where: { $0.id == note.id }) ?? 0
        let spacing: CGFloat = 160 // Simple spacing
        let columns = Int(screenWidth / spacing)
        let column = noteIndex % max(columns, 1)
        
        let minX = noteWidth / 2 + 20
        let maxX = screenWidth - noteWidth / 2 - 20
        let x = minX + CGFloat(column) * spacing
        
        let clampedX = min(max(minX, x), maxX)
        print("🆕 Initial X for new note '\(note.title.prefix(10))': \(clampedX)")
        return Float(clampedX)
    }
    
    private func getInitialY(for note: Note, screenWidth: CGFloat) -> Float {
        // SIMPLE initial positioning - just place notes in a basic grid
        let noteIndex = notes.firstIndex(where: { $0.id == note.id }) ?? 0
        let spacing: CGFloat = 160 // Simple spacing
        let columns = Int(screenWidth / spacing)
        let row = noteIndex / max(columns, 1)
        
        let y = 140 + CGFloat(row) * 180 // Start below header/add button with spacing
        print("🆕 Initial Y for new note '\(note.title.prefix(10))': \(y)")
        return Float(y)
    }
    
    private func snapToGrid(_ position: CGPoint, screenWidth: CGFloat, excludeNote: Note? = nil) -> CGPoint {
        // SIMPLE CLEAN APPROACH - find closest note and decide what to do
        
        var closestNote: Note?
        var closestDistance: CGFloat = CGFloat.infinity
        
        // Find closest note (excluding the one being dragged)
        for note in notes {
            if let excludeNote = excludeNote, note.id == excludeNote.id {
                continue
            }
            
            let notePos = CGPoint(x: CGFloat(note.positionX), y: CGFloat(note.positionY))
            let distance = sqrt(pow(position.x - notePos.x, 2) + pow(position.y - notePos.y, 2))
            
            if distance < closestDistance {
                closestDistance = distance
                closestNote = note
            }
        }
        
        // Simple decision making
        if let targetNote = closestNote {
            let targetPos = CGPoint(x: CGFloat(targetNote.positionX), y: CGFloat(targetNote.positionY))
            
            // STACK: If very close (within 80pts), stack directly on top
            if closestDistance < 80 {
                return targetPos
            }
            
            // POSITION: If moderately close (80-120pts), snap to edge/corner
            if closestDistance < 120 {
                return getSnapPosition(dragPos: position, targetPos: targetPos, screenWidth: screenWidth)
            }
        }
        
        // GRID: Default grid snapping
        return snapToGridPosition(position, screenWidth: screenWidth)
    }
    
    private func getSnapPosition(dragPos: CGPoint, targetPos: CGPoint, screenWidth: CGFloat) -> CGPoint {
        let deltaX = dragPos.x - targetPos.x
        let deltaY = dragPos.y - targetPos.y
        let halfWidth = noteWidth * 0.5
        let halfHeight = noteHeight * 0.5
        
        // Simple direction-based snapping
        var snapPos: CGPoint
        
        if abs(deltaX) > abs(deltaY) {
            // Horizontal snap (left or right)
            snapPos = CGPoint(
                x: targetPos.x + (deltaX > 0 ? halfWidth : -halfWidth),
                y: targetPos.y
            )
        } else {
            // Vertical snap (top or bottom)
            snapPos = CGPoint(
                x: targetPos.x,
                y: targetPos.y + (deltaY > 0 ? halfHeight : -halfHeight)
            )
        }
        
        // Clamp to bounds - only enforce minimum Y for final placement
        let minX = noteWidth / 2 + 10
        let maxX = screenWidth - noteWidth / 2 - 10
        let minY: CGFloat = 120 // Increased to account for header + add button
        
        return CGPoint(
            x: min(max(minX, snapPos.x), maxX),
            y: max(minY, snapPos.y)
        )
    }
    
    private func snapToGridPosition(_ position: CGPoint, screenWidth: CGFloat) -> CGPoint {
        let topPadding: CGFloat = 120 // Increased to account for header + add button
        let minX = noteWidth / 2 + 10
        let maxX = screenWidth - noteWidth / 2 - 10
        
        let snapX = round(position.x / gridSize) * gridSize
        let adjustedY = max(topPadding, position.y)
        let snapY = round((adjustedY - topPadding) / verticalSpacing) * verticalSpacing + topPadding
        
        return CGPoint(
            x: min(max(minX, snapX), maxX),
            y: snapY
        )
    }
    
    private func updateNotePosition(_ note: Note, to position: CGPoint, screenWidth: CGFloat) {
        // Final bounds check - enforce minimum Y to prevent placement in header area
        let minX = noteWidth / 2 + 10
        let maxX = screenWidth - noteWidth / 2 - 10
        let minY: CGFloat = 120 // Increased to account for header + add button
        
        let safeX = min(max(minX, position.x), maxX)
        let safeY = max(minY, position.y)
        
        // Update ONLY this note's position
        note.positionX = Float(safeX)
        note.positionY = Float(safeY)
        note.updateModifiedDate()
        
        try? modelContext.save()
    }
    
    private func findNoteAtPosition(_ location: CGPoint, in geometry: GeometryProxy) -> Note? {
        // Find all notes that contain this point, sorted by z-index (highest first)
        let candidateNotes = notes.filter { note in
            let notePos = getCurrentPosition(for: note, geometry: geometry)
            let noteRect = CGRect(
                x: notePos.x - noteWidth/2,
                y: notePos.y - noteHeight/2,
                width: noteWidth,
                height: noteHeight
            )
            return noteRect.contains(location)
        }.sorted { $0.zIndex > $1.zIndex } // Highest z-index first
        
        return candidateNotes.first // Return the topmost note
    }
    
    private func getCurrentPosition(for note: Note, geometry: GeometryProxy) -> CGPoint {
        let x = note.positionX == 0 ? getInitialX(for: note, screenWidth: geometry.size.width) : note.positionX
        let y = note.positionY == 0 ? getInitialY(for: note, screenWidth: geometry.size.width) : note.positionY
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

// Separate view to handle individual note positioning and gestures
struct SpatialNoteView: View {
    let note: Note
    let geometry: GeometryProxy
    @Binding var draggedNote: Note?
    @Binding var dragOffset: CGSize
    @Binding var showingContextMenu: Note?
    @Binding var contextMenuPosition: CGPoint
    
    // Resize state
    @State private var isResizing: Bool = false
    @State private var resizeStartSize: CGSize = .zero
    
    // Note dimensions - now dynamic based on note properties
    private var noteWidth: CGFloat { CGFloat(note.width) }
    private var noteHeight: CGFloat { CGFloat(note.height) }
    
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onFavorite: (Note) -> Void
    let getInitialX: (Note, CGFloat) -> Float
    let getInitialY: (Note, CGFloat) -> Float
    let bringNoteToFront: (Note) -> Void
    let snapToGrid: (CGPoint, CGFloat, Note?) -> CGPoint
    let updateNotePosition: (Note, CGPoint, CGFloat) -> Void
    let getStackedNotes: (CGPoint) -> [Note]
    
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
        if draggedNote?.id == note.id {
            return 1.05
        }
        
        // Slightly scale down stacked notes that aren't on top
        let stackedNotes = getStackedNotes(currentPosition)
        if stackedNotes.count > 1 && stackedNotes.first?.id != note.id {
            return 0.95
        }
        
        return 1.0
    }
    
    private var zIndexValue: Double {
        return draggedNote?.id == note.id ? 1000 : Double(note.zIndex)
    }
    
    private var shadowConfiguration: (radius: CGFloat, opacity: Double, offset: CGSize) {
        let stackedNotes = getStackedNotes(currentPosition)
        let isTopOfStack = stackedNotes.first?.id == note.id
        let stackCount = stackedNotes.count
        
        if draggedNote?.id == note.id {
            // Dragged note has enhanced shadow
            return (radius: 20, opacity: 0.3, offset: CGSize(width: 0, height: 8))
        } else if stackCount > 1 {
            if isTopOfStack {
                // Top of stack has normal shadow
                return (radius: 12, opacity: 0.2, offset: CGSize(width: 0, height: 6))
            } else {
                // Stacked notes have reduced shadow to show layering
                return (radius: 6, opacity: 0.1, offset: CGSize(width: 2, height: 3))
            }
        } else {
            // Single notes have standard shadow
            return (radius: 8, opacity: 0.1, offset: CGSize(width: 0, height: 4))
        }
    }
    
    private var stackIndicatorOffset: CGSize {
        let stackedNotes = getStackedNotes(currentPosition)
        let stackPosition = stackedNotes.firstIndex(where: { $0.id == note.id }) ?? 0
        
        if stackedNotes.count > 1 && stackPosition > 0 {
            // Offset stacked notes slightly to show depth
            let offsetX = CGFloat(stackPosition) * 3
            let offsetY = CGFloat(stackPosition) * 2
            return CGSize(width: offsetX, height: offsetY)
        }
        
        return .zero
    }
    
    var body: some View {
        // Force exact dimensions with Rectangle constraint
        Rectangle()
            .fill(Color.clear)
            .frame(width: noteWidth, height: noteHeight)
            .overlay(
                ZStack {
                    // Stack indicator for multiple notes
                    if getStackedNotes(currentPosition).count > 1 {
                        StackIndicatorView(stackCount: getStackedNotes(currentPosition).count)
                            .offset(stackIndicatorOffset)
                            .opacity(draggedNote?.id == note.id ? 0.3 : 0.6)
                    }
                    
                    // Use a plain note view without competing gestures
                    NoteContentView(note: note, width: noteWidth, height: noteHeight)
                        .shadow(
                            color: .black.opacity(shadowConfiguration.opacity),
                            radius: shadowConfiguration.radius,
                            x: shadowConfiguration.offset.width,
                            y: shadowConfiguration.offset.height
                        )
                    
                    // Resize handle in bottom-right corner
                    if draggedNote?.id != note.id && showingContextMenu == nil {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ResizeHandle(note: note, isResizing: $isResizing)
                            }
                        }
                        .frame(width: noteWidth, height: noteHeight)
                    }
                }
                .frame(width: noteWidth, height: noteHeight)
                .clipped()
            )
            .scaleEffect(scaleValue)
            .position(displayPosition)
            .zIndex(zIndexValue)
            .animation(.bouncy(duration: 0.6), value: draggedNote?.id == note.id)
            .animation(.easeInOut(duration: 0.3), value: getStackedNotes(currentPosition).count)
            .onLongPressGesture(minimumDuration: 0.5) {
                if draggedNote?.id != note.id && showingContextMenu == nil {
                    HapticManager.shared.buttonTapped()
                    showingContextMenu = note
                    contextMenuPosition = displayPosition
                }
            }
    }
}


// Note content view without competing gestures
struct NoteContentView: View {
    let note: Note
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .layoutPriority(1)
                }
                
                Spacer(minLength: 4)
                
                if note.isFavorited {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .layoutPriority(2)
                }
            }
            .frame(height: 30)
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxHeight: 50, alignment: .top)
                    .layoutPriority(1)
            }
            
            // Show first attachment if available
            if !note.attachments.isEmpty, let firstAttachment = note.attachments.first,
               let firstType = note.attachmentTypes.first, firstType.hasPrefix("image/"),
               let uiImage = UIImage(data: firstAttachment) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 30)
                    .clipped()
                    .cornerRadius(4)
                    .opacity(0.8)
            }
            
            Spacer(minLength: 0)
            
            HStack(alignment: .bottom) {
                Text(note.modifiedDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
                
                Spacer(minLength: 4)
                
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .layoutPriority(2)
                }
            }
            .frame(height: 16)
        }
        .padding(8)
        .frame(width: width, height: height)
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .frame(width: width, height: height)
        )
        .liquidGlassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .clipped()
    }
}

// Custom Context Menu that doesn't interfere with note layout
struct CustomContextMenuView: View {
    let note: Note
    let position: CGPoint
    let onFavorite: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    
    // Calculate smart positioning to respect screen boundaries using geometry
    private func menuPosition(in geometry: GeometryProxy) -> CGPoint {
        let menuWidth: CGFloat = 160 // Further reduced to ensure it fits
        let menuHeight: CGFloat = 96 // Further reduced to match smaller padding
        let padding: CGFloat = 8 // Further reduced padding
        let noteWidth: CGFloat = 160
        let noteHeight: CGFloat = 120
        
        // Get safe area insets
        let safeAreaTop = geometry.safeAreaInsets.top
        let safeAreaBottom = geometry.safeAreaInsets.bottom
        let safeAreaLeading = geometry.safeAreaInsets.leading
        let safeAreaTrailing = geometry.safeAreaInsets.trailing
        
        
        var x = position.x
        var y = position.y
        
        // Horizontal positioning logic - smarter edge handling
        let minX = safeAreaLeading + padding
        let maxX = geometry.size.width - safeAreaTrailing - padding - menuWidth
        
        // Ensure maxX is valid (screen is wide enough for menu)
        if maxX < minX {
            // Screen too narrow, center the menu
            x = (geometry.size.width - menuWidth) / 2
        } else {
            // Calculate how close the note is to each edge
            let distanceToLeftEdge = position.x - safeAreaLeading
            let distanceToRightEdge = (geometry.size.width - safeAreaTrailing) - position.x
            
            // Determine which side of the note has more space
            if distanceToRightEdge < distanceToLeftEdge {
                // Note is closer to right edge - use aggressive right-side positioning
                
                // Calculate the rightmost possible position for the menu
                let rightmostX = geometry.size.width - safeAreaTrailing - padding - menuWidth
                
                // Try to position menu as close to note as possible on the right side
                let preferredRightX = position.x + (noteWidth / 2) - menuWidth + 8 // Small overlap
                
                if preferredRightX >= minX {
                    // Use the closer of: preferred position or rightmost valid position
                    x = min(preferredRightX, rightmostX)
                } else {
                    // If preferred doesn't fit, try centered on note
                    let centeredX = position.x - (menuWidth / 2)
                    if centeredX >= minX && centeredX + menuWidth <= rightmostX + menuWidth {
                        x = max(minX, min(centeredX, rightmostX))
                    } else {
                        // Last resort: rightmost position
                        x = rightmostX
                    }
                }
            } else {
                // Note is closer to left edge or centered - use standard logic
                
                // First try: standard right side placement
                let rightX = position.x + (noteWidth / 2) + padding
                if rightX <= maxX {
                    x = rightX
                } else {
                    // Second try: standard left side placement  
                    let leftX = position.x - (noteWidth / 2) - padding - menuWidth
                    if leftX >= minX {
                        x = leftX
                    } else {
                        // Third try: align menu left edge with note left edge
                        let alignedLeftX = position.x - (noteWidth / 2)
                        if alignedLeftX <= maxX {
                            x = max(minX, alignedLeftX)
                        } else {
                            // Last resort: as far left as possible
                            x = minX
                        }
                    }
                }
            }
        }
        
        // Vertical positioning logic - guaranteed to stay within bounds
        let minY = safeAreaTop + padding
        let maxY = geometry.size.height - safeAreaBottom - padding - menuHeight
        
        // Ensure maxY is valid (screen is tall enough for menu)
        if maxY < minY {
            // Screen too short, center the menu
            y = (geometry.size.height - menuHeight) / 2
        } else {
            // Try centered with note first
            let centeredY = position.y - menuHeight / 2
            if centeredY >= minY && centeredY <= maxY {
                y = centeredY
            } else {
                // Try below note
                let belowY = position.y + (noteHeight / 2) + padding
                if belowY >= minY && belowY <= maxY {
                    y = belowY
                } else {
                    // Try above note
                    let aboveY = position.y - (noteHeight / 2) - padding - menuHeight
                    if aboveY >= minY && aboveY <= maxY {
                        y = aboveY
                    } else {
                        // For edge cases, position menu to stay as close to note as possible
                        let distanceToTopEdge = position.y - safeAreaTop
                        let distanceToBottomEdge = (geometry.size.height - safeAreaBottom) - position.y
                        
                        if distanceToBottomEdge < distanceToTopEdge {
                            // Note is closer to bottom edge - try to align menu bottom with note bottom
                            let alignedBottomY = position.y + (noteHeight / 2) - menuHeight
                            if alignedBottomY >= minY {
                                y = alignedBottomY
                            } else {
                                y = maxY
                            }
                        } else {
                            // Note is closer to top edge - try to align menu top with note top
                            let alignedTopY = position.y - (noteHeight / 2)
                            if alignedTopY <= maxY {
                                y = max(minY, alignedTopY)
                            } else {
                                y = minY
                            }
                        }
                    }
                }
            }
        }
        
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen invisible background for dismissal
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }
                    .ignoresSafeArea(.all)
                
                // Native iOS context menu styling
                VStack(spacing: 1) {
                    Button(action: {
                        HapticManager.shared.buttonTapped()
                        onFavorite()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: note.isFavorited ? "star.slash" : "star")
                                .foregroundStyle(note.isFavorited ? .secondary : Color.yellow)
                                .font(.system(size: 17, weight: .regular))
                                .frame(width: 22, alignment: .center)
                            
                            Text(note.isFavorited ? "Remove from Favorites" : "Add to Favorites")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        HapticManager.shared.buttonTapped()
                        // Add share functionality
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                                .font(.system(size: 17, weight: .regular))
                                .frame(width: 22, alignment: .center)
                            
                            Text("Share")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.horizontal, 12)
                    
                    Button(action: {
                        HapticManager.shared.noteDeleted()
                        onDelete()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.system(size: 17, weight: .regular))
                                .frame(width: 22, alignment: .center)
                            
                            Text("Delete")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 160)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .position(menuPosition(in: geometry))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.3, anchor: .center)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -10)),
                    removal: .scale(scale: 0.9, anchor: .center)
                        .combined(with: .opacity)
                ))
                .animation(.smooth(duration: 0.4, extraBounce: 0.0), value: position)
                .onTapGesture {
                    // Prevent menu tap from dismissing
                }
            }
        }
    }
}

// Resize handle for notes
struct ResizeHandle: View {
    let note: Note
    @Binding var isResizing: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Circle()
            .fill(.regularMaterial)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(.quaternary, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            )
            .scaleEffect(isResizing ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isResizing)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            HapticManager.shared.buttonTapped()
                        }
                        
                        // Calculate new size based on drag
                        let newWidth = max(120, Float(CGFloat(note.width) + value.translation.width))
                        let newHeight = max(80, Float(CGFloat(note.height) + value.translation.height))
                        
                        // Update note size
                        note.width = newWidth
                        note.height = newHeight
                        note.updateModifiedDate()
                    }
                    .onEnded { _ in
                        isResizing = false
                        HapticManager.shared.noteDropped()
                        try? modelContext.save()
                    }
            )
    }
}

// Visual indicator for stacked notes
struct StackIndicatorView: View {
    let stackCount: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(stackCount, 5), id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .scaleEffect(index == 0 ? 1.2 : 0.8)
            }
            
            if stackCount > 5 {
                Text("+\(stackCount - 5)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(.black.opacity(0.6)))
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.black.opacity(0.3))
                .blur(radius: 1)
        )
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
        folders: [],
        onTap: { _ in },
        onDelete: { _ in },
        onFavorite: { _ in },
        onFolderTap: nil,
        onFolderDelete: nil,
        onFolderFavorite: nil
    )
    .modelContainer(for: [Note.self, NoteCategory.self, Folder.self], inMemory: true)
}