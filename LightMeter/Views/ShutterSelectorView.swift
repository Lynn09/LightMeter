import SwiftUI

/// 快门优先滑动浮层，使用标准快门档位进行快速调整
struct ShutterSelectorView: View {

    // MARK: - Properties

    /// 当前锁定的快门速度，nil 表示自动联动
    @Binding var selectedShutterSpeed: Double?

    /// 是否显示浮层
    @Binding var isPresented: Bool

    /// 快门选择回调
    let onShutterSelected: (Double?) -> Void

    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 12
        static let lockButtonSize: CGFloat = 44
        static let overlayMaxWidth: CGFloat = 342
    }

    private enum Colors {
        static let background = Color.black.opacity(0.78)
        static let panelStroke = Color.white.opacity(0.14)
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let accent = Color(hex: "#007AFF")!
    }

    private var activeShutterSpeed: Double {
        selectedShutterSpeed ?? ExposureCalculator.baseShutterSpeed
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    titleRow

                    ShutterRulerPicker(
                        selectedShutterSpeed: activeShutterSpeed,
                        onSelect: selectShutter
                    )
                }

                lockPriorityButton
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .background(Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                    .stroke(Colors.panelStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 10)

            parameterAnchorTriangle
                .offset(x: 72, y: -1)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: Constants.overlayMaxWidth)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "stopwatch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedShutterSpeed == nil ? Colors.textSecondary : Colors.accent)

            Text(ExposureCalculator.formatShutterSpeed(activeShutterSpeed))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Colors.textPrimary)

            Text(selectedShutterSpeed == nil ? "自动" : "快门优先")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selectedShutterSpeed == nil ? Colors.textSecondary : Colors.accent)

            Spacer(minLength: 0)
        }
    }

    private var lockPriorityButton: some View {
        Button {
            if selectedShutterSpeed == nil {
                selectShutter(activeShutterSpeed)
            } else {
                selectedShutterSpeed = nil
                onShutterSelected(nil)
            }
        } label: {
            Image(systemName: selectedShutterSpeed == nil ? "lock.open" : "lock.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(selectedShutterSpeed == nil ? Colors.textSecondary : .white)
                .frame(width: Constants.lockButtonSize, height: Constants.lockButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedShutterSpeed == nil ? Color.white.opacity(0.08) : Colors.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedShutterSpeed == nil ? "锁定快门优先" : "解除快门优先")
    }

    private var parameterAnchorTriangle: some View {
        Triangle()
            .fill(Colors.background)
            .frame(width: 14, height: 7)
    }

    private func selectShutter(_ shutterSpeed: Double) {
        selectedShutterSpeed = shutterSpeed
        onShutterSelected(shutterSpeed)
    }
}

private struct ShutterRulerPicker: View {
    let selectedShutterSpeed: Double
    let onSelect: (Double) -> Void

    private let tickWidth: CGFloat = 42
    private let tickSpacing: CGFloat = 2
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex = 0
    @State private var isDragging = false

    private var values: [Double] {
        ExposureCalculator.standardShutterSpeeds
    }

    private var currentIndex: Int {
        values.firstIndex(of: selectedShutterSpeed) ?? nearestValueIndex(to: selectedShutterSpeed)
    }

    private var activeIndex: Int {
        isDragging ? nearestIndex(for: dragOffset, from: dragStartIndex) : currentIndex
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: tickSpacing) {
                    ForEach(Array(values.enumerated()), id: \.element) { index, shutterSpeed in
                        tick(for: shutterSpeed, isSelected: index == activeIndex)
                    }
                }
                .offset(x: rulerOffset(in: proxy.size.width))
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: activeIndex)

                centerSelectionIndicator
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            dragStartIndex = currentIndex
                            isDragging = true
                        }
                        dragOffset = value.translation.width
                        let index = nearestIndex(for: dragOffset, from: dragStartIndex)
                        let shutterSpeed = values[index]
                        if shutterSpeed != selectedShutterSpeed {
                            onSelect(shutterSpeed)
                        }
                    }
                    .onEnded { value in
                        let index = nearestIndex(for: value.translation.width, from: dragStartIndex)
                        onSelect(values[index])
                        dragOffset = 0
                        isDragging = false
                    }
            )
        }
        .frame(height: 52)
        .clipped()
    }

    private var centerSelectionIndicator: some View {
        VStack(spacing: 3) {
            Rectangle()
                .fill(Color(hex: "#007AFF")!)
                .frame(width: 2, height: 28)

            Circle()
                .fill(Color(hex: "#007AFF")!)
                .frame(width: 5, height: 5)
        }
        .allowsHitTesting(false)
    }

    private func rulerOffset(in width: CGFloat) -> CGFloat {
        let centerOffset = (width - tickWidth) / 2
        let index = isDragging ? dragStartIndex : currentIndex
        return centerOffset - CGFloat(index) * stride + dragOffset
    }

    private var stride: CGFloat {
        tickWidth + tickSpacing
    }

    private func nearestIndex(for offset: CGFloat, from startIndex: Int) -> Int {
        let delta = Int(round(-offset / stride))
        return min(max(startIndex + delta, 0), values.count - 1)
    }

    private func nearestValueIndex(to shutterSpeed: Double) -> Int {
        values.enumerated().min { left, right in
            abs(left.element - shutterSpeed) < abs(right.element - shutterSpeed)
        }?.offset ?? 0
    }

    private func tick(for shutterSpeed: Double, isSelected: Bool) -> some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.36))
                .frame(width: 2, height: isSelected ? 20 : 12)

            Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(width: tickWidth, height: 48)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

@available(iOS 17.0, *)
#Preview("Shutter Selector") {
    @Previewable @State var selectedShutterSpeed: Double? = 1.0 / 125.0
    @Previewable @State var isPresented = true

    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            ShutterSelectorView(
                selectedShutterSpeed: $selectedShutterSpeed,
                isPresented: $isPresented,
                onShutterSelected: { _ in }
            )
            .padding(.bottom, 120)
        }
    }
    .preferredColorScheme(.dark)
}
