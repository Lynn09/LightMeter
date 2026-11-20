import SwiftUI

struct ExposureInfoView: View {
    @ObservedObject var viewModel: MeteringViewModel
    let isExpanded: Bool
    let onApertureTap: () -> Void

    var body: some View {
        let point = viewModel.selectedPoint?.exposureParams
        let hasReading = !viewModel.meteringPoints.isEmpty
        HStack(spacing: 12) {
            Button(action: onApertureTap) {
                readout(viewModel.isApertureLocked ? "锁定光圈" : "自动光圈",
                        value: viewModel.lockedAperture.map(ExposureCalculator.formatAperture)
                            ?? point?.formattedAperture ?? (hasReading ? viewModel.currentExposure.formattedAperture : "—"),
                        symbol: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.plain)
            readout("快门", value: point?.formattedShutterSpeed ?? (hasReading ? viewModel.currentExposure.formattedShutterSpeed : "—"))
            readout("ISO", value: String(viewModel.selectedFilm.iso))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func readout(_ title: String, value: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                if let symbol { Image(systemName: symbol) }
            }
            .font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
