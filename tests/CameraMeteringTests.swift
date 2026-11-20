import Foundation

@main
enum CameraMeteringTests {
    static func main() {
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            guard value() else { fatalError(message) }
        }
        func snapshot(duration: Double = 1.0/125, iso: Double = 100, adjusting: Bool = false,
                      offset: Double = 0, bias: Double = 0, fresh: Bool = true) -> CameraExposureSnapshot {
            CameraExposureSnapshot(aperture: 8, duration: duration, iso: iso, targetOffset: offset,
                                   targetBias: bias, isAdjusting: adjusting, hasFreshFrame: fresh, cameraID: "test")
        }
        let ev = ExposureCalculator.ev100(aperture: 8, duration: 1.0/125, iso: 100)!
        check(abs(ev - 12.965784284662087) < 1e-9, "Physical EV100 reference")
        let sameLight = ExposureCalculator.ev100(aperture: 8, duration: 1.0/250, iso: 200)!
        check(abs(sameLight - ev) < 1e-9, "Changing camera AE ISO/time must not change scene EV100")
        check(ExposureCalculator.ev100(aperture: 0, duration: 0, iso: 0) == nil, "Uninitialized metadata is not a measurement")
        check(ExposureCalculator.ev100(aperture: .nan, duration: 1, iso: 100) == nil, "Nonfinite metadata is unavailable")
        var convergence = ExposureConvergence()
        for _ in 0..<3 { check(convergence.append(snapshot()) == nil, "Require several settled samples") }
        check(abs((convergence.append(snapshot()) ?? 0) - ev) < 1e-9, "Settled metadata produces a stable EV100")
        check(convergence.append(snapshot(adjusting: true)) == nil, "Do not meter while AE is changing")
        check(convergence.append(snapshot(offset: 1.5)) == nil, "Reject light outside camera AE limits instead of applying an unverified offset")
        check(convergence.append(snapshot(bias: 1)) == nil, "Nonzero camera exposure bias must not contaminate EV100")
        check(convergence.append(snapshot(fresh: false)) == nil, "A stopped camera cannot meter from an old frame")
        for t in [1.0/125, 1.0/60, 1.0/250, 1.0/30] {
            check(convergence.append(snapshot(duration: t)) == nil, "Unstable lighting must not be reported as precise data")
        }
        print("CameraMeteringTests passed")
    }
}
