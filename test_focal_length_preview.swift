import CoreGraphics
import Foundation

@main
struct FocalLengthPreviewTest {
    static func main() {
        precondition(StandardFocalLength.allCases.map(\.millimeters) == [24, 28, 35, 50, 85, 105])

        let zoom50 = FocalLengthPreviewGeometry.zoomFactor(
            baseEquivalentFocalLength: 24,
            selectedFocalLength: .mm50
        )
        precondition(abs(zoom50 - (50.0 / 24.0)) < 0.001)

        let zoom24 = FocalLengthPreviewGeometry.zoomFactor(
            baseEquivalentFocalLength: 24,
            selectedFocalLength: .mm24
        )
        precondition(abs(zoom24 - 1.0) < 0.001)

        let clampedZoom = FocalLengthPreviewGeometry.clampedZoomFactor(
            5.0,
            minimum: 1.0,
            maximum: 3.0
        )
        precondition(abs(clampedZoom - 3.0) < 0.001)

        precondition(
            FocalLengthPreviewGeometry.isWiderThanCurrentLens(
                baseEquivalentFocalLength: 28,
                selectedFocalLength: .mm24
            )
        )

        let displayName = CameraLensInfo.makeDisplayName(equivalentFocalLength: 49.6)
        precondition(displayName == "手机 50mm")

        precondition(
            FocalLengthDrawerPresentation.visibleFocalLengths(
                isExpanded: false,
                selectedFocalLength: .mm35
            ) == [.mm35]
        )

        precondition(
            FocalLengthDrawerPresentation.visibleFocalLengths(
                isExpanded: true,
                selectedFocalLength: .mm35
            ) == StandardFocalLength.allCases
        )
    }
}
