import SwiftUI

struct ApertureSelectorView: View {
    let selectedAperture: Double?
    let onApertureSelected: (Double?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            option("自动", aperture: nil)
            Divider().frame(height: 20)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
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
        .padding(.horizontal, 16)
    }

    private func option(_ title: String, aperture: Double?) -> some View {
        Button { onApertureSelected(aperture) } label: {
            Text(title).font(.subheadline.monospacedDigit())
                .padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44)
                .background(.white.opacity(selectedAperture == aperture ? 0.18 : 0), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedAperture == aperture ? .isSelected : [])
    }
}
