import CoreGraphics
import Foundation

@main
struct MeteringPointLayoutTest {
    static func main() {
        let containerSize = CGSize(width: 300, height: 480)

        let topPosition = MeteringPointLayout.displayPosition(
            normalizedPoint: CGPoint(x: 0.5, y: 0.0),
            containerSize: containerSize
        )

        precondition(MeteringPointLayout.markerSize == 20)
        precondition(MeteringPointLayout.markerRadius == 10)
        precondition(MeteringPointLayout.selectedGlowSize == 25)
        precondition(topPosition.y >= MeteringPointLayout.markerRadius)

        let topBadgeOffset = MeteringPointLayout.exposureValueBadgeYOffset(
            normalizedY: 0.0,
            containerHeight: containerSize.height
        )

        precondition(topPosition.y + topBadgeOffset >= 12)

        let centerPosition = MeteringPointLayout.displayPosition(
            normalizedPoint: CGPoint(x: 0.5, y: 0.5),
            containerSize: containerSize
        )

        precondition(centerPosition.x == 150)
        precondition(centerPosition.y == 240)
    }
}
