import SwiftUI
import SwiftData
import UIKit

private struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        // Use the max observed size to avoid flicker if children report sequentially
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

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
    let selectionMode: Bool
    @Binding var selectedNoteIDs: Set<UUID>
    let onToggleSelect: (Note) -> Void
    
    @State private var showingContextMenu: Note?
    @State private var reorderedNotes: [Note] = []
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    @State private var lastCanvasOffset: CGSize = .zero
    @State private var showZoomIndicator = false
    @State private var zoomIndicatorTimer: Timer?
    @State private var contentSize: CGSize = .zero
    @State private var viewportSize: CGSize = .zero
    
    @State private var isPinching = false
    @State private var isPanning = false
    @State private var pinchStartScale: CGFloat = 1.0
    @State private var pinchStartOffset: CGSize = .zero
    @State private var pinchAnchorPoint: CGPoint = .zero
    @State private var lastSnappedDetent: CGFloat?
    
    private var noteWidth: CGFloat { 180 }
    private var noteHeight: CGFloat { 140 }
    
    private var gridColumns: [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let totalPadding: CGFloat = 40
        let availableWidth = screenWidth - totalPadding
        let maxNoteWidth = availableWidth - 20
        let minWidth: CGFloat = 140
        return [GridItem(.adaptive(minimum: minWidth, maximum: maxNoteWidth), spacing: 15)]
    }
    // (GridNoteCard moved to file scope below for clarity)

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 18) {
                        ForEach(notes, id: \.id) { note in
                            let _ = note.id // Force capture to avoid observation
                            GridNoteCard(
                                note: note,
                                selectionMode: selectionMode,
                                isSelected: selectedNoteIDs.contains(note.id),
                                onTap: { onTap(note) },
                                onDelete: { onDelete(note) },
                                onFavorite: { onFavorite(note) },
                                onMoveRequest: { movedNote, translation in
                                    let currentZoom = zoomScale
                                    ModelMutationScheduler.shared.schedule {
                                        movedNote.positionX += Float(translation.x / currentZoom)
                                        movedNote.positionY += Float(translation.y / currentZoom)
                                        movedNote.updateModifiedDate()
                                        HapticManager.shared.noteMoved()
                                    }
                                },
                                onToggleSelect: { onToggleSelect(note) }
                            )
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ContentSizeKey.self, value: proxy.size)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scaleEffect(zoomScale, anchor: .center)
                .offset(canvasOffset)
                .gesture(pinchGesture)
                .simultaneousGesture(panGesture)
                .onTapGesture(count: 2) { resetZoom() }
                .onTapGesture(count: 1) {
                    // Dismiss any open action menus when tapping background
                    // This is handled by individual notes, but adding here as fallback
                }
                .onPreferenceChange(ContentSizeKey.self) { size in
                    guard !isPinching else { return }
                    guard size != contentSize else { return }
                    contentSize = size
                }
                .onAppear { viewportSize = geometry.size }
                .onChange(of: geometry.size) { _, newSize in 
                    viewportSize = newSize 
                }
            }
            
            if showZoomIndicator {
                VStack {
                    HStack {
                        Spacer()
                        ZoomIndicator(scale: zoomScale)
                            .padding()
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: zoomScale)
        .animation(.default, value: notes.map(\.id))
    .onDisappear { zoomIndicatorTimer?.invalidate() }
    }
    
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .simultaneously(with: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard let magnification = value.first else { return }
                
                if !isPinching {
                    isPinching = true
                    pinchStartScale = zoomScale
                    pinchStartOffset = canvasOffset
                    if let location = value.second?.startLocation {
                        pinchAnchorPoint = CGPoint(
                            x: location.x - viewportSize.width/2,
                            y: location.y - viewportSize.height/2
                        )
                    }
                }
                
                let newScale = min(max(pinchStartScale * magnification, 0.5), 3.0)
                zoomScale = newScale
                
                let scaleFactor = newScale / pinchStartScale
                let offsetAdjustment = CGSize(
                    width: pinchAnchorPoint.x * (1 - scaleFactor),
                    height: pinchAnchorPoint.y * (1 - scaleFactor)
                )
                
                let proposedOffset = CGSize(
                    width: pinchStartOffset.width + offsetAdjustment.width,
                    height: pinchStartOffset.height + offsetAdjustment.height
                )
                
                canvasOffset = boundedOffset(for: proposedOffset)
                showZoomIndicatorWithTimer()
            }
            .onEnded { _ in
                isPinching = false
                lastCanvasOffset = canvasOffset
                
                let detents: [CGFloat] = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0]
                if let closest = detents.min(by: { abs($0 - zoomScale) < abs($1 - zoomScale) }) {
                    let relativeDistance = abs(closest - zoomScale) / closest
                    if relativeDistance < 0.08 && lastSnappedDetent != closest {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                            zoomScale = closest
                            clampOffsetIfNeeded()
                        }
                        lastSnappedDetent = closest
                        HapticManager.impact(.medium)
                    } else if lastSnappedDetent != zoomScale {
                        lastSnappedDetent = nil
                        HapticManager.impact(.light)
                        clampOffsetIfNeeded()
                    }
                }
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard zoomScale > 1.0, !isPinching else { return }
                
                if !isPanning {
                    isPanning = true
                    let speed = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    if speed > 30 {
                        HapticManager.impact(.light)
                    }
                }
                
                let proposed = CGSize(
                    width: lastCanvasOffset.width + value.translation.width,
                    height: lastCanvasOffset.height + value.translation.height
                )
                canvasOffset = boundedOffset(for: proposed)
            }
            .onEnded { _ in
                isPanning = false
                lastCanvasOffset = canvasOffset
            }
    }

    private func boundedOffset(for proposed: CGSize) -> CGSize {
        guard zoomScale > 1.0 else { return .zero }
        // Effective content size after scaling
        let scaledWidth = contentSize.width * zoomScale
        let scaledHeight = contentSize.height * zoomScale
        let viewWidth = viewportSize.width
        let viewHeight = viewportSize.height
        let horizontalExcess = max(0, (scaledWidth - viewWidth)/2)
        let verticalExcess = max(0, (scaledHeight - viewHeight)/2)
        let clampedX = min(max(proposed.width, -horizontalExcess), horizontalExcess)
        let clampedY = min(max(proposed.height, -verticalExcess), verticalExcess)
        return CGSize(width: clampedX, height: clampedY)
    }

    private func clampOffsetIfNeeded() {
        if zoomScale <= 1.0 {
            canvasOffset = .zero
            lastCanvasOffset = .zero
        } else {
            let bounded = boundedOffset(for: canvasOffset)
            canvasOffset = bounded
            lastCanvasOffset = bounded
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            zoomScale = 1.0
            canvasOffset = .zero
            lastCanvasOffset = .zero
            lastSnappedDetent = 1.0
        }
        HapticManager.shared.buttonTapped()
        showZoomIndicatorWithTimer()
    }
    
    private func zoomToPoint(_ point: CGPoint, scale: CGFloat) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            zoomScale = scale
            
            let scaledPoint = CGPoint(
                x: point.x * scale - viewportSize.width / 2,
                y: point.y * scale - viewportSize.height / 2
            )
            
            canvasOffset = boundedOffset(for: CGSize(width: -scaledPoint.x, height: -scaledPoint.y))
            lastCanvasOffset = canvasOffset
        }
        HapticManager.shared.buttonTapped()
        showZoomIndicatorWithTimer()
    }
    
    private func showZoomIndicatorWithTimer() {
        showZoomIndicator = true
        zoomIndicatorTimer?.invalidate()
        zoomIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showZoomIndicator = false
            }
        }
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
    // Outer canvas scaling is applied globally now

    // Drag / resize state
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var noteSize = CGSize(width: 180, height: 140)
    @State private var showActions = false
    
    private var scaledNoteSize: CGSize { noteSize }
    @State private var isResizing = false
    @State private var initialSize: CGSize = .zero

    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Layout helpers
    private var horizontalPadding: CGFloat { 20 }
    private var verticalPadding: CGFloat { 18 }
    private var showAttachmentPreview: Bool { scaledNoteSize.width >= 170 && scaledNoteSize.height >= 160 }
    private var contentLineLimit: Int { showAttachmentPreview ? 3 : (!note.tags.isEmpty ? 4 : 5) }
    private var displayedTags: [String] {
        guard !note.tags.isEmpty else { return [] }
        let available = max(60, scaledNoteSize.width - horizontalPadding * 2 - 40)
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
            .frame(width: min(scaledNoteSize.width, UIScreen.main.bounds.width - 60), height: scaledNoteSize.height, alignment: .leading)
            .overlay(alignment: .topTrailing) { topRightBadges }
            .overlay(alignment: .bottomTrailing) {
                if showActions && !selectionMode {
                    actionButtons
                }
            }
            .overlay(alignment: .topLeading) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                        .onTapGesture { onToggleSelect() }
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width - 60, alignment: .leading)
        .offset(dragOffset)
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 8 : 4)
        .opacity(note.isArchived ? 0.45 : 1.0)
        .saturation(note.isArchived ? 0.4 : 1.0)
        .animation(themeManager.reduceMotion ? nil : .easeInOut(duration: 0.45), value: themeManager.currentTheme)
        .onTapGesture { 
            if selectionMode { 
                onToggleSelect() 
            } else {
                if showActions {
                    // Dismiss actions on tap
                    withAnimation(.easeOut(duration: 0.2)) { showActions = false }
                } else {
                    HapticManager.shared.noteSelected()
                    onTap()
                }
            }
        }
        // High priority long press for actions menu
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if selectionMode {
                        onToggleSelect()
                    } else {
                        HapticManager.impact(.medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showActions.toggle()
                        }
                    }
                }
        )
        .onAppear {
            let w = CGFloat(note.width)
            let h = CGFloat(note.height)
            if w >= 140, h >= 120 { noteSize = CGSize(width: CGFloat(w), height: CGFloat(h)) }
        }
        .gesture(dragGesture)
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
            .frame(width: min(scaledNoteSize.width, UIScreen.main.bounds.width - 60), height: scaledNoteSize.height)
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
                ModelMutationScheduler.shared.schedule {
                    note.width = Float(noteSize.width)
                    note.height = Float(noteSize.height)
                    note.updateModifiedDate()
                }
            }
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !selectionMode else { return }
                if !isDragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { isDragging = true } }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !selectionMode else { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = .zero; isDragging = false }; return }
                onMoveRequest(note, CGPoint(x: value.translation.width, y: value.translation.height))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    dragOffset = .zero
                    isDragging = false
                }
            }
    }


    @ViewBuilder var noteHeader: some View {
        let hasBadges = note.isFavorited || ((note.tasks?.isEmpty) == false)
    HStack(alignment: .top, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
        .font(.system(size: 17, weight: .semibold))
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
                    .frame(maxHeight: min(scaledNoteSize.height * 0.45, 120))
                Group {
                    if firstType.contains("gif") { AnimatedGIFView(data: firstImageData) }
                    else if let uiImage = UIImage(data: firstImageData) { Image(uiImage: uiImage).resizable() }
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: min(scaledNoteSize.height * 0.4, 100))
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
                .font(.system(size: 14))
                .fontWeight(.regular)
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(contentLineLimit)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .padding(.top, 2)
        } else {
            Text("No content")
                .font(.system(size: 14))
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
                    Button {
                        HapticManager.shared.buttonTapped()
                        ModelMutationScheduler.shared.schedule { note.addTask("New Task") }
                    } label: {
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
    
    @ViewBuilder var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: {
                HapticManager.shared.buttonTapped()
                onFavorite()
                withAnimation(.easeOut(duration: 0.2)) { showActions = false }
            }) {
                Image(systemName: note.isFavorited ? "star.slash" : "star")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Button(action: {
                HapticManager.shared.buttonTapped()
                ModelMutationScheduler.shared.schedule {
                    note.isArchived.toggle()
                    note.updateModifiedDate()
                }
                withAnimation(.easeOut(duration: 0.2)) { showActions = false }
            }) {
                Image(systemName: note.isArchived ? "arrow.uturn.left" : "archivebox")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Button(action: {
                HapticManager.shared.noteDeleted()
                onDelete()
                withAnimation(.easeOut(duration: 0.2)) { showActions = false }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Button(action: {
                HapticManager.shared.buttonTapped()
                NotificationCenter.default.post(name: .requestMoveSingleNote, object: note)
                withAnimation(.easeOut(duration: 0.2)) { showActions = false }
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(8)
        .transition(.scale.combined(with: .opacity))
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

struct ZoomIndicator: View {
    let scale: CGFloat
    
    private var zoomPercentage: Int {
        Int(scale * 100)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: scale > 1 ? "plus.magnifyingglass" : (scale < 1 ? "minus.magnifyingglass" : "magnifyingglass"))
                .font(.system(size: 14, weight: .medium))
            
            Text("\(zoomPercentage)%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
