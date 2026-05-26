import CoreGraphics
import Foundation

@main
struct CameraPreviewLayoutTest {
    static func main() {
        let containerSize = CGSize(width: 300, height: 640)

        let contentSize = CameraPreviewLayout.contentSize(for: containerSize)
        precondition(contentSize.width == 300)
        precondition(contentSize.height == 640)

        let centerPoint = CameraPreviewLayout.normalizedPoint(
            from: CGPoint(x: 150, y: 320),
            in: contentSize
        )

        precondition(abs(centerPoint.x - 0.5) < 0.001)
        precondition(abs(centerPoint.y - 0.5) < 0.001)

        let bottomPoint = CameraPreviewLayout.normalizedPoint(
            from: CGPoint(x: 150, y: 640),
            in: contentSize
        )

        precondition(abs(bottomPoint.y - 1.0) < 0.001)
    }
}
