import SwiftUI

/// Wraps subviews left-to-right, breaking to a new row when the current row
/// runs out of horizontal space. Used by the cloze picker so token chips flow
/// across multiple lines on a manga sentence.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let projectedWidth = rowWidth + size.width + (rows[rows.count - 1].isEmpty ? 0 : spacing)
            if projectedWidth > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += currentRowHeight + lineSpacing
                rows.append([])
                rowWidth = 0
                currentRowHeight = 0
            }
            rows[rows.count - 1].append(size)
            rowWidth += size.width + (rows[rows.count - 1].count == 1 ? 0 : spacing)
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + lineSpacing
                currentRowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
            _ = maxWidth // silence unused warning under -Wunused
        }
    }
}
