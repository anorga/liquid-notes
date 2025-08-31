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
    // Multi-select support
    let selectionMode: Bool
    @Binding var selectedNoteIDs: Set<UUID>
    let onToggleSelect: (Note) -> Void
    
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
    // (GridNoteCard moved to file scope below for clarity)

    // MARK: - Subviews & gestures
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                ForEach(notes, id: \.id) { note in
                    GridNoteCard(
                        note: note,
                        selectionMode: selectionMode,
                        isSelected: selectedNoteIDs.contains(note.id),
                        onTap: { onTap(note) },
                        onDelete: { onDelete(note) },
                        onFavorite: { onFavorite(note) },
                        onMoveRequest: { movedNote, translation in
                            // Basic spatial move: update stored position using translation delta
                            movedNote.positionX += Float(translation.x)
                            movedNote.positionY += Float(translation.y)
                            movedNote.updateModifiedDate()
                            HapticManager.shared.noteMoved()
                        },
                        onToggleSelect: { onToggleSelect(note) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .animation(.default, value: notes.map(\.id))
    }
}

// MARK: - Backwards-compatible convenience initializer (non-colliding)
extension SpatialCanvasView {
    init(
        notes: [Note],
        onTap: @escaping (Note) -> Void,
        onDelete: @escaping (Note) -> Void,
        onFavorite: @escaping (Note) -> Void,
        selectionMode: Bool = false,
        selectedNoteIDs: Binding<Set<UUID>> = .constant([]),
        onToggleSelect: @escaping (Note) -> Void = { _ in }
    ) {
        self.notes = notes
        self.folders = []
        self.onTap = onTap
        self.onDelete = onDelete
        self.onFavorite = onFavorite
        self.onFolderTap = nil
        self.onFolderDelete = nil
        self.onFolderFavorite = nil
        self.selectionMode = selectionMode
        self._selectedNoteIDs = selectedNoteIDs
        self.onToggleSelect = onToggleSelect
    }
}

// MARK: - GridNoteCard (top-level)
private struct GridNoteCard: View {
    let note: Note
    let selectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onFavorite: () -> Void
    let onMoveRequest: (Note, CGPoint) -> Void
    let onToggleSelect: () -> Void

    // Drag / resize state
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var noteSize = CGSize(width: 180, height: 140)
    @State private var isResizing = false
    @State private var initialSize: CGSize = .zero

    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Layout helpers
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
    private var showAttachmentPreview: Bool { noteSize.width >= 170 && noteSize.height >= 160 }
    private var contentLineLimit: Int { showAttachmentPreview ? 3 : (!note.tags.isEmpty ? 4 : 5) }
    private var displayedTags: [String] {
        guard !note.tags.isEmpty else { return [] }
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
            glassCard.overlay(alignment: .bottomTrailing) { resizeHandle }
            VStack(alignment: .leading, spacing: 10) {
                noteHeader
                attachmentPreviewView
                contentView
                tagsRow
                Spacer(minLength: 8)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: min(noteSize.width, UIScreen.main.bounds.width - 60), height: noteSize.height, alignment: .leading)
            .overlay(alignment: .topTrailing) { topRightBadges }
            .overlay(alignment: .topLeading) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                        .onTapGesture { onToggleSelect() }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width - 60, alignment: .leading)
        .scaleEffect(isDragging ? 1.08 : (isResizing ? 1.04 : 1.0))
        .offset(dragOffset)
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 8 : 4)
        .opacity(note.isArchived ? 0.45 : 1.0)
        .saturation(note.isArchived ? 0.4 : 1.0)
        .animation(themeManager.reduceMotion ? nil : .easeInOut(duration: 0.45), value: themeManager.currentTheme)
        .onTapGesture { if selectionMode { onToggleSelect() } else { HapticManager.shared.noteSelected(); onTap() } }
        .onLongPressGesture(minimumDuration: 0.35) { if !selectionMode { onToggleSelect() } }
        .onAppear {
            let w = CGFloat(note.width)
            let h = CGFloat(note.height)
            if w >= 140, h >= 120 { noteSize = CGSize(width: CGFloat(w), height: CGFloat(h)) }
        }
        .gesture(dragGesture)
        .contextMenu { contextMenuContent }
        .draggable(note.id.uuidString)
    }
}

