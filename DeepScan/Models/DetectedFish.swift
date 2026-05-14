import CoreGraphics
import Foundation

// One bounding box returned by the detector. Coordinates are stored in
// UIImage / SwiftUI convention (top-left origin, normalized 0...1) so the
// view layer can place overlays without doing any further math.
struct DetectedFish: Identifiable, Hashable {
    let id = UUID()
    let boundingBox: CGRect
    let confidence: Double

    var area: CGFloat { boundingBox.width * boundingBox.height }
}
