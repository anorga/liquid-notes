import SwiftUI

struct CanvasMinimap: View {
    let notes: [Note]
    let canvasBounds: CGRect
    let viewportSize: CGSize
    let zoomScale: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private let minimapWidth: CGFloat = 120
    private let minimapHeight: CGFloat = 80

    private var scale: CGFloat {
        let scaleX = minimapWidth / canvasBounds.width
        let scaleY = minimapHeight / canvasBounds.height
        return min(scaleX, scaleY)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )

            Canvas { context, size in
                for note in notes {
                    let x = (CGFloat(note.positionX) - canvasBounds.minX) * scale
                    let y = (CGFloat(note.positionY) - canvasBounds.minY) * scale
                    let w = cardWidth * scale
                    let h = cardHeight * scale

                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    let roundedRect = RoundedRectangle(cornerRadius: 2, style: .continuous).path(in: rect)

                    if note.isFavorited {
                        context.fill(roundedRect, with: .color(Color.yellow.opacity(0.7)))
                    } else {
                        context.fill(roundedRect, with: .color(Color.blue.opacity(0.5)))
                    }
                    context.stroke(roundedRect, with: .color(Color.white.opacity(0.3)), lineWidth: 0.5)
                }

                let viewportWidth = viewportSize.width / zoomScale * scale
                let viewportHeight = viewportSize.height / zoomScale * scale
                let viewportRect = CGRect(
                    x: 4,
                    y: 4,
                    width: min(viewportWidth, minimapWidth - 8),
                    height: min(viewportHeight, minimapHeight - 8)
                )
                let viewportPath = RoundedRectangle(cornerRadius: 2, style: .continuous).path(in: viewportRect)
                context.stroke(viewportPath, with: .color(Color.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1))
            }
            .frame(width: minimapWidth, height: minimapHeight)
        }
        .frame(width: minimapWidth, height: minimapHeight)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct CanvasMinimapInteractive: View {
    let notes: [Note]
    let canvasBounds: CGRect
    @Binding var viewportOffset: CGPoint
    let viewportSize: CGSize
    let zoomScale: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private let minimapWidth: CGFloat = 120
    private let minimapHeight: CGFloat = 80

    private var scale: CGFloat {
        let scaleX = minimapWidth / canvasBounds.width
        let scaleY = minimapHeight / canvasBounds.height
        return min(scaleX, scaleY)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )

            Canvas { context, size in
                for note in notes {
                    let x = (CGFloat(note.positionX) - canvasBounds.minX) * scale
                    let y = (CGFloat(note.positionY) - canvasBounds.minY) * scale
                    let w = cardWidth * scale
                    let h = cardHeight * scale

                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    let roundedRect = RoundedRectangle(cornerRadius: 2, style: .continuous).path(in: rect)

                    if note.isFavorited {
                        context.fill(roundedRect, with: .color(Color.yellow.opacity(0.7)))
                    } else {
                        context.fill(roundedRect, with: .color(Color.blue.opacity(0.5)))
                    }
                }
            }
            .frame(width: minimapWidth, height: minimapHeight)

            let viewportWidth = viewportSize.width / zoomScale * scale
            let viewportHeight = viewportSize.height / zoomScale * scale
            let viewportX = (viewportOffset.x - canvasBounds.minX) * scale
            let viewportY = (viewportOffset.y - canvasBounds.minY) * scale

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: viewportWidth, height: viewportHeight)
                .position(x: viewportX + viewportWidth / 2, y: viewportY + viewportHeight / 2)
        }
        .frame(width: minimapWidth, height: minimapHeight)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let tapX = value.location.x / scale + canvasBounds.minX
                    let tapY = value.location.y / scale + canvasBounds.minY
                    viewportOffset = CGPoint(x: tapX, y: tapY)
                    HapticManager.shared.buttonTapped()
                }
        )
    }
}