// MARK: Subviews & gestures for GridNoteCard
private extension GridNoteCard {
    var glassCard: some View {
        let corner: CGFloat = 26
        let base = RoundedRectangle(cornerRadius: corner, style: .continuous)
        // Use themedGlass as available in ThemeManager extensions
        return base
            .fill(Color.clear)
            .overlay(
                AnyView(
                    EmptyView()
                        .themedGlassCard()
                )
            )
            .clipShape(base)
            .frame(width: min(noteSize.width, UIScreen.main.bounds.width - 60), height: noteSize.height)
            .shadow(color: .black.opacity(themeManager.minimalMode ? 0.08 : 0.16), radius: themeManager.minimalMode ? 6 : 12, x: 0, y: themeManager.minimalMode ? 3 : 5)
            .shadow(color: (ThemeManager.shared.currentTheme.primaryGradient.first ?? .clear).opacity(themeManager.minimalMode ? 0.04 : 0.1), radius: themeManager.minimalMode ? 18 : 32, x: 0, y: themeManager.minimalMode ? 10 : 20)
    }

    var resizeHandle: some View {
        ZStack {
            Rectangle().fill(Color.clear).frame(width: 52, height: 52).contentShape(Rectangle())
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
                withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.88)) { noteSize = CGSize(width: newWidth, height: newHeight) }
            }
            .onEnded { _ in
                withAnimation(.bouncy(duration: 0.32, extraBounce: 0.08)) { isResizing = false }
                note.width = Float(noteSize.width)
                note.height = Float(noteSize.height)
                note.updateModifiedDate()
            }
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !isDragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { isDragging = true } }
                dragOffset = value.translation
            }
            .onEnded { value in
                onMoveRequest(note, CGPoint(x: value.translation.width, y: value.translation.height))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    dragOffset = .zero
                    isDragging = false
                }
            }
    }

    var contextMenuContent: some View {
        Group {
            Button(action: { HapticManager.shared.buttonTapped(); onFavorite() }) {
                Label(note.isFavorited ? "Unfavorite" : "Favorite", systemImage: note.isFavorited ? "star.slash" : "star")
            }
            Menu("More…") {
                Button(action: { HapticManager.shared.buttonTapped(); note.isArchived.toggle(); note.updateModifiedDate() }) {
                    Label(note.isArchived ? "Restore" : "Archive", systemImage: note.isArchived ? "arrow.uturn.left" : "archivebox")
                }
                Button(role: .destructive, action: { HapticManager.shared.noteDeleted(); onDelete() }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder var noteHeader: some View {
        let hasBadges = note.isFavorited || ((note.tasks?.isEmpty) == false)
        HStack(alignment: .top, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.trailing, hasBadges ? 60 : 0)
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder var attachmentPreviewView: some View {
        if showAttachmentPreview, let firstImageData = note.attachments.first, let firstType = note.attachmentTypes.first {
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
                    .overlay(Capsule().stroke(Color.white.opacity(allDone ? 0.35 : 0.22), lineWidth: 0.6))
                    .foregroundStyle(allDone ? .white : .primary.opacity(0.85))
                    .shadow(color: allDone ? Color.green.opacity(0.25) : .clear, radius: allDone ? 6 : 0, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Text(allDone ? "All tasks complete" : "\(incomplete) incomplete of \(tasks.count) tasks"))
                }
                if (note.tasks?.isEmpty ?? true) {
                    Button { HapticManager.shared.buttonTapped(); note.addTask("New Task") } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                if !(note.tasks?.isEmpty ?? true) {
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: note.progress)
                            .stroke(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)
                    .animation(.easeInOut(duration: 0.3), value: note.progress)
                    .accessibilityLabel(Text("Progress \(Int(note.progress * 100)) percent"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
    struct PreviewHost: View {
        @State private var selected: Set<UUID> = []

        var body: some View {
            SpatialCanvasView(
                notes: [],
                folders: [],
                onTap: { _ in },
                onDelete: { _ in },
                onFavorite: { _ in },
                onFolderTap: nil,
                onFolderDelete: nil,
                onFolderFavorite: nil,
                selectionMode: false,
                selectedNoteIDs: $selected,
                onToggleSelect: { _ in }
            )
            .modelContainer(for: [Note.self, Folder.self], inMemory: true)
        }
    }
    return PreviewHost()
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

// Parallax modifier removed (simplified per feedback)
