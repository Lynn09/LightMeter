import AVFoundation
import Combine
import CoreImage

// MARK: - Camera Manager

/// 相机管理器
/// 管理 AVCaptureSession 和处理相机权限，支持实时帧捕获用于测光
@MainActor
final class CameraManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 相机权限状态
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    /// 是否有权限访问相机
    @Published private(set) var hasPermission: Bool = false

    /// 是否正在运行
    @Published private(set) var isRunning: Bool = false

    /// 错误信息
    @Published private(set) var error: CameraError?

    @Published private(set) var rangefinder = RangefinderReading()
    @Published private(set) var rangefinderStatus = "正在连接 LiDAR"
    @Published private(set) var supportsLiDAR = false
    @Published private(set) var hasVideoFrames = false
    @Published private(set) var isPreviewing = false
    @Published private(set) var previewRevision = 0
    private var startupRequestedAt: TimeInterval?
    private var previewRecovery = CameraPreviewRecovery()
    private var acceptsDepthReadings = false
    private var depthAcceptAfter: TimeInterval = 0
    // Capture configuration is owned exclusively by sessionQueue, never the main actor.
    nonisolated(unsafe) private var depthDataOutput: AVCaptureDepthDataOutput?
    nonisolated(unsafe) private var depthReceiver: LiDARDepthReceiver?
    nonisolated(unsafe) private var startupRecovery = CameraStartupRecovery()

    func toggleDistanceLock() {
        expireDistance()
        if rangefinder.isLocked {
            // Only frames captured after unlocking may become the next live reading.
            depthAcceptAfter = ProcessInfo.processInfo.systemUptime
        }
        rangefinder.toggleLock()
    }

    func expireDistance() {
        rangefinder.expire(at: ProcessInfo.processInfo.systemUptime)
        guard let startedAt = startupRequestedAt, error == nil else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        switch previewRecovery.check(elapsed: elapsed, hasVideo: hasVideoFrames, isPreviewing: isPreviewing) {
        case .none: break
        case .reconnect:
            previewRevision += 1
        case .showFailure:
            error = .configurationFailed(hasVideoFrames
                ? "已收到相机画面，但预览连接失败，请点击重试。"
                : "相机启动超时，尚未收到视频画面，请点击重试。")
        }
    }

    func previewDidChange(_ visible: Bool) {
        #if DEBUG
        print("[LightMeter camera] previewing=\(visible)")
        #endif
        guard startupRequestedAt != nil else { return }
        isPreviewing = visible
    }

    // MARK: - Properties

    /// 相机会话
    nonisolated(unsafe) let session = AVCaptureSession()

    /// 视频输入设备
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?

    /// 视频数据输出（用于捕获实时帧进行测光）
    nonisolated(unsafe) private var videoDataOutput: AVCaptureVideoDataOutput?

    /// 会话队列
    nonisolated private let sessionQueue = DispatchQueue(label: "com.lightmeter.session.queue")

    /// 视频输出队列（用于处理帧数据）
    nonisolated private let videoOutputQueue = DispatchQueue(label: "com.lightmeter.video.output", qos: .userInitiated)

    /// 当前最新帧缓存
    // Both video callbacks and main-actor metering access this only under frameLock.
    nonisolated(unsafe) private var currentFrame: CVImageBuffer?
    nonisolated(unsafe) private var currentFrameCapturedAt: TimeInterval = 0
    @Published private(set) var isMetering = false
    @Published private(set) var meteringMessage: String?
    private var measurementGeneration = 0
    private weak var registeredPreviewLayer: AVCaptureVideoPreviewLayer?

    func registerPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) { registeredPreviewLayer = layer }


    /// 帧访问锁
    nonisolated private let frameLock = NSLock()

    // MARK: - Initialization

    override init() {
        super.init()

        if AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) == nil {
            rangefinderStatus = "此设备不支持 LiDAR 测距"
        }

        // 检查当前权限状态
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        hasPermission = authorizationStatus == .authorized

        // Configure on explicit permission/start requests, after the view has appeared.
    }

    // MARK: - Public Methods

    /// 请求相机权限
    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            // 请求权限
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                self.hasPermission = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            if granted {
                configureSession()
            }

        case .restricted, .denied:
            await MainActor.run {
                self.hasPermission = false
                self.authorizationStatus = status
                self.error = .permissionDenied
            }

        case .authorized:
            await MainActor.run {
                self.hasPermission = true
                self.authorizationStatus = .authorized
            }
            configureSession()

        @unknown default:
            break
        }
    }

    /// 开始相机会话
    func startSession() {
        #if DEBUG
        print("[LightMeter camera] start requested; permission=\(hasPermission)")
        #endif
        guard hasPermission else {
            error = .permissionDenied
            return
        }

        acceptsDepthReadings = true
        depthAcceptAfter = ProcessInfo.processInfo.systemUptime
        error = nil
        if startupRequestedAt == nil {
            startupRequestedAt = ProcessInfo.processInfo.systemUptime
            hasVideoFrames = false
            isPreviewing = false
            previewRecovery.reset()
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.frameLock.lock()
                self.currentFrame = nil
                self.frameLock.unlock()
                let token = self.startupRecovery.begin()
                #if DEBUG
                print("[LightMeter camera] starting; inputs=\(self.session.inputs.count), outputs=\(self.session.outputs.count)")
                #endif
                self.session.startRunning()
                #if DEBUG
                print("[LightMeter camera] start returned; running=\(self.session.isRunning)")
                #endif
                self.checkStartupFrames(token: token)
                Task { @MainActor in
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    /// 停止相机会话
    func stopSession() {
        #if DEBUG
        print("[LightMeter camera] stop requested")
        #endif
        acceptsDepthReadings = false
        measurementGeneration += 1
        isMetering = false
        rangefinder.reset()
        startupRequestedAt = nil
        hasVideoFrames = false
        isPreviewing = false
        isRunning = false
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.startupRecovery.stop()
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    /// 获取预览层
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }

    // MARK: - Private Methods

    /// 配置相机会话
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Permission checks and foreground transitions may configure more than once.
            guard self.videoDeviceInput == nil else { return }

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            #if DEBUG
            print("[LightMeter camera] configuring")
            #endif

            // 设置会话质量
            self.session.sessionPreset = .high

            // 添加视频输入
            do {
                try self.addVideoInput()
                try self.addVideoDataOutput()
                self.addDepthDataOutputIfSupported()
                #if DEBUG
                print("[LightMeter camera] configured device=\(self.videoDeviceInput?.device.deviceType.rawValue ?? "none")")
                #endif
            } catch {
                // Permit a later permission/foreground retry after partial configuration.
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                self.videoDeviceInput = nil
                self.videoDataOutput = nil
                // A depth configuration failure must not disable the regular camera.
                do {
                    try self.addVideoInput(allowLiDAR: false)
                    try self.addVideoDataOutput()
                    Task { @MainActor in
                        self.supportsLiDAR = false
                        self.acceptsDepthReadings = false
                        self.rangefinderStatus = "LiDAR 暂不可用，已恢复普通相机"
                    }
                    return
                } catch {
                    self.session.inputs.forEach { self.session.removeInput($0) }
                    self.session.outputs.forEach { self.session.removeOutput($0) }
                    self.videoDeviceInput = nil
                    self.videoDataOutput = nil
                }
                Task { @MainActor in
                    self.error = .configurationFailed(error.localizedDescription)
                    self.rangefinder.reset()
                    if self.rangefinderStatus != "此设备不支持 LiDAR 测距" {
                        self.rangefinderStatus = "LiDAR 测距暂不可用"
                    }
                }
            }
        }
    }

    nonisolated private func checkStartupFrames(token: Int) {
        sessionQueue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.frameLock.lock()
            let receivedFrame = self.currentFrame != nil
            self.frameLock.unlock()
            let action = self.startupRecovery.timeout(
                token: token, receivedFrame: receivedFrame,
                usingLiDAR: self.videoDeviceInput?.device.deviceType == .builtInLiDARDepthCamera
            )
            switch action {
            case .none: break
            case .retryWithoutDepth:
                self.session.stopRunning()
                self.session.beginConfiguration()
                self.session.outputs.forEach { self.session.removeOutput($0) }
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.videoDeviceInput = nil
                self.videoDataOutput = nil
                self.depthDataOutput = nil
                self.depthReceiver = nil
                self.frameLock.lock()
                self.currentFrame = nil
                self.frameLock.unlock()
                do {
                    try self.addVideoInput(allowLiDAR: false)
                    try self.addVideoDataOutput()
                    self.session.commitConfiguration()
                    self.session.startRunning()
                    Task { @MainActor in
                        self.supportsLiDAR = false
                        self.acceptsDepthReadings = false
                        self.rangefinder.reset()
                        self.rangefinderStatus = "LiDAR 暂不可用，已恢复普通相机"
                    }
                    self.checkStartupFrames(token: token)
                } catch {
                    self.session.inputs.forEach { self.session.removeInput($0) }
                    self.session.outputs.forEach { self.session.removeOutput($0) }
                    self.videoDeviceInput = nil
                    self.videoDataOutput = nil
                    self.session.commitConfiguration()
                    Task { @MainActor in self.error = .configurationFailed(error.localizedDescription) }
                }
            case .showFailure:
                Task { @MainActor in
                    self.rangefinder.reset()
                    self.error = .configurationFailed("相机未输出画面，请关闭占用相机的应用后重试。")
                }
            }
        }
    }

    /// 添加视频数据输出（用于实时帧捕获）
    nonisolated private func addVideoDataOutput() throws {
        let videoDataOutput = AVCaptureVideoDataOutput()

        // 设置像素格式为32位BGRA，便于处理
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        // 设置输出代理
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        guard session.canAddOutput(videoDataOutput) else {
            throw CameraError.cannotAddOutput
        }

        session.addOutput(videoDataOutput)
        self.videoDataOutput = videoDataOutput
    }

    // MARK: - Public Metering Methods

    /// Optional output: failure must leave ordinary camera metering available.
    nonisolated private func addDepthDataOutputIfSupported() {
        guard videoDeviceInput?.device.deviceType == .builtInLiDARDepthCamera,
              videoDeviceInput?.device.activeDepthDataFormat != nil else {
            Task { @MainActor in self.rangefinderStatus = "此设备不支持 LiDAR 测距" }
            return
        }
        let output = AVCaptureDepthDataOutput()
        guard session.canAddOutput(output) else {
            Task { @MainActor in self.rangefinderStatus = "LiDAR 测距暂不可用" }
            return
        }
        // Avoid filling holes with inferred depth at subject boundaries.
        output.isFilteringEnabled = false
        output.alwaysDiscardsLateDepthData = true
        let receiver = LiDARDepthReceiver { [weak self] distance, capturedAt in
            Task { @MainActor [weak self] in
                guard let self, self.acceptsDepthReadings,
                      capturedAt >= self.depthAcceptAfter,
                      ProcessInfo.processInfo.systemUptime - capturedAt < 0.5 else { return }
                self.rangefinder.update(distance, at: capturedAt)
            }
        }
        output.setDelegate(receiver, callbackQueue: videoOutputQueue)
        session.addOutput(output)
        depthReceiver = receiver
        depthDataOutput = output
        Task { @MainActor in
            self.supportsLiDAR = true
            self.rangefinderStatus = "对准主体测距"
        }
    }

    /// Uses the preview layer's transform, including portrait rotation and aspect-fill crop.
    func meter(at normalizedPreviewPoint: CGPoint) async -> CameraMeteringReading? {
        guard !isMetering else { return nil }
        guard isRunning, hasVideoFrames, let layer = registeredPreviewLayer,
              layer.bounds.width > 0, layer.bounds.height > 0 else {
            meteringMessage = "相机尚未就绪，请稍后再测光。"
            return nil
        }
        let layerPoint = CGPoint(x: normalizedPreviewPoint.x * layer.bounds.width,
                                 y: normalizedPreviewPoint.y * layer.bounds.height)
        let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        isMetering = true
        meteringMessage = nil
        let generation = measurementGeneration
        defer { if measurementGeneration == generation { isMetering = false } }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                sessionQueue.async { [weak self] in
                    guard let self, let device = self.videoDeviceInput?.device, self.session.isRunning else {
                        continuation.resume(throwing: CameraError.deviceNotFound)
                        return
                    }
                    do {
                        guard device.isExposurePointOfInterestSupported,
                              device.isExposureModeSupported(.continuousAutoExposure) else {
                            throw CameraError.configurationFailed("此相机不支持位置测光。")
                        }
                        try device.lockForConfiguration()
                        device.exposurePointOfInterest = devicePoint
                        device.setExposureTargetBias(0, completionHandler: nil)
                        device.exposureMode = .continuousAutoExposure
                        device.unlockForConfiguration()
                        continuation.resume()
                    } catch { continuation.resume(throwing: error) }
                }
            }
            // The device may briefly report its previous stable state after changing the ROI.
            try await Task.sleep(nanoseconds: 300_000_000)
            var convergence = ExposureConvergence()
            for _ in 0..<30 {
                try Task.checkCancellation()
                guard generation == measurementGeneration else { return nil }
                let snapshot = await exposureSnapshot()
                guard generation == measurementGeneration, !Task.isCancelled, isRunning else { return nil }
                if let snapshot, let raw = convergence.append(snapshot) {
                    let offset = UserDefaults.standard.double(forKey: "metering.calibration.\(snapshot.cameraID)")
                    let calibrated = raw + (offset.isFinite && abs(offset) <= 5 ? offset : 0)
                    #if DEBUG
                    print("[LightMeter metering] stable EV100=\(calibrated), spread=\(convergence.spread)")
                    #endif
                    return CameraMeteringReading(rawEV100: raw, ev100: calibrated,
                        cameraID: snapshot.cameraID, spreadEV: convergence.spread)
                }
                try await Task.sleep(nanoseconds: 80_000_000)
            }
            meteringMessage = "光线尚未稳定或超出相机测光范围，请对准主体后重试。"
        } catch is CancellationError {
            return nil
        } catch {
            if generation == measurementGeneration { meteringMessage = error.localizedDescription }
        }
        return nil
    }

    private func exposureSnapshot() async -> CameraExposureSnapshot? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, let device = self.videoDeviceInput?.device, self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                self.frameLock.lock()
                let fresh = self.currentFrame != nil && ProcessInfo.processInfo.systemUptime - self.currentFrameCapturedAt < 0.3
                self.frameLock.unlock()
                continuation.resume(returning: CameraExposureSnapshot(aperture: Double(device.lensAperture),
                    duration: CMTimeGetSeconds(device.exposureDuration), iso: Double(device.iso),
                    targetOffset: Double(device.exposureTargetOffset), targetBias: Double(device.exposureTargetBias),
                    isAdjusting: device.isAdjustingExposure, hasFreshFrame: fresh, cameraID: device.uniqueID))
            }
        }
    }

    /// Calibration is per capture device, and separate from artistic exposure compensation.
    func calibrate(rawEV100: Double, referenceEV100: Double, cameraID: String) -> Double? {
        guard let offset = ExposureCalculator.calibrationOffset(rawEV100: rawEV100, referenceEV100: referenceEV100) else { return nil }
        UserDefaults.standard.set(offset, forKey: "metering.calibration.\(cameraID)")
        return offset
    }

    /// 添加视频输入
    nonisolated private func addVideoInput(allowLiDAR: Bool = true) throws {
        // 获取后置摄像头
        let lidar = allowLiDAR ? AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) : nil
        let depthVideoFormat = lidar?.formats.last {
            let dimensions = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return dimensions.width <= 1920 && !($0.supportedDepthDataFormats.isEmpty)
                && !$0.isVideoBinned
                && $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
                && $0.supportedDepthDataFormats.contains {
                    CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
                        && $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
                }
                && CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        }
        guard let videoDevice = (depthVideoFormat == nil ? nil : lidar)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotFound
        }

        // Attach the input BEFORE setting formats: adding an input can select a new format.
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else { throw CameraError.cannotAddInput }
        session.addInput(videoInput)
        videoDeviceInput = videoInput
        session.sessionPreset = .high

        // 配置设备以获得更好曝光控制
        try videoDevice.lockForConfiguration()
        defer { videoDevice.unlockForConfiguration() }

        if videoDevice.deviceType == .builtInLiDARDepthCamera, let format = depthVideoFormat {
            // Setting activeFormat on the attached device selects inputPriority automatically.
            // Do not mutate the session preset while holding the device configuration lock.
            videoDevice.activeFormat = format
            videoDevice.activeDepthDataFormat = format.supportedDepthDataFormats.last {
                CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
                    && $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
            }
            videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            videoDevice.videoZoomFactor = 1
        }

        // 设置曝光模式为自动（支持连续自动曝光）
        if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
            videoDevice.exposureMode = .continuousAutoExposure
        }

        // 设置对焦模式
        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            videoDevice.focusMode = .continuousAutoFocus
        }

        // 设置白平衡
        if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
        }

    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 从 sample buffer 中提取图像缓冲区
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // 更新当前帧（线程安全）
        frameLock.lock()
        let isFirstFrame = currentFrame == nil
        currentFrame = imageBuffer
        currentFrameCapturedAt = ProcessInfo.processInfo.systemUptime
        frameLock.unlock()
        if isFirstFrame {
            #if DEBUG
            print("[LightMeter camera] first video frame")
            #endif
            Task { @MainActor [weak self] in
                guard let self, self.startupRequestedAt != nil else { return }
                self.hasVideoFrames = true
            }
        }
    }
}

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case cannotAddInput
    case cannotAddOutput
    case configurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "相机权限被拒绝。请在设置中允许访问相机。"
        case .deviceNotFound:
            return "无法找到相机设备。"
        case .cannotAddInput:
            return "无法添加相机输入。"
        case .cannotAddOutput:
            return "无法添加视频输出。"
        case .configurationFailed(let message):
            return "相机配置失败: \(message)"
        }
    }
}
