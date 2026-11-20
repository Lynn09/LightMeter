import Foundation

/// Scene values are always EV100. Camera settings obey N²/t = 2^EV100 × ISO/100.
struct ExposureCalculator {
    /// Display-only approximation on the processed camera feed, not a film rendering model.
    static func previewOverlayOpacity(stops: Double) -> Double {
        guard stops.isFinite else { return 0 }
        return 1 - pow(2, -min(5, abs(stops)))
    }
    static let calibrationConstant = 12.5
    static let baseAperture = 8.0
    static let baseShutterSpeed = 1.0 / 125.0
    // A legacy Zone reference, derived from the settings instead of an arbitrary 12.5.
    static let referenceEV = log2(8.0 * 8.0 * 125.0)
    static let standardApertures: [Double] = [1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4, 4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14, 16, 18, 20, 22, 25, 29, 32]
    static let standardShutterSpeeds: [Double] =
        [8000.0, 6400, 5000, 4000, 3200, 2500, 2000, 1600, 1250, 1000, 800, 640, 500, 400, 320, 250, 200, 160, 125, 100, 80, 60, 50, 40, 30, 25, 20, 15, 13, 10, 8, 6, 5, 4, 3, 2.5, 2, 1.6, 1.3].map { 1 / $0 }
        + [1, 1.3, 1.6, 2, 2.5, 3.2, 4, 5, 6, 8, 10, 13, 15, 20, 25, 30]

    static func ev100(aperture: Double, duration: Double, iso: Double) -> Double? {
        guard aperture.isFinite, duration.isFinite, iso.isFinite,
              aperture > 0, duration > 0, iso > 0 else { return nil }
        return 2 * log2(aperture) - log2(duration) - log2(iso / 100)
    }

    static func calibrationOffset(rawEV100: Double, referenceEV100: Double) -> Double? {
        let offset = referenceEV100 - rawEV100
        guard rawEV100.isFinite, referenceEV100.isFinite, abs(offset) <= 5 else { return nil }
        return offset
    }

    static func shutter(aperture: Double, ev100: Double, iso: Int) -> Double {
        guard aperture > 0, aperture.isFinite, ev100.isFinite, iso > 0 else { return .nan }
        return pow(aperture, 2) / (pow(2, ev100) * Double(iso) / 100)
    }

