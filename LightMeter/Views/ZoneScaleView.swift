import SwiftUI

// MARK: - Zone Scale View

/// 11区梯度条视图 - 快门控制版本
/// 拖动宽容度框调整快门速度，而非移动宽容度范围
/// 宽容度框宽度固定，仅作为参考显示
struct ZoneScaleView: View {

    // MARK: - Properties

    /// 宽容度最小 Zone（仅用于显示高亮框位置）
    let minZone: Int

    /// 宽容度最大 Zone（仅用于显示高亮框位置）
    let maxZone: Int

    /// 测光点数组
    let meteringPoints: [MeteringPoint]

    /// 当前快门偏移量（Zone单位）
    /// 正数 = 提高快门，负数 = 降低快门
    var shutterSpeedOffset: Double = 0

    /// 拖动过程中的临时偏移
    var dragOffset: Double = 0

    /// 快门偏移变化回调（拖动中）
    var onShutterOffsetChange: ((Double) -> Void)?

    /// 快门偏移结束回调（拖动结束）
    var onShutterOffsetEnd: ((Double) -> Void)?

    /// 渐变条高度
    var gradientHeight: CGFloat = 32

    /// Zone 标签
    private let zoneLabels = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    /// 11个 Zone 的颜色（从黑到白）
    private let zoneColors: [Color] = [
        Color(hex: "#000000")!, // Zone 0: 纯黑
        Color(hex: "#1A1A1A")!, // Zone I
        Color(hex: "#333333")!, // Zone II
        Color(hex: "#4D4D4D")!, // Zone III
        Color(hex: "#666666")!, // Zone IV
        Color(hex: "#808080")!, // Zone V: 中灰
        Color(hex: "#999999")!, // Zone VI
        Color(hex: "#B3B3B3")!, // Zone VII
        Color(hex: "#CCCCCC")!, // Zone VIII
        Color(hex: "#E6E6E6")!, // Zone IX
        Color(hex: "#FFFFFF")!  // Zone X: 纯白
    ]

    // MARK: - State

    /// 是否正在拖动
    @State private var isDragging: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Zone 标签行
            zoneLabelsRow

