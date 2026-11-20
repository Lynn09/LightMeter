import Foundation

@main
enum MeteringPipelineTests {
    @MainActor static func main() {
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            guard value() else { fatalError(message) }
        }
        let model = MeteringViewModel()
        model.lockAperture(8)
        model.addMeteringPoint(x: 0.5, y: 0.5, ev100: 10.25)
        check(model.meteringPoints.count == 1, "Measured EV100 reaches the point model")
        let result = model.currentExposure
        check(abs(result.ev - 10.25) < 1e-9, "Do not reconstruct EV from an integer Zone")
        let iso = model.selectedFilm.iso
        let physicalEV = log2(result.aperture * result.aperture / result.shutterSpeed) - log2(Double(iso) / 100)
        check(abs(physicalEV - result.ev) < 1e-9, "Recommended settings satisfy the physical exposure equation")
        let original = result.shutterSpeed
        model.setManualExposureOffset(1)
        check(abs(model.currentExposure.shutterSpeed / original - 2) < 1e-9, "Manual +1 compensation adds one stop with a locked aperture")
        check(model.currentExposure.ev == 10.25, "Exposure adjustment must not change the measured scene value")
        model.resetToAutoExposure()
        model.endShutterDragWithOffset(1)
        check(model.currentExposure.shutterSpeed < original, "Positive shutter drag must make the shutter faster")
        model.selectFilm(.velvia50)
        check(model.currentExposure.iso == 50, "Film ISO applies to all exposure paths")
        check(model.meteringPoints[0].exposureParams?.iso == 50, "Film change recomputes per-point recommendations")
        model.resetShutterOffset()
        model.addMeteringPoint(x: 0.2, y: 0.2, ev100: 10.75)
        check(abs(model.currentExposure.ev - 10.5) < 1e-9, "Average continuous EV values, not rounded Zones")
        let pointID = model.meteringPoints[0].id
        model.selectPoint(id: pointID)
        check(model.selectedPoint?.id == pointID, "Tap a point to inspect its settings inline")
        model.selectPoint(id: pointID)
        check(model.selectedPoint == nil, "Tap the selected point again to return to average exposure")
        check(model.mode == .metering, "Start in exposure metering mode")
        model.mode = .rangefinder
        model.addMeteringPoint(x: 0.3, y: 0.4, ev100: 15)
        check(!model.canAddMeteringPoint && model.meteringPoints.count == 2, "Rangefinding must not add exposure samples")
        model.mode = .metering
        check(model.canAddMeteringPoint && model.lockedAperture == 8 && model.currentExposure.ev == 10.5,
              "Returning from rangefinding preserves the exposure setup")
        let calibrated = MeteringViewModel()
        calibrated.addMeteringPoint(x: 0.5, y: 0.5, ev100: 10, rawEV100: 10, cameraID: "wide")
        calibrated.addMeteringPoint(x: 0.6, y: 0.6, ev100: 12, rawEV100: 12, cameraID: "other")
        calibrated.applyCalibration(cameraID: "wide", offset: 0.7)
        calibrated.applyCalibration(cameraID: "wide", offset: 0.7)
        check(abs(calibrated.meteringPoints[0].ev - 10.7) < 1e-9, "Repeated calibration must use raw EV, not accumulate corrections")
        check(calibrated.meteringPoints[1].ev == 12, "Calibration is scoped to the capture lens")
        calibrated.applyCalibration(cameraID: "wide", offset: 0)
        check(calibrated.meteringPoints[0].ev == 10, "Clearing calibration restores raw readings")
        let invalid = MeteringViewModel()
        invalid.addMeteringPoint(x: 0.5, y: 0.5, ev100: .nan)
        check(invalid.meteringPoints.isEmpty, "Failed metering must not create a fake point")
        print("MeteringPipelineTests passed")
    }
}
