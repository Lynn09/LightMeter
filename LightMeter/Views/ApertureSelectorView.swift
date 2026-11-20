import SwiftUI

struct ApertureSelectorView: View {
    let selectedAperture: Double?
    let onApertureSelected: (Double?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var translation: CGFloat = 0
    @ScaledMetric(relativeTo: .subheadline) private var step: CGFloat = 60

    private static let stops: [Double?] = [nil] + ExposureCalculator.standardApertures
    private var selectedIndex: Int { Self.stops.firstIndex(of: selectedAperture) ?? 0 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let position = indexPosition(for: translation)
            ZStack {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(.yellow.opacity(0.12))
                    .frame(width: step, height: 36)
                    .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(Self.stops.indices, id: \.self) { index in
                        let centered = index == Int(position.rounded())
                        Button {
                            select(index)
                        } label: {
                            Text(Self.stops[index].map(ExposureCalculator.formatAperture) ?? "自动")
                                .font(.subheadline.weight(centered ? .bold : .medium).monospacedDigit())
                                .foregroundStyle(centered ? Color.yellow : .white)
                                .frame(width: step, height: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                        .accessibilityHidden(CGFloat(abs(index - selectedIndex)) * step > width / 2)
                    }
                }
                .fixedSize()
                .offset(x: (width - step) / 2 - position * step)
                .frame(width: width, alignment: .leading)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.30),
                        .init(color: .white, location: 0.70),
                        .init(color: .clear, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
            }
            .contentShape(Capsule())
            .highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .updating($translation) { value, state, _ in state = value.translation.width }
                    .onEnded { value in
                        let momentum = value.predictedEndTranslation.width - value.translation.width
                        let travel = value.translation.width + min(step * 3, max(-step * 3, momentum))
                        select(Int(indexPosition(for: travel).rounded()))
                    }
            )
        }
        .frame(height: 48)
        .padding(.horizontal, 16)
    }

    private func indexPosition(for translation: CGFloat) -> CGFloat {
        min(CGFloat(Self.stops.count - 1), max(0, CGFloat(selectedIndex) - translation / step))
    }

    private func select(_ index: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            onApertureSelected(Self.stops[index])
        }
    }
}
