import CoreGraphics
import Foundation

/// Groups individual line/column boxes from Vision into bubble-sized regions.
///
/// **Why this exists:** `VNDetectTextRectanglesRequest` returns one box per
/// horizontal line (or per vertical column after our 90° rotation pass). For
/// vertical Japanese in a manga bubble that's one box per column, but
/// manga-ocr was trained on bubble-sized crops — it reads a single column
/// reasonably well but tends to hallucinate text at the end. Feeding it the
/// full bubble crop produces cleaner output and one sentence per bubble
/// instead of one per column that we'd then have to splice.
///
/// **Algorithm:** dilate each region by a fraction of its short dimension on
/// every side, then iteratively union any pair of dilated regions that
/// overlap. Adjacent columns inside the same bubble merge (their gap is
/// smaller than a column width). Columns from different bubbles stay
/// separate (their gap is larger). Same logic works in reverse for stacked
/// horizontal lines that belong to the same caption/sign.
struct RegionMerger {
    /// Multiplier on each region's short dimension used for dilation. A column
    /// with width 50px gets expanded by 50*dilateShortRatio on left and right;
    /// the same scaling on top/bottom for tall horizontal strips.
    var dilateShortRatio: CGFloat = 1.2

    func merge(_ regions: [CGRect]) -> [CGRect] {
        guard regions.count > 1 else { return regions }
        var groups: [[CGRect]] = regions.map { [$0] }

        func unionOf(_ rs: [CGRect]) -> CGRect {
            rs.reduce(CGRect.null) { $0.union($1) }
        }
        func dilated(_ r: CGRect) -> CGRect {
            let short = min(r.width, r.height)
            let pad = short * dilateShortRatio
            return r.insetBy(dx: -pad, dy: -pad)
        }

        var changed = true
        while changed {
            changed = false
            outer: for i in 0..<groups.count {
                for j in (i + 1)..<groups.count {
                    let di = dilated(unionOf(groups[i]))
                    let dj = dilated(unionOf(groups[j]))
                    if di.intersects(dj) {
                        groups[i].append(contentsOf: groups[j])
                        groups.remove(at: j)
                        changed = true
                        break outer
                    }
                }
            }
        }
        return groups.map(unionOf).map { $0.integral }
    }
}
