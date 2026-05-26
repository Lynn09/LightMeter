import CoreGraphics
import Foundation

@main
struct StaticFrameOrientationTest {
    static func main() {
        let portraitSize = StaticFramePreviewGeometry.displaySize(
            forPixelWidth: 1920,
            height: 1080,
            orientation: .portrait
        )

        precondition(portraitSize.width == 1080)
        precondition(portraitSize.height == 1920)

        let landscapeSize = StaticFramePreviewGeometry.displaySize(
            forPixelWidth: 1920,
            height: 1080,
            orientation: .landscapeRight
        )

        precondition(landscapeSize.width == 1920)
        precondition(landscapeSize.height == 1080)

        let rawPoint = StaticFramePreviewGeometry.rawPoint(
            forDisplayPoint: CGPoint(x: 0.25, y: 0.75),
            orientation: .portrait
        )

        precondition(abs(rawPoint.x - 0.75) < 0.001)
        precondition(abs(rawPoint.y - 0.75) < 0.001)
    }
}
