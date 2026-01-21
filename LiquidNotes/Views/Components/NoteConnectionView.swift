import SwiftUI

struct NoteConnectionsView: View {
    let notes: [Note]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            for note in notes {
                let linkedIDs = note.linkedNoteIDs
                guard !linkedIDs.isEmpty else { continue }

                let startCenter = CGPoint(
                    x: CGFloat(note.positionX) + offset.x + cardWidth / 2,
                    y: CGFloat(note.positionY) + offset.y + cardHeight / 2
                )

                for linkedIDString in linkedIDs {
                    guard let linkedNote = notes.first(where: { $0.id.uuidString == linkedIDString }) else { continue }

                    let endCenter = CGPoint(
                        x: CGFloat(linkedNote.positionX) + offset.x + cardWidth / 2,
                        y: CGFloat(linkedNote.positionY) + offset.y + cardHeight / 2
                    )

                    let path = createConnectionPath(from: startCenter, to: endCenter)

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [Color.blue.opacity(0.4), Color.cyan.opacity(0.4)]),
                            startPoint: startCenter,
                            endPoint: endCenter
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3])
                    )

                    let arrowPath = createArrowHead(at: endCenter, from: startCenter)
                    context.fill(arrowPath, with: .color(Color.cyan.opacity(0.5)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func createConnectionPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let controlOffset = min(abs(dx), abs(dy)) * 0.3

        let control1 = CGPoint(
            x: start.x + dx * 0.25,
            y: start.y + controlOffset * (dy > 0 ? 1 : -1)
        )
        let control2 = CGPoint(
            x: end.x - dx * 0.25,
            y: end.y - controlOffset * (dy > 0 ? 1 : -1)
        )

        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }

    private func createArrowHead(at point: CGPoint, from origin: CGPoint) -> Path {
        let angle = atan2(point.y - origin.y, point.x - origin.x)
        let arrowSize: CGFloat = 8

        var path = Path()
        let p1 = CGPoint(
            x: point.x - arrowSize * cos(angle - .pi / 6),
            y: point.y - arrowSize * sin(angle - .pi / 6)
        )
        let p2 = CGPoint(
            x: point.x - arrowSize * cos(angle + .pi / 6),
            y: point.y - arrowSize * sin(angle + .pi / 6)
        )

        path.move(to: point)
        path.addLine(to: p1)
        path.addLine(to: p2)
        path.closeSubpath()

        return path
    }
}

struct SingleNoteConnectionView: View {
    let fromNote: Note
    let toNote: Note
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let startCenter = CGPoint(
                x: CGFloat(fromNote.positionX) + cardWidth / 2,
                y: CGFloat(fromNote.positionY) + cardHeight / 2
            )
            let endCenter = CGPoint(
                x: CGFloat(toNote.positionX) + cardWidth / 2,
                y: CGFloat(toNote.positionY) + cardHeight / 2
            )

            Path { path in
                path.move(to: startCenter)
                let midX = (startCenter.x + endCenter.x) / 2
                let midY = (startCenter.y + endCenter.y) / 2
                let controlOffset = abs(startCenter.y - endCenter.y) * 0.3
                path.addQuadCurve(
                    to: endCenter,
                    control: CGPoint(x: midX, y: midY - controlOffset)
                )
            }
            .stroke(
                LinearGradient(
                    colors: [.blue.opacity(0.5), .cyan.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3])
            )
        }
        .allowsHitTesting(false)
    }
}