    /// Compensation changes exposure time once; it never rewrites the measured scene EV.
    static func recommend(ev100: Double, iso: Int, lockedAperture: Double? = nil,
                          preferredShutter: Double = baseShutterSpeed, compensation: Double = 0)
        -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        let aperture = lockedAperture ?? nearestStandardAperture(sqrt(pow(2, ev100) * Double(iso) / 100 * preferredShutter))
        return (aperture, shutter(aperture: aperture, ev100: ev100 - compensation, iso: iso), iso, ev100)
    }

    static func evToZone(ev: Double, referenceEV: Double = referenceEV) -> Int {
        guard ev.isFinite, referenceEV.isFinite else { return 5 }
        return Int(max(0, min(10, (ev - referenceEV + 5).rounded())))
    }
    static func zoneToEV(zone: Int, referenceEV: Double = referenceEV) -> Double { referenceEV + Double(zone) - 5 }
    static func calculateAperture(baseAperture: Double, stops: Double) -> Double { baseAperture / pow(2, stops / 2) }
    static func calculateShutterSpeed(baseShutterSpeed: Double, stops: Double) -> Double { baseShutterSpeed * pow(2, stops) }
    static func calculateExposureAdjustment(currentZones: [Int], targetZone: Int = 5) -> Double {
        currentZones.isEmpty ? 0 : Double(targetZone) - Double(currentZones.reduce(0, +)) / Double(currentZones.count)
    }
    static func distanceToLatitude(zone: Double, minZone: Int, maxZone: Int) -> Double {
        max(Double(minZone) - zone, zone - Double(maxZone), 0)
    }
    static func optimalPlacement(zones: [Double], minZone: Int, maxZone: Int) -> Double {
        guard let low = zones.min(), let high = zones.max(), minZone <= maxZone else { return 0 }
        let mean = zones.reduce(0, +) / Double(zones.count)
        let lower = Double(minZone) - low
        let upper = Double(maxZone) - high
        let shift = lower <= upper ? min(upper, max(lower, 5 - mean)) : (lower + upper) / 2
        return min(5, max(-5, shift))
    }
    static func calculateOptimalAdjustment(zones: [Int], minZone: Int, maxZone: Int,
                                           step: Double = 0.05, range: ClosedRange<Double> = -5...5) -> Double {
        min(range.upperBound, max(range.lowerBound, optimalPlacement(zones: zones.map(Double.init), minZone: minZone, maxZone: maxZone)))
    }
    static func nearestStandardShutter(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return baseShutterSpeed }
        return standardShutterSpeeds.min { abs(log2($0 / value)) < abs(log2($1 / value)) } ?? value
    }
    static func nearestStandardAperture(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return baseAperture }
        return standardApertures.min { abs(2 * log2($0 / value)) < abs(2 * log2($1 / value)) } ?? value
    }
    static func calculateShutterForLockedAperture(aperture: Double, pointEV: Double, iso: Int) -> Double {
        shutter(aperture: aperture, ev100: pointEV, iso: iso)
    }
    static func calculateExposureForSinglePoint(pointZone: Int, pointEV: Double, lockedAperture: Double, iso: Int)
        -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double, zone: Int) {
        (lockedAperture, shutter(aperture: lockedAperture, ev100: pointEV, iso: iso), iso, pointEV, pointZone)
    }
    static func calculateExposureWithLockedAperture(zones: [Int], lockedAperture: Double, iso: Int)
        -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        let ev = zones.isEmpty ? referenceEV : zones.map { zoneToEV(zone: $0) }.reduce(0, +) / Double(zones.count)
        return recommend(ev100: ev, iso: iso, lockedAperture: lockedAperture)
    }
    static func calculateExposure(zones: [Int], minZone: Int, maxZone: Int, iso: Int = 100, manualCompensation: Double? = nil)
        -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double, adjustment: Double) {
        let ev = zones.isEmpty ? referenceEV : zones.map { zoneToEV(zone: $0) }.reduce(0, +) / Double(zones.count)
        let adjustment = manualCompensation ?? calculateOptimalAdjustment(zones: zones, minZone: minZone, maxZone: maxZone)
        let result = recommend(ev100: ev, iso: iso, compensation: adjustment)
        return (result.aperture, result.shutterSpeed, iso, ev, adjustment)
    }
    static func calculateExposureWithShutterOffset(zones: [Int], shutterOffset: Double, lockedAperture: Double? = nil,
                                                   iso: Int, baseShutterSpeed: Double = 1/125.0)
        -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        let ev = zones.isEmpty ? referenceEV : zones.map { zoneToEV(zone: $0) }.reduce(0, +) / Double(zones.count)
        return recommend(ev100: ev, iso: iso, lockedAperture: lockedAperture,
                         preferredShutter: baseShutterSpeed, compensation: -shutterOffset)
    }
    static func formatAperture(_ aperture: Double) -> String {
        guard aperture.isFinite, aperture > 0 else { return "—" }
        let value = nearestStandardAperture(aperture)
        return value == floor(value) ? String(format: "f/%.0f", value) : String(format: "f/%.1f", value)
    }
    static func formatShutterSpeed(_ speed: Double) -> String {
        guard speed.isFinite, speed > 0 else { return "—" }
        // Do not silently turn a required bulb exposure into 30 seconds.
        let value = (speed < standardShutterSpeeds[0] || speed > 30) ? speed : nearestStandardShutter(speed)
        if value >= 1 { return String(format: value == floor(value) ? "%.0fs" : "%.1fs", value) }
        return "1/\(Int((1 / value).rounded()))s"
    }
    static func formatISO(_ iso: Int) -> String { "ISO \(iso)" }
    static func formatEV(_ ev: Double) -> String { ev.isFinite ? String(format: "EV100 %.1f", ev) : "EV100 —" }
    static func nearestShutterSpeed(_ speed: Double) -> (fraction: String, decimal: Double) {
        let nearest = nearestStandardShutter(speed)
        return (formatShutterSpeed(nearest).replacingOccurrences(of: "s", with: ""), nearest)
    }
}
