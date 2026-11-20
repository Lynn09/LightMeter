import AVFoundation

/// All delegate calls arrive on CameraManager's serial video queue.
final class LiDARDepthReceiver: NSObject, AVCaptureDepthDataOutputDelegate {
    private let onReading: @Sendable (Double?, TimeInterval) -> Void
    private var lastDelivery: TimeInterval = 0

    init(onReading: @escaping @Sendable (Double?, TimeInterval) -> Void) {
        self.onReading = onReading
    }

    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime, connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastDelivery >= 0.1 else { return }
        lastDelivery = now
        guard depthData.depthDataAccuracy == .absolute,
              depthData.depthDataQuality == .high else {
            onReading(nil, now)
            return
        }
        let buffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else {
            onReading(nil, now)
            return
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width >= 5, height >= 5, let address = CVPixelBufferGetBaseAddress(buffer) else {
            onReading(nil, now)
            return
        }
        // An aspect-fill preview preserves the image center, including in portrait.
        // Sample a small central patch; use the row stride, not width, for indexing.
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.stride
        let pixels = address.assumingMemoryBound(to: Float.self)
        var samples: [Float] = []
        for y in (height / 2 - 2)...(height / 2 + 2) {
            for x in (width / 2 - 2)...(width / 2 + 2) {
                samples.append(pixels[y * stride + x])
            }
        }
        onReading(RangefinderReading.distance(from: samples), now)
    }
}
