import Foundation

@main
struct MeteringCalibrationBehaviorTest {
    static func main() {
        let ev100 = MeteringCalibrationMath.ev100(
            aperture: 8.0,
            exposureDuration: 1.0 / 125.0,
            iso: 100
        )
        precondition(abs(ev100 - 12.965784) < 0.0001)

        let professional = LensCalibration(
            nativeLensKey: "wide",
            level: .professional,
            evOffset: 0.2,
            sampleCount: 1,
            createdAt: Date(timeIntervalSince1970: 1),
            deviceModel: "iPhone",
            appVersion: "1"
        )
        let standard = LensCalibration(
            nativeLensKey: "wide",
            level: .standard,
            evOffset: -0.1,
            sampleCount: 5,
            createdAt: Date(timeIntervalSince1970: 2),
            deviceModel: "iPhone",
            appVersion: "1"
        )
        let quick = LensCalibration(
            nativeLensKey: "wide",
            level: .quick,
            evOffset: 0.5,
            sampleCount: 1,
            createdAt: Date(timeIntervalSince1970: 3),
            deviceModel: "iPhone",
            appVersion: "1"
        )

        precondition(LensCalibration.best(from: [quick, standard, professional])?.level == .professional)
        precondition(abs(MeteringCalibrationMath.sceneEV(
            pointBrightness: ExposureCalculator.middleGrayReflectance,
            cameraReferenceEV: 12.5,
            calibration: professional
        ) - 12.7) < 0.0001)
        precondition(professional.statusLabel == "\(CalibrationLevel.professional.displayName) +0.2 EV")
        precondition(CalibrationLevel.professional.trustRank > CalibrationLevel.standard.trustRank)

        let indoorMiddleGraySample = CalibrationSample(
            measuredEV: ExposureCalculator.brightnessToEV(brightness: 0.5),
            referenceEV: 7.0
        )
        precondition(abs(indoorMiddleGraySample.offset + 6.973931) < 0.0001)
        precondition(MeteringCalibrationMath.averageOffset(from: [indoorMiddleGraySample]) != nil)

        let indoorQuick = LensCalibration(
            nativeLensKey: "wide",
            level: .quick,
            evOffset: 0,
            referenceBrightness: 0.5,
            sampleCount: 1,
            createdAt: Date(timeIntervalSince1970: 4),
            deviceModel: "iPhone",
            appVersion: "1"
        )
        precondition(LensCalibration.best(from: [indoorQuick])?.level == .quick)
        let calibratedMiddleGrayEV = MeteringCalibrationMath.sceneEV(
            pointBrightness: 0.5,
            cameraReferenceEV: 7.0,
            calibration: indoorQuick
        )
        precondition(abs(calibratedMiddleGrayEV - 7.0) < 0.0001)

        let brighterPointEV = MeteringCalibrationMath.sceneEV(
            pointBrightness: 1.0,
            cameraReferenceEV: 7.0,
            calibration: indoorQuick
        )
        precondition(abs(brighterPointEV - 8.0) < 0.0001)

        let legacyCalibrationJSON = """
        {
          "id": "legacy",
          "nativeLensKey": "wide",
          "level": "quick",
          "evOffset": 0.1,
          "sampleCount": 1,
          "createdAt": 0,
          "deviceModel": "iPhone",
          "appVersion": "1"
        }
        """
        let decodedLegacy = try! JSONDecoder().decode(
            LensCalibration.self,
            from: Data(legacyCalibrationJSON.utf8)
        )
        precondition(decodedLegacy.referenceBrightness == ExposureCalculator.middleGrayReflectance)
    }
}
