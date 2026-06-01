import SwiftUI

/// 光圈优先滑动浮层，使用标准光圈档位进行快速调整
struct ApertureSelectorView: View {

    // MARK: - Properties

    /// 当前锁定的光圈值，nil 表示自动联动
    @Binding var selectedAperture: Double?

    /// 是否显示浮层
    @Binding var isPresented: Bool

    /// 光圈选择回调
    let onApertureSelected: (Double?) -> Void

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

    private var activeAperture: Double {
        selectedAperture ?? ExposureCalculator.baseAperture
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    titleRow

                    ApertureRulerPicker(
                        selectedAperture: activeAperture,
                        onSelect: selectAperture
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
                .offset(x: -72, y: -1)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: Constants.overlayMaxWidth)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedAperture == nil ? Colors.textSecondary : Colors.accent)

            Text(ExposureCalculator.formatAperture(activeAperture))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Colors.textPrimary)

            Text(selectedAperture == nil ? String(localized: "exposure.mode.autoShort") : String(localized: "exposure.mode.aperturePriority"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selectedAperture == nil ? Colors.textSecondary : Colors.accent)

            Spacer(minLength: 0)
        }
    }

    private var lockPriorityButton: some View {
        Button {
            if selectedAperture == nil {
                selectAperture(activeAperture)
            } else {
                selectedAperture = nil
                onApertureSelected(nil)
            }
        } label: {
            Image(systemName: selectedAperture == nil ? "lock.open" : "lock.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(selectedAperture == nil ? Colors.textSecondary : .white)
                .frame(width: Constants.lockButtonSize, height: Constants.lockButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedAperture == nil ? Color.white.opacity(0.08) : Colors.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(selectedAperture == nil ? "exposure.accessibility.lockAperturePriority" : "exposure.accessibility.unlockAperturePriority"))
    }

    private var parameterAnchorTriangle: some View {
        Triangle()
            .fill(Colors.background)
            .frame(width: 14, height: 7)
    }

    private func selectAperture(_ aperture: Double) {
        selectedAperture = aperture
        onApertureSelected(aperture)
    }
}

private struct ApertureRulerPicker: View {
    let selectedAperture: Double
    let onSelect: (Double) -> Void

    private let tickWidth: CGFloat = 34
    private let tickSpacing: CGFloat = 2
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex = 0
    @State private var isDragging = false

    private var values: [Double] {
        ExposureCalculator.standardApertures
    }

    private var currentIndex: Int {
        values.firstIndex(of: selectedAperture) ?? nearestValueIndex(to: selectedAperture)
    }

    private var activeIndex: Int {
        isDragging ? nearestIndex(for: dragOffset, from: dragStartIndex) : currentIndex
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: tickSpacing) {
                    ForEach(Array(values.enumerated()), id: \.element) { index, aperture in
                        tick(for: aperture, isSelected: index == activeIndex)
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
                        let aperture = values[index]
                        if aperture != selectedAperture {
                            onSelect(aperture)
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
                .fill(Color.white.opacity(0.55))
                .frame(width: 1, height: 22)

            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 4, height: 4)
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

    private func nearestValueIndex(to aperture: Double) -> Int {
        values.enumerated().min { left, right in
            abs(left.element - aperture) < abs(right.element - aperture)
        }?.offset ?? 0
    }

    private func tick(for aperture: Double, isSelected: Bool) -> some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.36))
                .frame(width: 2, height: isSelected ? 20 : 12)

            Text(ExposureCalculator.formatAperture(aperture))
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
#Preview("Aperture Selector") {
    @Previewable @State var selectedAperture: Double? = 8.0
    @Previewable @State var isPresented = true

    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            ApertureSelectorView(
                selectedAperture: $selectedAperture,
                isPresented: $isPresented,
                onApertureSelected: { _ in }
            )
            .padding(.bottom, 120)
        }
    }
    .preferredColorScheme(.dark)
}
