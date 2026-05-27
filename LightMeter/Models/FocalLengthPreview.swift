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
    let baseEquivalentFocalLength: Double?
    let zoomFactor: Double
    let displayName: String
    let renderingMode: String

    static let unknown = CameraLensInfo(
        equivalentFocalLength: nil,
        baseEquivalentFocalLength: nil,
        zoomFactor: 1,
        displayName: "镜头 --",
        renderingMode: "未知"
    )

    static func makeDisplayName(equivalentFocalLength: Double?) -> String {
        guard let equivalentFocalLength else {
            return "镜头 --"
        }

        return "手机 \(Int(round(equivalentFocalLength)))mm"
    }
}

// MARK: - Focal Length Preview Geometry

/// 标准焦段取景预览的裁切规则
enum FocalLengthPreviewGeometry {
    static func zoomFactor(
        baseEquivalentFocalLength: Double?,
        selectedFocalLength: StandardFocalLength
    ) -> CGFloat {
        guard let baseEquivalentFocalLength,
              baseEquivalentFocalLength > 0 else {
            return 1
        }

        let target = Double(selectedFocalLength.millimeters)
        return CGFloat(max(1, target / baseEquivalentFocalLength))
    }

    static func clampedZoomFactor(
        _ zoomFactor: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        max(minimum, min(maximum, zoomFactor))
    }

    static func previewScale(
        currentEquivalentFocalLength: Double?,
        selectedFocalLength: StandardFocalLength
    ) -> CGFloat {
        1
    }

    static func isWiderThanCurrentLens(
        baseEquivalentFocalLength: Double?,
        selectedFocalLength: StandardFocalLength
    ) -> Bool {
        guard let baseEquivalentFocalLength else {
            return false
        }

        return Double(selectedFocalLength.millimeters) < baseEquivalentFocalLength
    }
}

// MARK: - Focal Length Drawer Presentation

/// 焦段抽屉展示规则
enum FocalLengthDrawerPresentation {
    static func visibleFocalLengths(
        isExpanded: Bool,
        selectedFocalLength: StandardFocalLength
    ) -> [StandardFocalLength] {
        isExpanded ? StandardFocalLength.allCases : [selectedFocalLength]
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
