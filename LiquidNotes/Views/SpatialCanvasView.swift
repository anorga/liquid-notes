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
            NotesFlowGrid(
                notes: displayedNotes,
                onTap: onTap,
                onDelete: onDelete,
                onFavorite: onFavorite,
                onMoveRequest: handleNoteMove
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .onAppear { if reorderedNotes.isEmpty { reorderedNotes = notes } }
        .onChange(of: notes) { _, newNotes in reorderedNotes = newNotes }
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

// MARK: - Extracted Flow Grid to reduce type-check complexity in main view body
private struct NotesFlowGrid: View {
    let notes: [Note]
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onFavorite: (Note) -> Void
    let onMoveRequest: (Note, CGPoint) -> Void

    var body: some View {
        FlowLayout(horizontalSpacing: 15, verticalSpacing: 15) {
            ForEach(notes, id: \.id) { note in
                GridNoteCard(
                    note: note,
                    onTap: { onTap(note) },
                    onDelete: { onDelete(note) },
                    onFavorite: { onFavorite(note) },
                    onMoveRequest: { dragged, point in onMoveRequest(dragged, point) }
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Note titled \(note.title.isEmpty ? "Untitled" : note.title)"))
                .accessibilityHint(Text("Double tap to open. Swipe horizontally for actions."))
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
    @State private var initialSize: CGSize = .zero // store size at resize gesture start
    @State private var dragStartLocation = CGPoint.zero
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeActions = false
    @AppStorage("enableSwipeAffordance") private var enableSwipeAffordance = true
    @AppStorage("enableArchiveUndo") private var enableArchiveUndo = true
    @State private var showUndo = false
    @State private var undoWorkItem: DispatchWorkItem?
    @ObservedObject private var themeManager = ThemeManager.shared

    // Breakpoint-based padding for consistent interior spacing & to avoid icon overflow on narrow notes
    private var horizontalPadding: CGFloat {
        let w = noteSize.width
        if w <= 155 { return 18 }
        if w <= 185 { return 20 }
        return 22
    }
    private var verticalPadding: CGFloat {
        let h = noteSize.height
        if h <= 145 { return 16 }
        if h <= 180 { return 18 }
        return 20
    }

    // Only show large attachment preview if note is big enough to not crowd title/padding
    private var showAttachmentPreview: Bool {
        noteSize.width >= 170 && noteSize.height >= 160
    }

    private var contentLineLimit: Int {
        if showAttachmentPreview { return 3 }
        if !note.tags.isEmpty { return 4 }
        return 5
    }

    // Tag truncation logic (E): try to fit tags within available width budget
    private var displayedTags: [String] {
        guard !note.tags.isEmpty else { return [] }
        // Rough width estimation: base 20 + 8 per char (capsules) up to available width minus padding and star/archive overlay zone
        let available = max(60, noteSize.width - horizontalPadding * 2 - 40)
        var used: CGFloat = 0
        var result: [String] = []
        for tag in note.tags {
            let est = 28 + CGFloat(tag.count) * 7.0
            if used + est > available { break }
            result.append(tag)
            used += est
        }
        return result
    }
    
    var body: some View {
        ZStack {
            leftSwipeBackground
            rightSwipeBackground
            
            glassCard.overlay(alignment: .bottomTrailing) { resizeHandle }
            
            VStack(alignment: .leading, spacing: 10) {
                noteHeader
                attachmentPreviewView
                contentView
                tagsRow
                Spacer(minLength: 8)
            }
            // Dynamic internal padding for clearer content breathing room without overflow
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: min(noteSize.width, UIScreen.main.bounds.width - 60), height: noteSize.height, alignment: .leading)
            .overlay(alignment: .topTrailing) { topRightBadges }
        }
    .frame(maxWidth: UIScreen.main.bounds.width - 60, alignment: .leading)
        .scaleEffect(isDragging ? 1.08 : isResizing ? 1.04 : 1.0)
        .offset(dragOffset)
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 8 : 4)
    .opacity(note.isArchived ? 0.45 : 1.0)
    .saturation(note.isArchived ? 0.4 : 1.0)
    .animation(themeManager.reduceMotion ? nil : .easeInOut(duration: 0.45), value: themeManager.currentTheme)
    // Explicit animations handled in gesture bodies for resizing
        .onTapGesture {
            HapticManager.shared.noteSelected()
            onTap()
        }
        .onAppear {
            // Initialize with persisted size if available
            let persistedWidth = CGFloat(note.width)
            let persistedHeight = CGFloat(note.height)
            if persistedWidth >= 140, persistedHeight >= 120 { noteSize = CGSize(width: persistedWidth, height: persistedHeight) }
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard !isResizing else { return } // ignore when resizing
                    if showSwipeActions { swipeOffset = value.translation.width; return }
                    let horizontalPriority = abs(value.translation.width) > abs(value.translation.height) * 1.6
                    if horizontalPriority && !isDragging && swipeOffset == 0 {
                        showSwipeActions = true
                        swipeOffset = value.translation.width
                        return
                    }
                    guard !showSwipeActions else { return }
                    if !isDragging { isDragging = true }
                    let smoothing: CGFloat = 0.55
                    let constrainedX = max(-12, value.translation.width * smoothing)
                    let constrainedY = value.translation.height * 0.85
                    dragOffset = CGSize(
                        width: dragOffset.width * 0.35 + constrainedX * 0.65,
                        height: dragOffset.height * 0.35 + constrainedY * 0.65
                    )
                }
                .onEnded { value in
                    guard !isResizing else { return }
                    if showSwipeActions {
                        withAnimation(.bouncy(duration: 0.35)) {
                            if swipeOffset < -110 { onFavorite(); HapticManager.shared.noteFavorited() }
                            else if swipeOffset > 110 {
                                let wasArchived = note.isArchived
                                note.isArchived = true
                                HapticManager.shared.noteArchived()
                                if enableArchiveUndo {
                                    showUndo = true
                                    undoWorkItem?.cancel()
                                    let work = DispatchWorkItem { showUndo = false }
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
                    isDragging = false
                    let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    if dragDistance > 80 {
                        onMoveRequest(note, CGPoint(x: value.translation.width, y: value.translation.height))
                        HapticManager.shared.noteDropped()
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragOffset = .zero }
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
    // Debug build marker removed
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

private extension GridNoteCard {
    var leftSwipeBackground: some View {
        Group {
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
                        LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20, corners: [.topRight, .bottomRight])
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
                .frame(width: noteSize.width, height: noteSize.height)
            }
        }
    }

    var rightSwipeBackground: some View {
        Group {
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
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        }
    }
    // Extracted glass card to reduce type-check complexity.
    var glassCard: some View {
        let corner: CGFloat = themeManager.noteStyle == 0 ? 20 : 34
        let base = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let glass = Color.clear.refinedClearGlass(
            cornerRadius: corner,
            intensity: themeManager.noteGlassDepth * (themeManager.noteStyle == 0 ? 1.0 : 1.08)
        )
        let firstShadowColor = Color.black.opacity(
            themeManager.minimalMode ? 0.08 : (themeManager.noteStyle == 0 ? 0.15 : 0.18)
        )
        let secondShadowColor = (ThemeManager.shared.currentTheme.primaryGradient.first ?? .clear).opacity(
            themeManager.minimalMode ? 0.04 : (themeManager.noteStyle == 0 ? 0.08 : 0.12)
        )
        let widthCap = min(noteSize.width, UIScreen.main.bounds.width - 60)
        return base.fill(Color.clear)
            .overlay(glass)
            .clipShape(base)
            .frame(width: widthCap, height: noteSize.height)
            .shadow(color: firstShadowColor,
                    radius: themeManager.minimalMode ? 6 : (themeManager.noteStyle == 0 ? 10 : 14),
                    x: 0, y: themeManager.minimalMode ? 3 : 5)
            .shadow(color: secondShadowColor,
                    radius: themeManager.minimalMode ? 18 : (themeManager.noteStyle == 0 ? 28 : 36),
                    x: 0, y: themeManager.minimalMode ? 10 : (themeManager.noteStyle == 0 ? 18 : 22))
            .offset(x: swipeOffset)
            .modifier(ParallaxIfEnabled(enabled: themeManager.noteParallax && !themeManager.reduceMotion))
    }

    var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
            Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Circle().fill(.regularMaterial))
                .opacity(isResizing ? 0.95 : 0.7)
                .scaleEffect(isResizing ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isResizing)
        }
        .padding(2)
        .highPriorityGesture(resizeDragGesture)
    }

    var resizeDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    initialSize = noteSize
                }
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                let totalPadding: CGFloat = 40
                let safeBuffer: CGFloat = 20
                let maxWidth = screenWidth - totalPadding - safeBuffer
                let maxHeight = min(320, screenHeight * 0.35)
                let proposedWidth = initialSize.width + value.translation.width
                let proposedHeight = initialSize.height + value.translation.height
                let newWidth = max(140, min(maxWidth, proposedWidth))
                let newHeight = max(120, min(maxHeight, proposedHeight))
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.88)) {
                    noteSize = CGSize(width: newWidth, height: newHeight)
                }
            }
            .onEnded { _ in
                withAnimation(.bouncy(duration: 0.32, extraBounce: 0.08)) { isResizing = false }
                note.width = Float(noteSize.width)
                note.height = Float(noteSize.height)
                note.updateModifiedDate()
            }
    }
}

