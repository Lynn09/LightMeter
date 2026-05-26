import CoreGraphics

// MARK: - Camera Preview Layout

/// 相机预览的可见尺寸和点击坐标规则
enum CameraPreviewLayout {
    static func contentSize(for containerSize: CGSize) -> CGSize {
        containerSize
    }

    static func normalizedPoint(from location: CGPoint, in contentSize: CGSize) -> CGPoint {
        guard contentSize.width > 0, contentSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        return CGPoint(
            x: max(0, min(1, location.x / contentSize.width)),
            y: max(0, min(1, location.y / contentSize.height))
        )
    }
}
