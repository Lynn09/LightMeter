import CoreGraphics
import Foundation

@main
struct FocalLengthPreviewTest {
    static func main() {
        precondition(StandardFocalLength.allCases.map(\.millimeters) == [24, 28, 35, 50, 85, 105])

        let scale50 = FocalLengthPreviewGeometry.previewScale(
            currentEquivalentFocalLength: 24,
            selectedFocalLength: .mm50
        )
        precondition(abs(scale50 - (50.0 / 24.0)) < 0.001)

        let scale24 = FocalLengthPreviewGeometry.previewScale(
            currentEquivalentFocalLength: 24,
            selectedFocalLength: .mm24
        )
        precondition(abs(scale24 - 1.0) < 0.001)

        let sourcePoint = FocalLengthPreviewGeometry.sourcePoint(
            forDisplayPoint: CGPoint(x: 0.75, y: 0.5),
            previewScale: 2.0
        )
        precondition(abs(sourcePoint.x - 0.625) < 0.001)
        precondition(abs(sourcePoint.y - 0.5) < 0.001)

        precondition(
            FocalLengthPreviewGeometry.isWiderThanCurrentLens(
                currentEquivalentFocalLength: 28,
                selectedFocalLength: .mm24
            )
        )
    }
}