            // 渐变条容器（包含宽容度框和测光点）
            gradientBarContainer
        }
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Subviews

    /// Zone 标签行
    private var zoneLabelsRow: some View {
        GeometryReader { geometry in
            let zoneWidth = geometry.size.width / 11

            HStack(spacing: 0) {
                ForEach(0..<11, id: \.self) { index in
                    Text(zoneLabels[index])
                        .font(.system(size: 10, weight: index == 5 ? .semibold : .regular))
                        .foregroundColor(index == 5 ? .white : Color(hex: "#8E8E93"))
                        .frame(width: zoneWidth)
                }
            }
        }
        .frame(height: 16)
    }

    /// 渐变条容器
    private var gradientBarContainer: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let zoneWidth = totalWidth / 11

            ZStack {
                // 渐变背景
                gradientBackground

                // 宽容度标记（固定位置，仅作为参考）
                dynamicRangeMarker(zoneWidth: zoneWidth)

                // 测光点标记（随快门偏移移动）
                meteringPointMarkers(zoneWidth: zoneWidth)

                // 拖动指示器
                dragIndicator(zoneWidth: zoneWidth)
            }
        }
        .frame(height: gradientHeight)
    }

    /// 渐变背景
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: zoneColors),
            startPoint: .leading,
            endPoint: .trailing
        )
        .cornerRadius(4)
    }

    /// 宽容度标记（固定位置，仅作为参考）
    private func dynamicRangeMarker(zoneWidth: CGFloat) -> some View {
        let rangeWidth = CGFloat(maxZone - minZone + 1) * zoneWidth
        let baseXOffset = CGFloat(minZone) * zoneWidth

        return Rectangle()
            .fill(Color(hex: "#007AFF")!.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(Color(hex: "#007AFF")!, lineWidth: isDragging ? 2 : 1)
            )
            .frame(width: rangeWidth, height: gradientHeight - 4)
            .position(x: baseXOffset + rangeWidth / 2, y: gradientHeight / 2)
            .cornerRadius(4)
            // 拖动手势 - 用于调整快门
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        if !isDragging {
                            isDragging = true
                        }
                        onShutterOffsetChange?(zoneOffset)
                    }
                    .onEnded { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        isDragging = false
                        onShutterOffsetEnd?(zoneOffset)
                    }
            )
            .onTapGesture(count: 2) {
                // 双击重置
                onShutterOffsetEnd?(0)
            }
    }

    /// 测光点标记（随快门偏移移动）
    private func meteringPointMarkers(zoneWidth: CGFloat) -> some View {
        // The view model already includes exposure compensation and shutter offset.
        // Keep fractional Zone positions; clamp only their on-screen placement.
        ForEach(Array(meteringPoints.enumerated()), id: \.element.id) { index, point in
            let zone = min(10, max(0, point.zonePosition ?? Double(point.zone)))
            meteringPointCircle(point: point, index: index, count: meteringPoints.count)
                .position(x: CGFloat(zone) * zoneWidth + zoneWidth / 2, y: gradientHeight / 2)
        }
    }

    /// 测光点圆圈
    private func meteringPointCircle(point: MeteringPoint, index: Int, count: Int) -> some View {
        Circle()
            .fill(Color(hex: point.color) ?? .blue)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .opacity(isDragging ? 0.8 : 1.0)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .zIndex(Double(count - index))
    }

    /// 拖动指示器（显示当前偏移量）
    private func dragIndicator(zoneWidth: CGFloat) -> some View {
        let totalOffset = shutterSpeedOffset + dragOffset
        let centerX = CGFloat(5 - totalOffset) * zoneWidth + zoneWidth / 2

        return Group {
            if isDragging || abs(shutterSpeedOffset) > 0.01 {
                VStack(spacing: 2) {
                    // 指示三角形
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isDragging ? .green : .white)
                        .rotationEffect(.degrees(180))

                    // 偏移数值
                    Text(offsetDisplayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDragging ? .green : .white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isDragging ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
                        )
                }
                .position(x: centerX, y: -20)
            }
        }
    }

    /// 偏移显示文本
    private var offsetDisplayText: String {
        let totalOffset = shutterSpeedOffset + dragOffset
        let sign = totalOffset > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", totalOffset)) EV"
    }
}

// MARK: - Preview

#Preview("Zone Scale View - Shutter Control") {
    VStack(spacing: 20) {
        // Velvia 50，无偏移
        ZoneScaleView(
            minZone: 4,
            maxZone: 8,
            meteringPoints: [
                MeteringPoint(x: 100, y: 100, color: "#34C759", zone: 4, ev: 11.5),
                MeteringPoint(x: 200, y: 200, color: "#FF9500", zone: 7, ev: 14.5)
            ],
            shutterSpeedOffset: 0,
            onShutterOffsetChange: { offset in
                print("Drag offset: \(offset)")
            },
            onShutterOffsetEnd: { offset in
                print("End with offset: \(offset)")
            }
        )
        .frame(height: 80)
        .padding(.horizontal)

        // Velvia 50，+2 EV快门偏移（测光点向左移动）
        ZoneScaleView(
            minZone: 4,
            maxZone: 8,
            meteringPoints: [
                MeteringPoint(x: 100, y: 100, color: "#34C759", zone: 4, ev: 11.5),
                MeteringPoint(x: 200, y: 200, color: "#FF9500", zone: 7, ev: 14.5)
            ],
            shutterSpeedOffset: 2,  // +2 EV = 提高2档快门
            onShutterOffsetChange: nil,
            onShutterOffsetEnd: nil
        )
        .frame(height: 80)
        .padding(.horizontal)

        Text("+2 EV 快门偏移，测光点向左移动2档")
            .font(.caption)
            .foregroundColor(.secondary)

        Spacer()
    }
    .padding(.vertical)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
