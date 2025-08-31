import SwiftUI
import SwiftData

struct GraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    private var nodes: [Note] { allNotes.filter { !$0.isArchived } }
    // Cached computed positions for session
    @State private var computedPositions: [UUID: CGPoint] = [:]
    @State private var needsLayout = true
    @State private var degreeSizing = true
    @State private var showControls = true
    private func position(for index: Int) -> CGPoint {
        let n = nodes[index]
        if n.hasCustomGraphPosition { return CGPoint(x: n.graphPosX, y: n.graphPosY) }
        if let p = computedPositions[n.id] { return p }
        // Fallback radial seed
        let count = max(nodes.count, 1)
        let angle = 2 * Double.pi * Double(index) / Double(count)
        let radius = 160.0 + Double(index % 5) * 18.0
        let p = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        computedPositions[n.id] = p
        return p
    }
    private func runForceLayout(iterations: Int = 250) {
        var pos = computedPositions
        // Initialize
        for (i, note) in nodes.enumerated() where !note.hasCustomGraphPosition { _ = position(for: i) }
        let area: CGFloat = 800 * 800
        let k = sqrt(area / CGFloat(max(nodes.count,1)))
        func repulsive(_ d: CGFloat) -> CGFloat { k * k / max(d, 0.01) }
        func attractive(_ d: CGFloat) -> CGFloat { (d*d)/k }
        for _ in 0..<iterations {
            var disp: [UUID: CGVector] = [:]
            for a in nodes {
                if a.hasCustomGraphPosition { continue }
                var force = CGVector.zero
                let pa = pos[a.id] ?? .zero
                for b in nodes where b.id != a.id {
                    let pb = pos[b.id] ?? .zero
                    let dx = pa.x - pb.x; let dy = pa.y - pb.y
                    let dist = sqrt(dx*dx + dy*dy) + 0.01
                    let rf = repulsive(dist)
                    force.dx += (dx/dist) * rf
                    force.dy += (dy/dist) * rf
                }
                disp[a.id] = force
            }
            // Attractive (edges)
            for a in nodes {
                let pa = pos[a.id] ?? .zero
                for id in a.linkedNoteIDs {
                    guard let b = nodes.first(where: { $0.id == id }) else { continue }
                    let pb = pos[b.id] ?? .zero
                    let dx = pa.x - pb.x; let dy = pa.y - pb.y
                    let dist = sqrt(dx*dx + dy*dy) + 0.01
                    let af = attractive(dist)
                    let vx = (dx/dist) * af
                    let vy = (dy/dist) * af
                    if !a.hasCustomGraphPosition { disp[a.id]!.dx -= vx; disp[a.id]!.dy -= vy }
                    if !b.hasCustomGraphPosition { disp[b.id, default: .zero].dx += vx; disp[b.id, default: .zero].dy += vy }
                }
            }
            // Update positions
            let temp: CGFloat = 0.95
            for a in nodes where !a.hasCustomGraphPosition {
                var pa = pos[a.id] ?? .zero
                let d = disp[a.id] ?? .zero
                let mag = sqrt(d.dx*d.dx + d.dy*d.dy)
                if mag > 0 {
                    pa.x += (d.dx / mag) * min(mag, k) * temp
                    pa.y += (d.dy / mag) * min(mag, k) * temp
                }
                pos[a.id] = pa
            }
        }
        computedPositions = pos
        needsLayout = false
        persistComputedPositions(pos)
    }
    private func persistComputedPositions(_ positions: [UUID: CGPoint]) {
        for n in nodes where !n.hasCustomGraphPosition { if let p = positions[n.id] { n.graphPosX = p.x; n.graphPosY = p.y } }
        try? modelContext.save()
    }
    private func resetCustomPositions() {
        for n in nodes { n.hasCustomGraphPosition = false }
        computedPositions.removeAll(); needsLayout = true; runForceLayout()
    }
    private func relayout() { computedPositions.removeAll(); needsLayout = true; runForceLayout() }
    private func fitToView(size: CGSize) {
        // Compute bounding box of current positions
        var all: [CGPoint] = []
        for (i, n) in nodes.enumerated() { all.append(position(for: i)) }
        guard !all.isEmpty else { return }
        let minX = all.map{ $0.x }.min() ?? 0, maxX = all.map{ $0.x }.max() ?? 0
        let minY = all.map{ $0.y }.min() ?? 0, maxY = all.map{ $0.y }.max() ?? 0
        let width = maxX - minX, height = maxY - minY
        let pad: CGFloat = 80
        let scaleX = (size.width - pad) / max(width, 1)
        let scaleY = (size.height - pad) / max(height, 1)
        let newScale = min(max(scaleX, 0.2), scaleY)
        withAnimation { scale = min(newScale, 2.5); offset = .zero }
    }
    private func degree(for note: Note) -> Int {
        // Degree counts outbound + inbound unique
        var deg: Set<UUID> = Set(note.linkedNoteIDs)
        for n in nodes where n.id != note.id { if n.linkedNoteIDs.contains(note.id) { deg.insert(n.id) } }
        return deg.count
    }
    var body: some View {
    GeometryReader { geo in
            let center = CGPoint(x: geo.size.width/2 + offset.width, y: geo.size.height/2 + offset.height)
            let posMap: [UUID: CGPoint] = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1.id, position(for: $0)) })
            ZStack {
                EdgeLayer(nodes: nodes, positions: posMap, scale: scale, center: center)
                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, note in
                    if let p = posMap[note.id] {
                        let deg = degreeSizing ? degree(for: note) : 0
                        DraggableNode(note: note, point: p, scale: scale, offset: offset, degree: deg) { newP, isFinal in
                            computedPositions[note.id] = newP
                            if isFinal {
                                note.graphPosX = newP.x
                                note.graphPosY = newP.y
                                note.hasCustomGraphPosition = true
                                try? modelContext.save()
                            }
                        }
                    }
                }
                if showControls {
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 8) {
                            Button(action: { withAnimation { degreeSizing.toggle() } }) { Image(systemName: degreeSizing ? "circle.grid.cross" : "circle") }
                            Button(action: { relayout() }) { Image(systemName: "arrow.triangle.2.circlepath") }
                            Button(action: { resetCustomPositions() }) { Image(systemName: "gobackward") }
                            Button(action: { fitToView(size: geo.size) }) { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass") }
                            Button(action: { withAnimation { showControls = false } }) { Image(systemName: "xmark.circle") }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } else {
                    Button(action: { withAnimation { showControls = true } }) { Image(systemName: "slider.horizontal.3") }
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .gesture(MagnificationGesture().onChanged { val in scale = max(0.4, min(2.5, val)) })
            .gesture(DragGesture().onChanged { g in offset = CGSize(width: dragStart.width + g.translation.width, height: dragStart.height + g.translation.height) }.onEnded { _ in dragStart = offset })
            .onAppear { if needsLayout { runForceLayout() } }
        }
        .overlay(alignment: .topLeading) {
            LNHeader(title: "Graph") { EmptyView() }
        }
        .padding(.top, 0)
        .background(LiquidNotesBackground().ignoresSafeArea())
    }
}

