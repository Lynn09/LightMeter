import CoreGraphics

// MARK: - Metering Point Layout

/// 测光点覆盖层的边界约束规则
enum MeteringPointLayout {
    static let markerSize: CGFloat = 20
    static let markerRadius: CGFloat = markerSize / 2
    static let markerCornerRadius: CGFloat = 3
    static let selectedGlowSize: CGFloat = 25
    static let selectedGlowCornerRadius: CGFloat = 4
    private static let topBadgeClearance: CGFloat = 46

    static func displayPosition(
        normalizedPoint point: CGPoint,
        containerSize: CGSize
    ) -> CGPoint {
        let x = max(0, min(1, point.x)) * containerSize.width
        let y = max(0, min(1, point.y)) * containerSize.height

        return CGPoint(
            x: max(markerRadius, min(containerSize.width - markerRadius, x)),
            y: max(markerRadius, min(containerSize.height - markerRadius, y))
        )
    }

    static func exposureValueBadgeYOffset(
        normalizedY: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        let y = max(markerRadius, min(containerHeight - markerRadius, normalizedY * containerHeight))
        return y < topBadgeClearance ? 34 : -34
    }
}
