import Foundation

@main
struct CameraCalibrationSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/Managers/CameraManager.swift",
            encoding: .utf8
        )

        precondition(source.contains("var currentNativeLensInfo: NativeLensInfo?"))
        precondition(source.contains("var currentExposureSnapshot: CameraExposureSnapshot?"))
        precondition(source.contains("var currentMeteringReferenceEV: Double?"))
        precondition(source.contains("frozenExposureSnapshot"))
        precondition(source.contains("func getCenterWeightedBrightness() -> Double"))
        precondition(source.contains("func lockCurrentExposure() -> Bool"))
        precondition(source.contains("func captureCalibrationSample() -> CalibrationSample?"))
        precondition(source.contains("private func nativeLensDisplayName(for device: AVCaptureDevice) -> String"))
        precondition(source.contains("String(localized: \"camera.native.main\")"))
        precondition(source.contains("MeteringCalibrationMath.ev100("))
        precondition(source.contains("device.exposureMode = .locked"))
        precondition(source.contains("device.lensAperture"))
        precondition(source.contains("CMTimeGetSeconds(device.exposureDuration)"))
    }
}
