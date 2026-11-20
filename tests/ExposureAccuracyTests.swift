import Foundation

@main
enum ExposureAccuracyTests {
    static func main() {
        func near(_ actual: Double, _ expected: Double, _ tolerance: Double = 1e-8, _ message: String) {
            guard actual.isFinite, abs(actual - expected) <= tolerance else {
                fatalError("\(message): got \(actual), expected \(expected)")
            }
        }
        // Independent reference: N²/t = 2^EV100 × ISO/100.
        let ev = log2(8.0 * 8.0 * 125.0)
        let t100 = ExposureCalculator.calculateShutterForLockedAperture(aperture: 8, pointEV: ev, iso: 100)
        let t400 = ExposureCalculator.calculateShutterForLockedAperture(aperture: 8, pointEV: ev, iso: 400)
        near(t100, 1.0/125, 1e-8, "f/8 at EV100 12.9658 must be 1/125s")
        near(t400, 1.0/500, 1e-8, "ISO 400 must be two stops faster than ISO 100")
        near(ExposureCalculator.nearestStandardShutter(1.0/170), 1.0/160, 1e-8, "Snap in exposure stops, not absolute seconds")
        let adjusted = ExposureCalculator.calculateExposure(zones: [5], minZone: 0, maxZone: 10, iso: 100, manualCompensation: 1)
        let neutral = ExposureCalculator.calculateExposure(zones: [5], minZone: 0, maxZone: 10, iso: 100, manualCompensation: 0)
        let exposureRatio = (adjusted.shutterSpeed / pow(adjusted.aperture, 2)) / (neutral.shutterSpeed / pow(neutral.aperture, 2))
        near(exposureRatio, 2, 1e-8, "+1 exposure compensation must add exactly one stop")
        near(ExposureCalculator.calibrationOffset(rawEV100: 10, referenceEV100: 10.7) ?? 0, 0.7, 1e-8, "Calibration uses reference minus raw EV100")
        guard ExposureCalculator.calibrationOffset(rawEV100: .nan, referenceEV100: 10) == nil,
              ExposureCalculator.calibrationOffset(rawEV100: 10, referenceEV100: 25) == nil else {
            fatalError("Reject invalid or implausibly large calibration offsets")
        }
        for iso in [50, 100, 400, 800] {
            for ev in stride(from: -5.0, through: 20.0, by: 0.25) {
                for aperture in [1.4, 2.8, 8, 16] {
                    let result = ExposureCalculator.recommend(ev100: ev, iso: iso, lockedAperture: aperture)
                    let recovered = log2(pow(result.aperture, 2) / result.shutterSpeed) - log2(Double(iso) / 100)
                    near(recovered, ev, 1e-8, "Physical equation sweep")
                }
                let automatic = ExposureCalculator.recommend(ev100: ev, iso: iso)
                near(log2(pow(automatic.aperture, 2) / automatic.shutterSpeed) - log2(Double(iso) / 100), ev, 1e-8, "Automatic recommendations preserve scene exposure")
            }
        }
        near(ExposureCalculator.optimalPlacement(zones: [2.2, 5, 7.7], minZone: 3, maxZone: 8), 0.55, 1e-8, "Unfit scene uses continuous minimax placement")
        near(ExposureCalculator.previewOverlayOpacity(stops: 0), 0, 1e-8, "Neutral preview is unchanged")
        near(ExposureCalculator.previewOverlayOpacity(stops: -1), 0.5, 1e-8, "One stop darker halves the displayed signal")
        near(ExposureCalculator.previewOverlayOpacity(stops: 1), 0.5, 1e-8, "Positive preview has a bounded highlight overlay")
        near(ExposureCalculator.previewOverlayOpacity(stops: .nan), 0, 1e-8, "Invalid compensation is neutral")
        print("ExposureAccuracyTests passed")
    }
}
