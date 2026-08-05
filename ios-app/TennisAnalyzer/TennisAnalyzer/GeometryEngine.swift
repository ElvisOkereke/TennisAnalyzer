import CoreGraphics
import Foundation

/// Pure geometry math for serve mechanics metrics.
///
/// Mirrors `python/tennis_analyzer/geometry.py`, which was prototyped and
/// unit-tested first per the playbook's Python-before-Swift workflow.
enum GeometryEngine {
    /// Angle in degrees at vertex `b`, between rays b->a and b->c.
    ///
    /// Points are in image-pixel space. Returns 0 for degenerate input
    /// (a or c coincident with b).
    static func angleAtVertex(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let bax = Double(a.x - b.x)
        let bay = Double(a.y - b.y)
        let bcx = Double(c.x - b.x)
        let bcy = Double(c.y - b.y)

        let magBA = (bax * bax + bay * bay).squareRoot()
        let magBC = (bcx * bcx + bcy * bcy).squareRoot()
        guard magBA != 0, magBC != 0 else { return 0.0 }

        var cosine = (bax * bcx + bay * bcy) / (magBA * magBC)
        cosine = max(-1.0, min(1.0, cosine))
        return acos(cosine) * 180.0 / Double.pi
    }

    /// Contact point height as a fraction of standing body height.
    ///
    /// All points are in image-pixel space, y increasing downward.
    /// Returns 0 if head and foot are at the same height (degenerate).
    static func heightRatio(contact: CGPoint, head: CGPoint, foot: CGPoint) -> Double {
        let bodyHeight = Double(foot.y - head.y)
        guard bodyHeight != 0 else { return 0.0 }
        return Double(foot.y - contact.y) / bodyHeight
    }
}
