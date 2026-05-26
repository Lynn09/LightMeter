import Foundation

@main
struct ExposureCoupledControlsTest {
    static func main() {
        let aperturePriority = ExposureCalculator.calculateCoupledExposure(
            ev: ExposureCalculator.referenceEV,
            iso: 100,
            lockedAperture: 11.0,
            lockedShutterSpeed: nil
        )

        precondition(aperturePriority.aperture == 11.0)
        precondition(abs(aperturePriority.shutterSpeed - 1.0 / 60.0) < 0.001)

        let shutterPriority = ExposureCalculator.calculateCoupledExposure(
            ev: ExposureCalculator.referenceEV,
            iso: 100,
            lockedAperture: nil,
            lockedShutterSpeed: 1.0 / 250.0
        )

        precondition(shutterPriority.shutterSpeed == 1.0 / 250.0)
        precondition(abs(shutterPriority.aperture - 5.6) < 0.01)
    }
}
