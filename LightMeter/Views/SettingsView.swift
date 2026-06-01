import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MeteringViewModel
    @ObservedObject var cameraManager: CameraManager
    let onStartProfessionalCalibration: (Double) -> Void
    let onStartStandardCalibration: () -> Void
    let onStartQuickCalibration: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var professionalReferenceEV: String = ""
    @State private var calibrationMessage: String?

    private var currentLensName: String {
        viewModel.activeNativeLensInfo?.name ?? String(localized: "settings.noNativeLens")
    }

    var body: some View {
        NavigationStack {
            Form {
                currentCalibrationSection
                calibrationActionsSection
                resetSection
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentCalibrationSection: some View {
        Section("settings.meteringCalibration") {
            LabeledContent("settings.nativeLens", value: currentLensName)
            LabeledContent("settings.status", value: viewModel.calibrationStatusLabel)

            if let calibration = viewModel.activeCalibration {
                LabeledContent("settings.samples", value: "\(calibration.sampleCount)")
                LabeledContent("settings.created", value: calibration.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let message = calibrationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var calibrationActionsSection: some View {
        Section("settings.calibrationActions") {
            VStack(alignment: .leading, spacing: 10) {
                Text("settings.calibration.professional")
                    .font(.headline)

                TextField("settings.referenceEV100.placeholder", text: $professionalReferenceEV)
                    .keyboardType(.decimalPad)

                Button("settings.startProfessionalCalibration") {
                    startProfessionalCalibration()
                }
            }
            .padding(.vertical, 4)

            Button("settings.calibration.standard") {
                dismiss()
                DispatchQueue.main.async {
                    onStartStandardCalibration()
                }
            }

            Button("settings.calibration.quick") {
                dismiss()
                DispatchQueue.main.async {
                    onStartQuickCalibration()
                }
            }
        }
    }

    private var resetSection: some View {
        Section("settings.reset") {
            Button("settings.resetCurrentNativeLens", role: .destructive) {
                viewModel.resetCalibrationForCurrentLens()
                calibrationMessage = String(localized: "settings.message.resetCurrentNativeLens")
            }

            Button("settings.resetAllCalibrations", role: .destructive) {
                viewModel.resetAllCalibrations()
                calibrationMessage = String(localized: "settings.message.resetAllCalibrations")
            }
        }
    }

    private func startProfessionalCalibration() {
        guard let referenceEV = Double(professionalReferenceEV) else {
            calibrationMessage = String(localized: "settings.message.invalidReferenceEV")
            return
        }

        dismiss()
        DispatchQueue.main.async {
            onStartProfessionalCalibration(referenceEV)
        }
    }
}

#Preview("Settings") {
    SettingsView(
        viewModel: MeteringViewModel(),
        cameraManager: CameraManager(),
        onStartProfessionalCalibration: { _ in },
        onStartStandardCalibration: {},
        onStartQuickCalibration: {}
    )
}
