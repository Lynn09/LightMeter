import CoreGraphics
import ImageIO

// MARK: - Static Frame Preview Orientation

/// 静态帧预览方向
enum StaticFramePreviewOrientation {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

// MARK: - Static Frame Preview Geometry

/// 静态帧预览的方向和尺寸规则
enum StaticFramePreviewGeometry {
    static func displaySize(
        forPixelWidth width: Int,
        height: Int,
        orientation: StaticFramePreviewOrientation
    ) -> CGSize {
        switch orientation {
        case .portrait, .portraitUpsideDown:
            return CGSize(width: height, height: width)
        case .landscapeLeft, .landscapeRight:
            return CGSize(width: width, height: height)
        }
    }

    static func exifOrientation(for orientation: StaticFramePreviewOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        }
    }

    static func rawPoint(
        forDisplayPoint point: CGPoint,
        orientation: StaticFramePreviewOrientation
    ) -> CGPoint {
        let x = max(0, min(1, point.x))
        let y = max(0, min(1, point.y))

        switch orientation {
        case .portrait:
            return CGPoint(x: y, y: 1 - x)
        case .portraitUpsideDown:
            return CGPoint(x: 1 - y, y: x)
        case .landscapeLeft:
            return CGPoint(x: 1 - x, y: 1 - y)
        case .landscapeRight:
            return CGPoint(x: x, y: y)
        }
    }
}
