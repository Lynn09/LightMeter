import Foundation

/// Independent of camera hardware so filtering and locking can be tested on the host.
struct RangefinderReading {
    private(set) var meters: Double?
    private(set) var isLocked = false
    private var history: [Double] = []
    private var lastUpdate: TimeInterval?

    /// Conservative working range, not a claim about hardware precision.
    static let workingRange = 0.15...5.0

    static func distance(from samples: [Float]) -> Double? {
        let valid = samples.map(Double.init)
            .filter { $0.isFinite && workingRange.contains($0) }.sorted()
        guard !valid.isEmpty, valid.count * 2 > samples.count else { return nil }
        let median = valid[valid.count / 2]
        // Reject foreground/background boundaries rather than averaging across them.
        let nearSurface = valid.filter { abs($0 - median) <= max(0.05, median * 0.1) }
        guard nearSurface.count * 5 >= valid.count * 4 else { return nil }
        return median
    }

    mutating func update(_ distance: Double?, at time: TimeInterval) {
        guard !isLocked else { return }
        if let lastUpdate, time < lastUpdate { return }
        guard let distance, distance.isFinite, Self.workingRange.contains(distance) else {
            reset()
            return
        }
        if let previous = history.last, abs(distance - previous) > max(0.25, previous * 0.15) {
            history.removeAll()
        }
        history.append(distance)
        if history.count > 5 { history.removeFirst() }
        meters = history.reduce(0, +) / Double(history.count)
        lastUpdate = time
    }

    mutating func toggleLock() {
        if isLocked { reset() }
        else if meters != nil { isLocked = true }
    }

    mutating func expire(at time: TimeInterval) {
        guard !isLocked, let lastUpdate, time - lastUpdate > 0.75 else { return }
        reset()
    }

    mutating func reset() {
        meters = nil
        isLocked = false
        history.removeAll()
        lastUpdate = nil
    }
}
