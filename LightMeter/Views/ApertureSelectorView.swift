import SwiftUI

struct ApertureSelectorView: View {
    let selectedAperture: Double?
    let onApertureSelected: (Double?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            option("自动", aperture: nil)
            Divider().frame(height: 20)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(ExposureCalculator.standardApertures, id: \.self) { value in
                            option(ExposureCalculator.formatAperture(value), aperture: value)
                                .id(value)
                        }
                    }
                }
                .onAppear {
                    if let selectedAperture { proxy.scrollTo(selectedAperture, anchor: .center) }
                }
            }
        }
        .padding(.horizontal, 6)
        .background(.white.opacity(0.10), in: Capsule())
        .padding(.horizontal, 16)
    }

    private func option(_ title: String, aperture: Double?) -> some View {
        let selected = selectedAperture == aperture
        return Button { onApertureSelected(aperture) } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .bold : .medium).monospacedDigit())
                .foregroundStyle(selected ? Color.yellow : .white)
                .padding(.horizontal, 6)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