private struct EdgeLayer: View {
    let nodes: [Note]
    let positions: [UUID: CGPoint]
    let scale: CGFloat
    let center: CGPoint
    var body: some View {
        Canvas { context, _ in
            for note in nodes {
                guard let p1 = positions[note.id] else { continue }
                for target in note.linkedNoteIDs {
                    guard let p2 = positions[target] else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + p1.x * scale, y: center.y + p1.y * scale))
                    path.addLine(to: CGPoint(x: center.x + p2.x * scale, y: center.y + p2.y * scale))
                    context.stroke(path, with: .color(Color.accentColor.opacity(0.25)), lineWidth: 1)
                }
            }
        }
    }
}

private struct DraggableNode: View {
    let note: Note
    let point: CGPoint
    let scale: CGFloat
    let offset: CGSize
    let degree: Int
    let onMove: (CGPoint, Bool) -> Void
    @State private var dragStart: CGPoint = .zero
    var body: some View {
        VStack(spacing: 4) {
            let base: CGFloat = 18
            let extra = min(CGFloat(degree) * 2.5, 32)
            Circle()
                .fill(note.isFavorited ? Color.yellow : Color.accentColor)
                .frame(width: base + extra, height: base + extra)
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 90)
        }
        .position(x: UIScreen.main.bounds.width/2 + point.x * scale + offset.width, y: UIScreen.main.bounds.height/2 + point.y * scale + offset.height)
        .contentShape(Rectangle())
        .gesture(DragGesture()
            .onChanged { g in
                let new = CGPoint(x: point.x + g.translation.width/scale, y: point.y + g.translation.height/scale)
                onMove(new, false)
            }
            .onEnded { g in
                let new = CGPoint(x: point.x + g.translation.width/scale, y: point.y + g.translation.height/scale)
                onMove(new, true)
            }
        )
        .onTapGesture { NotificationCenter.default.post(name: .lnOpenNoteRequested, object: note.id) }
    }
}

#Preview { GraphView().modelContainer(for: [Note.self]) }