// MARK: - Extracted subviews for readability & compiler performance
private extension GridNoteCard {
    @ViewBuilder var noteHeader: some View {
        let hasBadges = note.isFavorited || ((note.tasks?.isEmpty) == false)
        // Reserve horizontal space on the right so overlay badges don't collide with the title text.
        HStack(alignment: .top, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.trailing, hasBadges ? 60 : 0) // space for star + task badge row
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder var attachmentPreviewView: some View {
        if showAttachmentPreview,
           let firstImageData = note.attachments.first,
           let firstType = note.attachmentTypes.first {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .frame(maxHeight: min(noteSize.height * 0.45, 120))
                Group {
                    if firstType.contains("gif") { AnimatedGIFView(data: firstImageData) }
                    else if let uiImage = UIImage(data: firstImageData) { Image(uiImage: uiImage).resizable() }
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: min(noteSize.height * 0.4, 100))
                .clipped()
                .cornerRadius(10)
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    .blendMode(.overlay)
                    .cornerRadius(10)
            }
        }
    }

    @ViewBuilder var contentView: some View {
        if !note.content.isEmpty {
            Text(note.content)
                .font(.callout)
                .fontWeight(.regular)
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(contentLineLimit)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .padding(.top, 2)
        } else {
            Text("No content")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .italic()
        }
    }

