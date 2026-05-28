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
        precondition(mainView.contains("calibrationPreviewInterface"))
        precondition(mainView.contains("showsPreviewControls: !isCalibrationActive"))
        precondition(mainView.contains("private func startCameraSessionIfNeeded()"))
        precondition(mainView.contains("cameraManager.resumeLivePreview()"))
        precondition(mainView.contains(".task {\n            await startCameraSessionIfNeeded()"))
        precondition(!mainView.contains("cameraPreviewContent: some View {\n        CameraPreviewView(") || !mainView.contains(".onDisappear {\n            cameraManager.stopSession()\n        }\n    }\n\n    private var filmSelectorOverlay"))
        precondition(mainView.contains("startCalibrationCapture"))
        precondition(mainView.contains("captureCalibrationSample"))
        precondition(mainView.contains("viewModel.updateNativeLensInfo(lensInfo)"))
        precondition(mainView.contains("calibrationStatus: viewModel.calibrationStatusLabel"))

        precondition(filmSelector.contains(".overlay(alignment: .top)"))
        precondition(filmSelector.contains(".offset(y: -7)"))

        precondition(settings.contains("struct SettingsView: View"))
        precondition(settings.contains("Professional Calibration"))
        precondition(settings.contains("Standard Calibration"))
        precondition(settings.contains("Quick Calibration"))
        precondition(settings.contains("onStartProfessionalCalibration"))
        precondition(settings.contains("onStartStandardCalibration"))
        precondition(settings.contains("onStartQuickCalibration"))
        precondition(!settings.contains("cameraManager.captureCalibrationSample()"))
    }
}
