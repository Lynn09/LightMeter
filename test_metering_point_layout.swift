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

        precondition(topPosition.y >= 20)

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