    @ViewBuilder var tagsRow: some View {
        if !note.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(displayedTags, id: \.self) { tag in
                        TagView(tag: tag, color: .blue)
                            .scaleEffect(0.85)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxHeight: 26)
            .padding(.top, 2)
        }
    }

    @ViewBuilder var topRightBadges: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // First row: favorite + tasks (horizontal alignment)
            HStack(spacing: 6) {
                if note.isFavorited {
                    Image(systemName: "star.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(6)
                        .background(Circle().fill(.ultraThinMaterial))
                        .clipShape(Circle())
                        .transition(.scale.combined(with: .opacity))
                }
                if let tasks = note.tasks, !tasks.isEmpty {
                    let incomplete = tasks.filter { !$0.isCompleted }.count
                    let allDone = incomplete == 0
                    HStack(spacing: 4) {
                        Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                            .font(.system(size: 11, weight: .semibold))
                        Text(allDone ? "Done" : "\(incomplete)/\(tasks.count)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            allDone ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(allDone ? 0.35 : 0.22), lineWidth: 0.6)
                    )
                    .foregroundStyle(allDone ? .white : .primary.opacity(0.85))
                    .shadow(color: allDone ? Color.green.opacity(0.25) : .clear, radius: allDone ? 6 : 0, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Text(allDone ? "All tasks complete" : "\(incomplete) incomplete of \(tasks.count) tasks"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            // Second row (optional icons) placed below
            if !showAttachmentPreview && !note.attachments.isEmpty {
                Image(systemName: "paperclip")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Circle().fill(.ultraThinMaterial))
                    .clipShape(Circle())
                    .transition(.opacity.combined(with: .scale))
                    .onTapGesture { onTap() }
            }
            if note.isArchived {
                Text("Archived")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(6)
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

// Helper modifier to conditionally apply subtle parallax
private struct ParallaxIfEnabled: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.subtleParallax(.shared, maxOffset: 4)
        } else { content }
    }
}
