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
                RoundedRectangle(cornerRadius: 8)
                    .fill(point.swiftColor.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .blur(radius: 10)
            }

            // 主方框
            RoundedRectangle(cornerRadius: 6)
                .fill(point.swiftColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(point.swiftColor, lineWidth: isSelected ? 3 : 2)
                )

            // 十字准星
            MeteringPointPlusShape()
                .stroke(point.swiftColor, lineWidth: 1.5)
                .frame(width: 24, height: 24)
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

// MARK: - Plus Shape

/// 十字形状
private struct MeteringPointPlusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfSize = min(rect.width, rect.height) / 2

        // 水平线
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))

        // 垂直线
        path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))

        return path
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
