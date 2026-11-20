import Foundation

@main
enum RangefinderReadingTests {
    static func main() {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        let surface = Array(repeating: Float(2), count: 23) + [.nan, 100]
        check(RangefinderReading.distance(from: surface) == 2, "Reject invalid pixels and use the median surface distance")
        check(RangefinderReading.distance(from: [.nan, 0, -.infinity, 20]) == nil, "Invalid and out-of-range depths must not become distances")
        check(RangefinderReading.distance(from: [1, 1, 1, 4, 4]) == nil, "A depth boundary must not produce a misleading distance")
        check(RangefinderReading.distance(from: [2, .nan, .nan]) == nil, "Require a majority of valid samples")
        check(RangefinderReading.distance(from: []) == nil, "Empty patches are unavailable")
        check(RangefinderReading.distance(from: [0.1, 0.1, 0.1]) == nil, "Too-close targets are unavailable")

        var reading = RangefinderReading()
        reading.toggleLock()
        check(!reading.isLocked, "Cannot lock an empty reading")
        reading.update(2, at: 0)
        check(reading.meters == 2, "First valid reading appears immediately")
        reading.update(2.1, at: 0.1)
        check(abs((reading.meters ?? 0) - 2.05) < 0.001, "Smooth small fluctuations")
        reading.toggleLock()
        reading.update(4, at: 0.2)
        reading.expire(at: 2)
        check(reading.isLocked && abs((reading.meters ?? 0) - 2.05) < 0.001, "Locked reading stays frozen")
        reading.toggleLock()
        check(!reading.isLocked && reading.meters == nil, "Unlock clears stale history before resuming")
        reading.update(4, at: 3)
        check(reading.meters == 4, "New surface does not blend with the old target")
        reading.update(nil, at: 3.1)
        check(reading.meters == nil, "Invalid depth clears the live reading")
        reading.update(2, at: 4)
        reading.expire(at: 4.5)
        check(reading.meters != nil, "Fresh data stays visible")
        reading.expire(at: 5)
        check(reading.meters == nil, "Missing depth frames expire rather than showing stale data")
        reading.update(2, at: 6)
        reading.update(4, at: 6.1)
        check(reading.meters == 4, "A different target resets smoothing")
        reading.update(1, at: 5.9)
        check(reading.meters == 4, "Late callbacks cannot replace a newer target")
        reading.toggleLock()
        reading.reset()
        check(reading.meters == nil && !reading.isLocked, "Stopping capture clears even a locked reading")
        reading.update(.nan, at: 7)
        check(reading.meters == nil, "Nonfinite readings cannot reach the UI")
        print("RangefinderReadingTests passed")
    }
}
