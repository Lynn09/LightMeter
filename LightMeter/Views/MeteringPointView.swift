import SwiftUI

// MARK: - MeteringPointView

/// 测光点视图
/// 显示彩色方框标记，表示测光点的位置和状态
struct MeteringPointView: View {
    let point: MeteringPoint
    let isSelected: Bool
    let containerSize: CGSize
    let onTap: () -> Void

    var body: some View {
        ZStack {
            exposureValueBadge
                .offset(y: exposureValueBadgeYOffset)
                .zIndex(1)

            // 选中时的发光效果
            if isSelected {
                RoundedRectangle(cornerRadius: MeteringPointLayout.selectedGlowCornerRadius)
                    .fill(point.swiftColor.opacity(0.3))
                    .frame(
                        width: MeteringPointLayout.selectedGlowSize,
                        height: MeteringPointLayout.selectedGlowSize
                    )
                    .blur(radius: 5)
            }

            // 主方框
            RoundedRectangle(cornerRadius: MeteringPointLayout.markerCornerRadius)
                .fill(point.swiftColor.opacity(0.2))
                .frame(
                    width: MeteringPointLayout.markerSize,
                    height: MeteringPointLayout.markerSize
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MeteringPointLayout.markerCornerRadius)
                        .stroke(point.swiftColor, lineWidth: isSelected ? 2 : 1)
                )
        }
        .position(
            MeteringPointLayout.displayPosition(
                normalizedPoint: CGPoint(x: point.x, y: point.y),
                containerSize: containerSize
            )
        )
        .onTapGesture {
            onTap()
        }
    }

    private var exposureValueBadge: some View {
        Text(point.exposureValueLabel)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                Capsule()
                    .stroke(point.swiftColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }

    private var exposureValueBadgeYOffset: CGFloat {
        MeteringPointLayout.exposureValueBadgeYOffset(
            normalizedY: point.y,
            containerHeight: containerSize.height
        )
    }
}

// MARK: - Preview

#Preview("Metering Point View") {
    ZStack {
        Color.black.ignoresSafeArea()

        MeteringPointView(
            point: MeteringPoint(
                x: 0.5,
                y: 0.5,
                color: "#007AFF",
                zone: 5,
                ev: 12.5
            ),
            isSelected: true,
            containerSize: CGSize(width: 300, height: 400),
            onTap: {}
        )
    }
}
