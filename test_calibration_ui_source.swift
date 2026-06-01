import Foundation

@main
struct CalibrationUISourceTest {
    static func main() throws {
        let toolbar = try String(contentsOfFile: "LightMeter/Views/TopToolbar.swift", encoding: .utf8)
        let mainView = try String(contentsOfFile: "LightMeter/Views/MainMeteringView.swift", encoding: .utf8)
        let filmSelector = try String(contentsOfFile: "LightMeter/Views/FilmSelectorView.swift", encoding: .utf8)
        let settings = try String(contentsOfFile: "LightMeter/Views/SettingsView.swift", encoding: .utf8)

        precondition(toolbar.contains("Image(systemName: \"gearshape\")"))
        precondition(toolbar.contains("let calibrationStatus: String"))
        precondition(toolbar.contains("onSettingsButtonTap"))
        precondition(toolbar.contains("Color.clear"))
        precondition(toolbar.contains("activeHighlight"))
        precondition(toolbar.contains(".frame(maxWidth: Constants.filmButtonMaxWidth)"))
        precondition(toolbar.contains(".frame(width: Constants.statusWidth, alignment: .trailing)"))
        precondition(toolbar.contains("ZStack"))
        precondition(toolbar.contains("filmButton"))
        precondition(toolbar.contains(".frame(maxWidth: .infinity, alignment: .center)"))

        precondition(mainView.contains("@State private var showingSettings = false"))
        precondition(mainView.contains("@State private var activeCalibrationMode: CalibrationCaptureMode?"))
        precondition(mainView.contains("private var isCalibrationActive: Bool"))
        precondition(mainView.contains(".sheet(isPresented: $showingSettings)"))
        precondition(mainView.contains("SettingsView("))
        precondition(mainView.contains("calibrationCaptureOverlay"))
        precondition(mainView.contains("CalibrationCaptureOverlay"))
        precondition(mainView.contains("if !isCalibrationActive"))
        precondition(mainView.contains("meteringInterface"))
        precondition(mainView.contains("meteringInterface\n"))
        precondition(!mainView.contains("} else {\n                calibrationPreviewInterface\n            }"))
        precondition(mainView.contains("showsPreviewControls: !isCalibrationActive"))
        precondition(mainView.contains("private func startCameraSessionIfNeeded()"))
        precondition(mainView.contains("cameraManager.resumeLivePreview()"))
        precondition(mainView.contains(".task {\n            await startCameraSessionIfNeeded()"))
        precondition(!mainView.contains("cameraPreviewContent: some View {\n        CameraPreviewView(") || !mainView.contains(".onDisappear {\n            cameraManager.stopSession()\n        }\n    }\n\n    private var filmSelectorOverlay"))
        precondition(mainView.contains("startCalibrationCapture"))
        guard let startRange = mainView.range(of: "private func startCalibrationCapture"),
              let captureRange = mainView.range(of: "private func captureCalibrationSample"),
              let activeRange = mainView.range(of: "activeCalibrationMode = mode", range: startRange.upperBound..<captureRange.lowerBound),
              let prepareRange = mainView.range(of: "prepareCameraForCalibrationCapture()", range: startRange.upperBound..<captureRange.lowerBound) else {
            preconditionFailure("Calibration startup should show UI before preparing camera.")
        }
        precondition(activeRange.lowerBound < prepareRange.lowerBound)
        precondition(mainView.contains("private func prepareCameraForCalibrationCapture()"))
        precondition(!mainView.contains("_ = cameraManager.lockCurrentExposure()"))
        precondition(mainView.contains("captureCalibrationSample"))
        precondition(mainView.contains("viewModel.updateNativeLensInfo(lensInfo)"))
        precondition(mainView.contains("calibrationStatus: viewModel.calibrationStatusLabel"))

        precondition(filmSelector.contains(".overlay(alignment: .top)"))
        precondition(filmSelector.contains(".offset(y: -7)"))

        precondition(settings.contains("struct SettingsView: View"))
        precondition(settings.contains("settings.calibration.professional"))
        precondition(settings.contains("settings.calibration.standard"))
        precondition(settings.contains("settings.calibration.quick"))
        precondition(settings.contains("onStartProfessionalCalibration"))
        precondition(settings.contains("onStartStandardCalibration"))
        precondition(settings.contains("onStartQuickCalibration"))
        precondition(settings.contains("DispatchQueue.main.async"))
        precondition(!settings.contains("cameraManager.captureCalibrationSample()"))
    }
}
