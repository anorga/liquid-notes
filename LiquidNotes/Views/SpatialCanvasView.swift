import SwiftUI
import SwiftData
import UIKit

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
    
    @State private var showingContextMenu: Note?
    @State private var reorderedNotes: [Note] = []
    
    private let noteWidth: CGFloat = 180
    private let noteHeight: CGFloat = 140
    
    private var gridColumns: [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let totalPadding: CGFloat = 40  // horizontal padding
        let availableWidth = screenWidth - totalPadding
        let maxNoteWidth = availableWidth - 20  // Extra buffer for safety
        
        // Use single adaptive column that can fit multiple notes per row but prevents overflow
        return [GridItem(.adaptive(minimum: 140, maximum: maxNoteWidth), spacing: 15)]
    }
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 15) {
                ForEach(displayedNotes, id: \.id) { note in
                    GridNoteCard(
                        note: note,
                        onTap: { onTap(note) },
                        onDelete: { onDelete(note) },
                        onFavorite: { onFavorite(note) },
                        onMoveRequest: { draggedNote, targetPosition in
                            handleNoteMove(draggedNote: draggedNote, targetPosition: targetPosition)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .onAppear {
            if reorderedNotes.isEmpty {
                reorderedNotes = notes
            }
        }
        .onChange(of: notes) { _, newNotes in
            // Update reordered notes when the original notes change
            reorderedNotes = newNotes
        }
        .scrollIndicators(.hidden)
    }
    
    private var displayedNotes: [Note] {
        return reorderedNotes.isEmpty ? notes : reorderedNotes
    }
    
    private func handleNoteMove(draggedNote: Note, targetPosition: CGPoint) {
        // Simple reordering based on significant drag distance
        guard let currentIndex = reorderedNotes.firstIndex(of: draggedNote) else { return }
        
        // If dragged far enough, move to end of list for now (can be enhanced later)
        let dragDistance = sqrt(targetPosition.x * targetPosition.x + targetPosition.y * targetPosition.y)
        if dragDistance > 80 {
            withAnimation(.bouncy(duration: 0.4)) {
                reorderedNotes.remove(at: currentIndex)
                reorderedNotes.append(draggedNote)
            }
        }
    }
}

struct GridNoteCard: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void
    let onFavorite: () -> Void
    let onMoveRequest: (Note, CGPoint) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var noteSize = CGSize(width: 180, height: 140)
    @State private var isResizing = false
    @State private var dragStartLocation = CGPoint.zero
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeActions = false
    @AppStorage("enableSwipeAffordance") private var enableSwipeAffordance = true
    @AppStorage("enableArchiveUndo") private var enableArchiveUndo = true
    @State private var showUndo = false
    @State private var undoWorkItem: DispatchWorkItem?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            if swipeOffset < -50 {
                HStack(spacing: 0) {
                    Spacer()
                    
                    VStack {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        Text("Favorite")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80, height: noteSize.height)
                    .background(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20, corners: [.topRight, .bottomRight])
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
                .frame(width: noteSize.width, height: noteSize.height)
            }
            
            if swipeOffset > 50 {
                HStack(spacing: 0) {
                    VStack {
                        Image(systemName: "archivebox.fill")
                            .font(.title2)
                        Text("Archive")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80, height: noteSize.height)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20, corners: [.topLeft, .bottomLeft])
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                    Spacer()
                }
                .frame(width: noteSize.width, height: noteSize.height)
            }
            
            // Themed glass background container
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .themedGlass(.regular, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    // Subtle adaptive overlay to prevent flat white look
                    LinearGradient(
                        colors: [
                            Color.white.opacity(themeManager.highContrast ? 0.10 : 0.05),
                            Color.black.opacity(themeManager.highContrast ? 0.15 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.overlay)
                    .opacity(themeManager.highContrast ? 0.7 : 0.4)
                )
                .frame(width: noteSize.width, height: noteSize.height)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5) // Enhanced shadow for depth
                .offset(x: swipeOffset)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Circle().fill(.regularMaterial))
                        .padding(6)
                        .opacity(isResizing ? 0.9 : 0.7)
                        .scaleEffect(isResizing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isResizing)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isResizing = true
                                    
                                    // Calculate safe boundaries for note resizing
                                    let screenWidth = UIScreen.main.bounds.width
                                    let screenHeight = UIScreen.main.bounds.height
                                    
                                    // Calculate maximum width: screen width minus padding, with some buffer
                                    let totalPadding: CGFloat = 40  // horizontal padding
                                    let safeBuffer: CGFloat = 20    // Extra buffer to prevent edge clipping
                                    let maxWidth = screenWidth - totalPadding - safeBuffer
                                    let maxHeight = min(280, screenHeight * 0.3)
                                    
                                    let newWidth = max(140, min(maxWidth, noteSize.width + value.translation.width))
                                    let newHeight = max(120, min(maxHeight, noteSize.height + value.translation.height))
                                    
                                    // Smooth resize animation
                                    withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.9)) {
                                        noteSize = CGSize(width: newWidth, height: newHeight)
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
                                        isResizing = false
                                    }
                                }
                        )
                }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(note.title.isEmpty ? "Untitled Note" : note.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 6) {
                        if false { // !note.tasks.isEmpty { // Temporarily disabled
                            ProgressCircle(progress: note.progress)
                                .frame(width: 24, height: 24)
                        }
                        
                        if note.isFavorited {
                            ZStack {
                                if !themeManager.reduceMotion {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [Color.yellow.opacity(0.55), Color.orange.opacity(0.0)],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 28
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                        .blur(radius: 6)
                                        .opacity(0.9)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                Image(systemName: "star.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .font(.system(size: 14, weight: .medium))
                                    .shadow(color: .yellow.opacity(0.5), radius: 4, x: 0, y: 1)
                                    .scaleEffect(themeManager.reduceMotion ? 1 : 1.08)
                                    .animation(themeManager.reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55), value: note.isFavorited)
                            }
                        }
                    }
                }
                
                if let firstImageData = note.attachments.first,
                   let firstType = note.attachmentTypes.first {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .frame(maxHeight: noteSize.height * 0.45)
                        if firstType.contains("gif") {
                            AnimatedGIFView(data: firstImageData)
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: noteSize.height * 0.4)
                                .clipped()
                                .cornerRadius(10)
                        } else if let uiImage = UIImage(data: firstImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: noteSize.height * 0.4)
                                .clipped()
                                .cornerRadius(10)
                        }
                    }
                }
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(5) // note.attachments.isEmpty && note.tags.isEmpty ? 5 : 3) // Temporarily simplified
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .padding(.top, 2)
                } else {
                    Text("No content")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
                
                if false { // !note.tags.isEmpty { // Temporarily disabled
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // ForEach(note.tags, id: \.self) { tag in
                            //     TagView(tag: tag, color: .blue)
                            //         .scaleEffect(0.9)
                            // }
                        }
                    }
                    .frame(maxHeight: 28)
                    .padding(.top, 4)
                }
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: noteSize.width, height: noteSize.height, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                if note.isArchived {
                    Text("Archived")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width - 60, alignment: .leading)  // Hard constraint with left alignment
        .scaleEffect(isDragging ? 1.08 : isResizing ? 1.04 : 1.0)
        .offset(dragOffset)
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 8 : 4)
    .opacity(note.isArchived ? 0.45 : 1.0)
    .saturation(note.isArchived ? 0.4 : 1.0)
    .animation(themeManager.reduceMotion ? nil : .easeInOut(duration: 0.45), value: themeManager.currentTheme)
    .animation(themeManager.reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82), value: noteSize)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.75), value: isDragging)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), value: noteSize)
        .animation(.bouncy(duration: 0.3, extraBounce: 0.1), value: isResizing)
        .onTapGesture {
            HapticManager.shared.noteSelected()
            onTap()
        }
        .contextMenu {
            Button(action: {
                HapticManager.shared.buttonTapped()
                onFavorite()
            }) {
                Label(note.isFavorited ? "Unfavorite" : "Favorite", systemImage: note.isFavorited ? "star.slash" : "star")
            }
            
            Button(role: .destructive, action: {
                HapticManager.shared.noteDeleted()
                onDelete()
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if showSwipeActions { // actively swiping
                        swipeOffset = value.translation.width
                        return
                    }
                    let horizontalPriority = abs(value.translation.width) > abs(value.translation.height) * 1.6
                    if horizontalPriority && isDragging == false && swipeOffset == 0 && !isResizing {
                        showSwipeActions = true
                        swipeOffset = value.translation.width
                        return
                    }
                    guard !showSwipeActions && !isResizing else { return }
                    isDragging = true
                    let rawConstrainedX = value.translation.width * 0.6
                    let constrainedX = max(-10, rawConstrainedX)
                    let constrainedY = value.translation.height * 0.9
                    dragOffset = CGSize(width: constrainedX, height: constrainedY)
                }
                .onEnded { value in
                    if showSwipeActions {
                        withAnimation(.bouncy(duration: 0.35)) {
                            if swipeOffset < -110 {
                                onFavorite(); HapticManager.shared.noteFavorited();
                            } else if swipeOffset > 110 {
                                let wasArchived = note.isArchived
                                note.isArchived = true
                                HapticManager.shared.noteArchived()
                                if enableArchiveUndo {
                                    showUndo = true
                                    undoWorkItem?.cancel()
                                    let work = DispatchWorkItem {
                                        showUndo = false
                                    }
                                    undoWorkItem = work
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
                                }
                                if !wasArchived { HapticManager.shared.success() }
                            }
                            swipeOffset = 0
                            showSwipeActions = false
                        }
                        return
                    }
                    guard !isResizing else { return }
                    isDragging = false
                    let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    if dragDistance > 80 {
                        onMoveRequest(note, CGPoint(x: value.translation.width, y: value.translation.height))
                        HapticManager.shared.noteDropped()
                    }
                    withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.9)) { dragOffset = .zero }
                    if dragDistance > 30 && dragDistance <= 80 { HapticManager.shared.buttonTapped() }
                }
        )
        .overlay(alignment: .top) {
            if enableSwipeAffordance && showSwipeActions {
                HStack {
                    if swipeOffset > 0 { Image(systemName: "archivebox.fill").foregroundStyle(.blue) }
                    Spacer()
                    if swipeOffset < 0 { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                }
                .padding(10)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if showUndo {
                HStack(spacing: 12) {
                    Text("Archived")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Button("Undo") {
                        undoWorkItem?.cancel()
                        note.isArchived = false
                        showUndo = false
                        HapticManager.shared.buttonTapped()
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    SpatialCanvasView(
        notes: [],
        folders: [],
        onTap: { _ in },
        onDelete: { _ in },
        onFavorite: { _ in },
        onFolderTap: nil,
        onFolderDelete: nil,
        onFolderFavorite: nil
    )
    .modelContainer(for: [Note.self, Folder.self], inMemory: true)
}

struct AnimatedGIFView: View {
    let data: Data
    @State private var currentFrame: UIImage?
    @State private var timer: Timer?
    
    var body: some View {
        Group {
            if let currentFrame = currentFrame {
                Image(uiImage: currentFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.regularMaterial)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 1 else {
            // Fallback to static image
            currentFrame = UIImage(data: data)
            return
        }
        
        var frameIndex = 0
        let frameCount = CGImageSourceGetCount(source)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let cgImage = CGImageSourceCreateImageAtIndex(source, frameIndex, nil) {
                currentFrame = UIImage(cgImage: cgImage)
            }
            frameIndex = (frameIndex + 1) % frameCount
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
