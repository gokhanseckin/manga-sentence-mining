import CoreGraphics

/// Approximates manga reading order: right-to-left, top-to-bottom.
/// Uses a vertical-band tolerance so right-aligned regions at similar heights
/// aren't reordered by tiny y differences.
struct ReadingOrder {
    /// Tolerance as a fraction of image height. Two regions whose vertical
    /// midpoints lie within `bandFraction * imageHeight` of each other are
    /// considered "same band" and ordered by maxX (right-most first).
    var bandFraction: CGFloat = 0.05

    func sort(_ regions: [CGRect], imageHeight: CGFloat) -> [CGRect] {
        let band = max(8, imageHeight * bandFraction)
        return regions.sorted { a, b in
            let dy = abs(a.midY - b.midY)
            if dy < band {
                return a.maxX > b.maxX
            }
            return a.minY < b.minY
        }
    }
}
