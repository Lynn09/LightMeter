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
        viewModel.activeNativeLensInfo?.name ?? "No native lens"
    }

    var body: some View {
        NavigationStack {
            Form {
                currentCalibrationSection
                calibrationActionsSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentCalibrationSection: some View {
        Section("Metering Calibration") {
            LabeledContent("Native Lens", value: currentLensName)
            LabeledContent("Status", value: viewModel.calibrationStatusLabel)

            if let calibration = viewModel.activeCalibration {
                LabeledContent("Samples", value: "\(calibration.sampleCount)")
                LabeledContent("Created", value: calibration.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let message = calibrationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var calibrationActionsSection: some View {
        Section("Calibration Actions") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Professional Calibration")
                    .font(.headline)

                TextField("Reference EV100", text: $professionalReferenceEV)
                    .keyboardType(.decimalPad)

                Button("Start Professional Calibration") {
                    startProfessionalCalibration()
                }
            }
            .padding(.vertical, 4)

            Button("Standard Calibration") {
                onStartStandardCalibration()
                dismiss()
            }

            Button("Quick Calibration") {
                onStartQuickCalibration()
                dismiss()
            }
        }
    }

    private var resetSection: some View {
        Section("Reset") {
            Button("Reset Current Native Lens", role: .destructive) {
                viewModel.resetCalibrationForCurrentLens()
                calibrationMessage = "Current native lens calibration was reset."
            }

            Button("Reset All Calibrations", role: .destructive) {
                viewModel.resetAllCalibrations()
                calibrationMessage = "All calibration data was reset."
            }
        }
    }

    private func startProfessionalCalibration() {
        guard let referenceEV = Double(professionalReferenceEV) else {
            calibrationMessage = "Enter a valid EV100 value."
            return
        }

        onStartProfessionalCalibration(referenceEV)
        dismiss()
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
