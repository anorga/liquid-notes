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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    let topContentInset: CGFloat
    
    @State private var showingContextMenu: Note?
    @State private var reorderedNotes: [Note] = []
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero // vertical only effective now
    @State private var lastCanvasOffset: CGSize = .zero
    @State private var showZoomIndicator = false
    @State private var zoomIndicatorTimer: Timer?
    @State private var contentSize: CGSize = .zero
    @State private var viewportSize: CGSize = .zero
    
    @State private var isPinching = false
    @State private var isPanning = false // legacy, will be phased out
    @State private var pinchStartScale: CGFloat = 1.0
    @State private var pinchStartOffset: CGSize = .zero
    @State private var pinchAnchorPoint: CGPoint = .zero
    @State private var lastSnappedDetent: CGFloat?
    
    // Equal-spacing adaptive layout configuration
    // Slightly tighter gaps to give cards more width
    private let gapSpacing: CGFloat = 12
    private var targetColumns: Int { 
        // Use size class for adaptive layout instead of device type
        horizontalSizeClass == .regular ? 4 : 2 
    }
    @State private var computedCardWidth: CGFloat = 160
    private var cardBaseHeight: CGFloat { 
        // Keep height based on device for consistency, or could also use size class
        horizontalSizeClass == .regular ? 210 : 190 
    }
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 60), spacing: gapSpacing, alignment: .topLeading), count: targetColumns)
    }
    // Removed automatic centering compensation; we now use an explicit top inset passed from parent.
    // (GridNoteCard moved to file scope below for clarity)

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gapSpacing) {
                        ForEach(notes, id: \.id) { note in
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
                                onToggleSelect: { onToggleSelect(note) },
                                cardWidth: computedCardWidth,
                                cardHeight: cardBaseHeight
                            )
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ContentSizeKey.self, value: proxy.size)
                        }
                    )
                    .padding(.horizontal, gapSpacing) // outer gap equals inter-item spacing
                    .padding(.top, topContentInset)
                    .padding(.bottom, 12)
                }
                .scaleEffect(zoomScale, anchor: .center)
                .offset(canvasOffset)
                .gesture(pinchGesture)
                // Horizontal panning removed; retain vertical scroll only
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
                .onAppear {
                    viewportSize = geometry.size
                    recalcCardWidth(totalWidth: geometry.size.width)
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewportSize = newSize
                    recalcCardWidth(totalWidth: newSize.width)
                }
                .onChange(of: horizontalSizeClass) { _, _ in
                    // Recalculate card width when size class changes (iPad window resize)
                    recalcCardWidth(totalWidth: geometry.size.width)
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
    
    // Horizontal pan removed; pinch zoom recenters without custom drag.
    private var panGesture: some Gesture { DragGesture(minimumDistance: .infinity) } // inert placeholder

    private func boundedOffset(for proposed: CGSize) -> CGSize { .zero }

    private func clampOffsetIfNeeded() {
    canvasOffset = .zero
    lastCanvasOffset = .zero
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
    
    private func recalcCardWidth(totalWidth: CGFloat) {
        // Subtract horizontal padding (we used gapSpacing on both sides)
        let inner = totalWidth - (gapSpacing * 2)
        guard inner > 0 else { return }
        // width = (inner - (columns-1)*gap)/columns
        let raw = (inner - CGFloat(targetColumns - 1) * gapSpacing) / CGFloat(targetColumns)
        // Floor to pixel grid for crisp rendering
        let scale = UIScreen.main.scale
        let rounded = floor(raw * scale) / scale
        if abs(rounded - computedCardWidth) > 0.5 { computedCardWidth = rounded }
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
    onToggleSelect: @escaping (Note) -> Void = { _ in },
    topContentInset: CGFloat = 8
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
    self.topContentInset = topContentInset
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
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    // Outer canvas scaling is applied globally now

    // Drag state (resizing removed for uniform layout)
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    // Removed custom long-press overlay actions; using native context menu

    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Layout helpers
    private var horizontalPadding: CGFloat { 14 } // unified edge padding
    private var verticalPadding: CGFloat { 14 }
    private var showAttachmentPreview: Bool { true }
    private var contentLineLimit: Int { 3 }
    // Dynamic adjustments: shrink attachment & content lines if title is long to prevent visual overflow
    private var isLongTitle: Bool { note.title.count > 24 } // tighter threshold for layout adjustments
    private var dynamicAttachmentHeight: CGFloat {
    // Use file-based attachments if present; fallback to legacy
    let hasFile = !note.fileAttachmentIDs.isEmpty
    let hasLegacy = note.attachments.first != nil
    guard showAttachmentPreview, (hasFile || hasLegacy) else { return 0 }
        // Smaller baseline to maintain consistent padding around all elements
        if isLongTitle && !note.content.isEmpty { return 55 }
        return 78
    }
    private var dynamicContentLineLimit: Int {
        // When title is long and attachment present, reduce body lines so layout stays balanced
        if isLongTitle && dynamicAttachmentHeight < 90 { return 2 }
        return contentLineLimit
    }
    private var displayedTags: [String] {
        guard !note.tags.isEmpty else { return [] }
    let available = max(60, cardWidth - horizontalPadding * 2 - 40)
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
            glassCard
            VStack(alignment: .leading, spacing: 6) {
                noteHeader
                contentView
                attachmentPreviewView
                tagsRow
                Spacer(minLength: 2)
                bottomBar
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: cardWidth, height: cardHeight, alignment: .leading)
            // Removed top-right overlay badges; now using bottom bar inside stack
            // Removed custom overlay action buttons
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
    .frame(width: cardWidth, height: cardHeight, alignment: .leading)
        .offset(dragOffset)
        .shadow(color: .black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 8 : 4)
        .opacity(note.isArchived ? 0.45 : 1.0)
        .saturation(note.isArchived ? 0.4 : 1.0)
        .animation(themeManager.reduceMotion ? nil : .easeInOut(duration: 0.45), value: themeManager.currentTheme)
        .onTapGesture { 
            if selectionMode { 
                onToggleSelect() 
            } else {
                HapticManager.shared.noteSelected()
                onTap()
            }
        }
        // Native iOS context menu replacing custom long-press UI
        .contextMenu(menuItems: {
            if !selectionMode {
                Button(action: {
                    HapticManager.shared.buttonTapped()
                    onFavorite()
                }) { Label(note.isFavorited ? "Unfavorite" : "Favorite", systemImage: note.isFavorited ? "star.slash" : "star") }

                Button(action: {
                    HapticManager.shared.buttonTapped()
                    ModelMutationScheduler.shared.schedule {
                        note.isArchived.toggle()
                        note.updateModifiedDate()
                    }
                }) { Label(note.isArchived ? "Unarchive" : "Archive", systemImage: note.isArchived ? "arrow.uturn.left" : "archivebox") }

                Button(action: {
                    HapticManager.shared.buttonTapped()
                    NotificationCenter.default.post(name: .requestMoveSingleNote, object: note)
                }) { Label("Move to Folder", systemImage: "folder") }

                Divider()
                Button(role: .destructive, action: {
                    HapticManager.shared.noteDeleted()
                    onDelete()
                }) { Label("Delete", systemImage: "trash") }
            }
        })
    .onAppear { /* uniform size: ignore persisted custom note.width/height */ }
        .gesture(dragGesture)
    }
}

// MARK: Subviews & gestures for GridNoteCard
private extension GridNoteCard {
    var glassCard: some View {
        let corner: CGFloat = UI.Corner.l
        let base = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let isLight = themeManager.currentTheme == .light
        let isNight = themeManager.currentTheme == .night
        let isMidnight = themeManager.currentTheme == .midnight
        // Neutral base tied to theme background fills (subtle, low color)
        let neutralGradient = LinearGradient(
            colors: themeManager.currentTheme.backgroundGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // Undertone layer brings slight cool hints in Night/Midnight without being too colorful
        let undertoneGradient: LinearGradient? = {
            switch themeManager.currentTheme {
            case .light:
                return nil
            case .night:
                // Cool cyan/blue undertones (no brown cast)
                return LinearGradient(colors: [
                    Color.cyan.opacity(0.20),
                    Color.blue.opacity(0.16)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .midnight:
                // Black-ish undertone (very subtle)
                return LinearGradient(colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.12)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }()
        // Tie strengths to glass intensity so slider affects previews in all themes
        let t = max(0.0, min(1.0, themeManager.glassIntensity))
        // Subtle base range + very gentle undertone range
        let neutralOpacity: Double = {
            let lightRange: ClosedRange<Double> = 0.08...0.24
            let nightRange: ClosedRange<Double> = 0.06...0.20
            let midnightRange: ClosedRange<Double> = 0.06...0.18
            let range = isLight ? lightRange : (isNight ? nightRange : midnightRange)
            return range.lowerBound + t * (range.upperBound - range.lowerBound)
        }()
        let undertoneOpacity: Double = {
            guard undertoneGradient != nil else { return 0 }
            let nightRange: ClosedRange<Double> = 0.03...0.10
            let midnightRange: ClosedRange<Double> = 0.02...0.08
            let range = isNight ? nightRange : midnightRange
            return range.lowerBound + t * (range.upperBound - range.lowerBound)
        }()

        // Build with material above the gradient: apply glass first, then add gradient as background
        return Color.clear
            .frame(width: cardWidth, height: cardHeight)
            .nativeGlassSurface(cornerRadius: corner)
            .background(
                ZStack {
                    base.fill(neutralGradient).opacity(neutralOpacity)
                    if let undertone = undertoneGradient {
                        base.fill(undertone).opacity(undertoneOpacity)
                    }
                }
            )
            .clipShape(base)
            .overlay(
                base.stroke(Color.white.opacity(isMidnight ? 0.22 : 0.18), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)
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
    let isMidnight = themeManager.currentTheme == .midnight
    HStack(alignment: .top, spacing: 6) {
            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                .font(.system(size: isLongTitle ? 15 : 16, weight: .semibold))
                .foregroundStyle(isMidnight ? Color.white : .primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder var attachmentPreviewView: some View {
        if showAttachmentPreview, let previewImage = spatialPreviewImage(for: note) {
            ZStack(alignment: .bottom) {
                // Native glass base behind the preview for edge clarity
                RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(height: dynamicAttachmentHeight)

                // Preview image content
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: dynamicAttachmentHeight)
                    .clipShape(RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous))

                // Native glass reflection highlight (subtle)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .blendMode(.screen)
                .opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous))
                .frame(height: dynamicAttachmentHeight)

                // Bottom gradient for text legibility over image
                if dynamicAttachmentHeight > 0 {
                    LinearGradient(colors: [Color.clear, Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                        .blendMode(.overlay)
                        .clipShape(RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous))
                        .frame(height: dynamicAttachmentHeight)
                }
            }
            // Hairline native border for visibility against varied backgrounds
            .overlay(
                RoundedRectangle(cornerRadius: UI.Corner.s, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            )
        }
    }

    private func spatialPreviewImage(for note: Note) -> UIImage? {
        // Prefer file-based thumbnail if available
        if let firstThumb = note.fileAttachmentThumbNames.first, !firstThumb.isEmpty,
           let dir = AttachmentFileStore.noteDir(noteID: note.id) {
            let url = dir.appendingPathComponent(firstThumb)
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { return img }
        }
        // Fallback: first legacy inline attachment data
        if let data = note.attachments.last, let img = UIImage(data: data) { return img }
        return nil
    }

    @ViewBuilder var contentView: some View {
        let isMidnight = themeManager.currentTheme == .midnight
        if !note.content.isEmpty {
            Text(note.content)
                .font(.system(size: 14))
                .fontWeight(.regular)
                .foregroundStyle(isMidnight ? Color.white.opacity(0.85) : .primary.opacity(0.8))
                .lineLimit(dynamicContentLineLimit)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .padding(.top, 0)
        } else {
            Text("No content")
                .font(.system(size: 14))
                .foregroundStyle(isMidnight ? Color.gray.opacity(0.6) : Color.secondary.opacity(0.6))
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
            .padding(.top, 0)
        }
    }

    // Repositioned icons into a bottom bar instead of top-right overlay
    @ViewBuilder var bottomBar: some View {
        HStack(spacing: 8) {
            if note.isFavorited {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .transition(.scale.combined(with: .opacity))
            }
            if let tasks = note.tasks, !tasks.isEmpty {
                let incomplete = tasks.filter { !$0.isCompleted }.count
                let allDone = incomplete == 0
                let upcoming = tasks.filter { !$0.isCompleted && $0.dueDate != nil }
                    .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                    .first?.dueDate
                let overdueCount = tasks.filter { !$0.isCompleted && ($0.dueDate.map { Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: Date()) } ?? false) }.count
                HStack(spacing: 4) {
                    Image(systemName: allDone ? "checkmark.circle.fill" : "checklist")
                        .font(.system(size: 11, weight: .semibold))
                    Text(allDone ? "Done" : "\(incomplete)/\(tasks.count)")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
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
                if overdueCount == 0, let upcoming = upcoming {
                    let dayString = upcoming.ln_dayDistanceString()
                    Text(dayString)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.22)))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
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
            }
            Spacer(minLength: 0)
            if note.isArchived {
                Text("Archived")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .nativeGlassChip()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 0)
    }
    
}


class GIFAnimator: NSObject {
    private var displayLink: CADisplayLink?
    private var imageSource: CGImageSource?
    private var frameIndex = 0
    private var frameCount = 0
    private var frameDurations: [TimeInterval] = []
    private var lastFrameTime: TimeInterval = 0
    private var currentFrameTime: TimeInterval = 0
    private var onFrameUpdate: ((UIImage?) -> Void)?
    private var isPaused = false
    
    func startAnimation(with data: Data, onFrameUpdate: @escaping (UIImage?) -> Void) {
        self.onFrameUpdate = onFrameUpdate
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 1 else {
            onFrameUpdate(UIImage(data: data))
            return
        }
        
        imageSource = source
        frameCount = CGImageSourceGetCount(source)
        frameDurations = (0..<frameCount).compactMap { index in
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
                  let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
                return 0.1
            }
            
            let duration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval ?? 0.1
            return max(duration, 0.05)
        }
        
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            onFrameUpdate(UIImage(cgImage: cgImage))
        }
        
        let displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        Task { @MainActor in
            let optimizer = PerformanceOptimizer.shared
            displayLink.preferredFramesPerSecond = optimizer.shouldReduceGIFFrameRate ? 5 : 10
        }
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    @objc private func updateFrame() {
        guard !isPaused,
              let imageSource = imageSource,
              frameCount > 0,
              frameDurations.count == frameCount else { return }
        
        let currentTime = CACurrentMediaTime()
        if lastFrameTime == 0 {
            lastFrameTime = currentTime
        }
        
        currentFrameTime += (currentTime - lastFrameTime)
        lastFrameTime = currentTime
        
        let frameDuration = frameDurations[frameIndex]
        
        if currentFrameTime >= frameDuration {
            currentFrameTime = 0
            frameIndex = (frameIndex + 1) % frameCount
            
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, frameIndex, nil) {
                onFrameUpdate?(UIImage(cgImage: cgImage))
            }
        }
    }
    
    func pauseAnimation() {
        isPaused = true
        displayLink?.isPaused = true
    }
    
    func resumeAnimation() {
        isPaused = false
        displayLink?.isPaused = false
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        imageSource = nil
        frameIndex = 0
        frameCount = 0
        frameDurations.removeAll()
        lastFrameTime = 0
        currentFrameTime = 0
        onFrameUpdate = nil
        isPaused = false
    }
}

struct AnimatedGIFView: View {
    let data: Data
    @State private var currentFrame: UIImage?
    @State private var animator = GIFAnimator()
    
    var body: some View {
        Group {
            if let currentFrame = currentFrame {
                Image(uiImage: currentFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.thinMaterial)
            }
        }
        .onAppear {
            animator.startAnimation(with: data) { frame in
                currentFrame = frame
            }
        }
        .onDisappear {
            animator.stopAnimation()
        }
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
        .nativeGlassChip()
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
