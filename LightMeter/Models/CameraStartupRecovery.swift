/// Owned by the serial capture queue. Tokens invalidate delayed work after stop/restart.
struct CameraStartupRecovery {
    enum Action: Equatable { case none, retryWithoutDepth, showFailure }
    private(set) var generation = 0
    private var wantsRunning = false
    private var retried = false

    mutating func begin() -> Int {
        generation += 1
        wantsRunning = true
        retried = false
        return generation
    }

    mutating func stop() {
        generation += 1
        wantsRunning = false
    }

    mutating func timeout(token: Int, receivedFrame: Bool, usingLiDAR: Bool) -> Action {
        guard wantsRunning, token == generation, !receivedFrame else { return .none }
        if usingLiDAR && !retried {
            retried = true
            return .retryWithoutDepth
        }
        return .showFailure
    }
}

struct CameraPreviewRecovery {
    enum Action: Equatable { case none, reconnect, showFailure }
    private var reconnectedAt: Double?
    mutating func reset() { reconnectedAt = nil }
    mutating func check(elapsed: Double, hasVideo: Bool, isPreviewing: Bool) -> Action {
        guard !isPreviewing else { return .none }
        if hasVideo, elapsed >= 2, reconnectedAt == nil {
            reconnectedAt = elapsed
            return .reconnect
        }
        if let reconnectedAt, elapsed - reconnectedAt >= 3 { return .showFailure }
        if !hasVideo, elapsed >= 8 { return .showFailure }
        return .none
    }
}
