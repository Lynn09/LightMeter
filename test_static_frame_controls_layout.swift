import CoreGraphics
import Foundation

@main
struct StaticFrameControlsLayoutTest {
    static func main() {
        let frame = StaticFrameControlsLayout.controlFrame(
            in: CGSize(width: 320, height: 640),
            controlSize: CGSize(width: 160, height: 34),
            bottomPadding: 14
        )

        precondition(frame.minY >= 0)
        precondition(frame.maxY <= 640)
        precondition(abs(frame.midX - 160) < 0.001)
        precondition(abs(frame.maxY - 626) < 0.001)
    }
}
