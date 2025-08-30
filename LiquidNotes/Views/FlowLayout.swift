import SwiftUI

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 15
    var verticalSpacing: CGFloat = 15
    var alignment: HorizontalAlignment = .leading
    
    struct Cache { var sizes: [CGSize] = [] }
    func makeCache(subviews: Subviews) -> Cache { Cache(sizes: subviews.map { _ in .zero }) }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let availableWidth = (proposal.width ?? UIScreen.main.bounds.width) - 40 // account for outer padding
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        cache.sizes = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            cache.sizes.append(size)
            if x + size.width > availableWidth && x > 0 { // wrap
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
        return CGSize(width: proposal.width ?? availableWidth, height: y + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let availableWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = cache.sizes.indices.contains(index) ? cache.sizes[index] : subview.sizeThatFits(.unspecified)
            if x + size.width > availableWidth && x > 0 { // wrap
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
    }
}

extension FlowLayout {
    init(spacing: CGFloat) { self.horizontalSpacing = spacing; self.verticalSpacing = spacing }
}