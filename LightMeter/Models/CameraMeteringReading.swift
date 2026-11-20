import Foundation

struct CameraExposureSnapshot: Sendable {
    let aperture: Double
    let duration: Double
    let iso: Double
    let targetOffset: Double
    let targetBias: Double
    let isAdjusting: Bool
    let hasFreshFrame: Bool
    let cameraID: String
}

struct CameraMeteringReading: Sendable {
    let rawEV100: Double
    let ev100: Double
    let cameraID: String
    let spreadEV: Double
}

struct ExposureConvergence {
    private var values: [Double] = []
    private var cameraID: String?
    var spread: Double { (values.max() ?? 0) - (values.min() ?? 0) }

    mutating func append(_ snapshot: CameraExposureSnapshot) -> Double? {
        guard snapshot.hasFreshFrame, !snapshot.isAdjusting,
              snapshot.targetOffset.isFinite, abs(snapshot.targetOffset) <= 0.2,
              snapshot.targetBias.isFinite, abs(snapshot.targetBias) <= 0.02,
              let ev = ExposureCalculator.ev100(aperture: snapshot.aperture, duration: snapshot.duration, iso: snapshot.iso)
        else { values.removeAll(); return nil }
        if cameraID != snapshot.cameraID { values.removeAll(); cameraID = snapshot.cameraID }
        values.append(ev)
        if values.count > 4 { values.removeFirst() }
        guard values.count == 4, spread <= 0.1 else { return nil }
        // Average in stop space; do not blend measurements of different targets.
        return values.reduce(0, +) / Double(values.count)
    }
}
