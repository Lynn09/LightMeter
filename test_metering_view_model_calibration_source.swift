import Foundation

@main
struct MeteringViewModelCalibrationSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/ViewModels/MeteringViewModel.swift",
            encoding: .utf8
        )

        precondition(source.contains("private let calibrationStore: MeteringCalibrationStore"))
        precondition(source.contains("@Published var activeNativeLensInfo: NativeLensInfo?"))
        precondition(source.contains("var activeCalibration: LensCalibration?"))
        precondition(source.contains("var calibrationStatusLabel: String"))
        precondition(source.contains("func updateNativeLensInfo(_ lensInfo: NativeLensInfo?)"))
        precondition(source.contains("func saveCalibration(level: CalibrationLevel"))
        precondition(source.contains("cameraReferenceEV: Double"))
        precondition(source.contains("referenceBrightness: Double"))
        precondition(source.contains("private func calibratedEV(for brightness: Double, cameraReferenceEV: Double?)"))
        precondition(source.contains("MeteringCalibrationMath.sceneEV("))
        precondition(source.contains("let ev = calibratedEV(for: brightness, cameraReferenceEV: cameraReferenceEV)"))
        precondition(source.contains("updateExposureParameters()"))
    }
}
