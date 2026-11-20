@main
enum CameraStartupRecoveryTests {
    static func main() {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        var recovery = CameraStartupRecovery()
        let token = recovery.begin()
        check(recovery.timeout(token: token, receivedFrame: false, usingLiDAR: true) == .retryWithoutDepth,
              "LiDAR with no video must fall back to the ordinary camera")
        check(recovery.timeout(token: token, receivedFrame: false, usingLiDAR: false) == .showFailure,
              "Failed fallback must report a visible camera error")
        check(recovery.timeout(token: token, receivedFrame: false, usingLiDAR: true) == .showFailure,
              "Recovery must not loop on LiDAR")
        let next = recovery.begin()
        check(recovery.timeout(token: next, receivedFrame: true, usingLiDAR: true) == .none,
              "A camera delivering video must keep depth capture")
        recovery.stop()
        check(recovery.timeout(token: next, receivedFrame: false, usingLiDAR: true) == .none,
              "A backgrounded camera must not be restarted by a delayed timeout")
        let current = recovery.begin()
        check(recovery.timeout(token: token, receivedFrame: false, usingLiDAR: true) == .none,
              "Old timeouts cannot alter a new session")
        check(recovery.timeout(token: current, receivedFrame: false, usingLiDAR: false) == .showFailure,
              "A non-LiDAR failure must be reported directly")
        var preview = CameraPreviewRecovery()
        check(preview.check(elapsed: 1, hasVideo: true, isPreviewing: false) == .none,
              "Allow the preview layer time to connect")
        check(preview.check(elapsed: 3, hasVideo: true, isPreviewing: false) == .reconnect,
              "Video frames with an invisible preview require a new preview connection")
        check(preview.check(elapsed: 3.2, hasVideo: true, isPreviewing: false) == .none,
              "Do not reconnect on every timer tick")
        check(preview.check(elapsed: 7, hasVideo: true, isPreviewing: false) == .showFailure,
              "A failed preview reconnection must show a visible error")
        preview.reset()
        check(preview.check(elapsed: 9, hasVideo: false, isPreviewing: false) == .showFailure,
              "An unstarted or blocked capture queue must not remain silently black")
        preview.reset()
        check(preview.check(elapsed: 9, hasVideo: true, isPreviewing: true) == .none,
              "A healthy preview does not trigger recovery")
        print("CameraStartupRecoveryTests passed")
    }
}
