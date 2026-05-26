import CoreGraphics
import Foundation

// MARK: - Standard Focal Length

/// 标准定焦焦段
enum StandardFocalLength: Int, CaseIterable, Identifiable {
    case mm24 = 24
    case mm28 = 28
    case mm35 = 35
    case mm50 = 50
    case mm85 = 85
    case mm105 = 105

    var id: Int { rawValue }
    var millimeters: Int { rawValue }
    var label: String { "\(rawValue)" }
    var displayLabel: String { "\(rawValue)mm" }
}

// MARK: - Camera Lens Info

/// 当前手机镜头信息
struct CameraLensInfo: Equatable {
    let equivalentFocalLength: Double?
    let displayName: String

    static let unknown = CameraLensInfo(
        equivalentFocalLength: nil,
        displayName: "镜头 --"
    )
}

// MARK: - Focal Length Preview Geometry

/// 标准焦段取景预览的裁切规则
enum FocalLengthPreviewGeometry {
    static func previewScale(
        currentEquivalentFocalLength: Double?,
        selectedFocalLength: StandardFocalLength
    ) -> CGFloat {
        guard let currentEquivalentFocalLength,
              currentEquivalentFocalLength > 0 else {
            return 1
        }

        let target = Double(selectedFocalLength.millimeters)
        return CGFloat(max(1, target / currentEquivalentFocalLength))
    }

    static func sourcePoint(
        forDisplayPoint point: CGPoint,
        previewScale: CGFloat
    ) -> CGPoint {
        let safeScale = max(1, previewScale)
        let x = 0.5 + (max(0, min(1, point.x)) - 0.5) / safeScale
        let y = 0.5 + (max(0, min(1, point.y)) - 0.5) / safeScale

        return CGPoint(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }

    static func isWiderThanCurrentLens(
        currentEquivalentFocalLength: Double?,
        selectedFocalLength: StandardFocalLength
    ) -> Bool {
        guard let currentEquivalentFocalLength else {
            return false
        }

        return Double(selectedFocalLength.millimeters) < currentEquivalentFocalLength
    }
}

// MARK: - Static Frame Controls Layout

/// 静态帧控制按钮布局
enum StaticFrameControlsLayout {
    static func controlFrame(
        in containerSize: CGSize,
        controlSize: CGSize,
        bottomPadding: CGFloat
    ) -> CGRect {
        CGRect(
            x: (containerSize.width - controlSize.width) / 2,
            y: max(0, containerSize.height - bottomPadding - controlSize.height),
            width: controlSize.width,
            height: controlSize.height
        )
    }
}
