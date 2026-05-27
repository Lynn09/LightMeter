import AVFoundation
import Combine
import CoreImage
import CoreGraphics
import Foundation

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

    /// 是否已冻结当前帧
    @Published private(set) var isFrameFrozen: Bool = false

    /// 冻结帧预览图
    @Published private(set) var frozenFrameImage: CGImage?

    /// 当前手机镜头焦段信息
    @Published private(set) var currentLensInfo: CameraLensInfo = .unknown

    // MARK: - Properties

    /// 相机会话
    let session = AVCaptureSession()

    /// 视频输入设备
    private var videoDeviceInput: AVCaptureDeviceInput?

    /// 视频数据输出（用于捕获实时帧进行测光）
    private var videoDataOutput: AVCaptureVideoDataOutput?

    /// 会话队列
    private let sessionQueue = DispatchQueue(label: "com.lightmeter.session.queue")

    /// 视频输出队列（用于处理帧数据）
    private let videoOutputQueue = DispatchQueue(label: "com.lightmeter.video.output", qos: .userInitiated)

    /// 当前最新帧缓存
    private var currentFrame: CVImageBuffer?

    /// 冻结帧缓存
    private var frozenFrame: CVImageBuffer?

    /// 帧访问锁
    private let frameLock = NSLock()

    /// 基准 35mm 等效焦段（videoZoomFactor = 1 时）
    private var baseEquivalentFocalLength: Double?

    /// 当前选择的标准定焦
    private var selectedFocalLength: StandardFocalLength = .mm35

    /// 亮度历史记录（用于平滑处理）
    private var brightnessHistory: [Double] = []
    private let maxHistorySize = 5
    private let brightnessLock = NSLock()

    // MARK: - Initialization

    override init() {
        super.init()

        // 检查当前权限状态
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        hasPermission = authorizationStatus == .authorized

        // 如果已有权限，配置会话
        if hasPermission {
            configureSession()
        }
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
        guard hasPermission else {
            error = .permissionDenied
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor in
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    /// 停止相机会话
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
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

    /// 截取并冻结当前视频帧
    /// - Returns: 是否成功冻结
    @discardableResult
    func captureStaticFrame() -> Bool {
        frameLock.lock()
        guard let frame = currentFrame else {
            frameLock.unlock()
            return false
        }
        frozenFrame = frame
        frameLock.unlock()

        frozenFrameImage = makeCGImage(from: frame)
        isFrameFrozen = frozenFrameImage != nil
        return isFrameFrozen
    }

    /// 恢复实时取景
    func resumeLivePreview() {
        frameLock.lock()
        frozenFrame = nil
        frameLock.unlock()

        frozenFrameImage = nil
        isFrameFrozen = false
    }

    /// 选择标准定焦焦段，并通过相机 zoom 驱动系统镜头切换/变焦
    func selectFocalLength(_ focalLength: StandardFocalLength) {
        selectedFocalLength = focalLength

        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.videoDeviceInput?.device else {
                return
            }

            self.applyZoom(for: focalLength, on: device)
        }
    }

    // MARK: - Private Methods

    /// 配置相机会话
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            // 设置会话质量
            self.session.sessionPreset = .high

            // 添加视频输入
            do {
                try self.addVideoInput()
                try self.addVideoDataOutput()
            } catch {
                Task { @MainActor in
                    self.error = .configurationFailed(error.localizedDescription)
                }
            }
        }
    }

    /// 添加视频数据输出（用于实时帧捕获）
    private func addVideoDataOutput() throws {
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

    /// 获取指定位置的亮度值（带平滑处理）
    /// - Parameters:
    ///   - point: 点击位置（归一化坐标 0...1）
    ///   - regionSize: 测光区域大小（正方形边长，像素）
    /// - Returns: 归一化亮度值 [0.0, 1.0]
    func getBrightness(at point: CGPoint, regionSize: Int = 64) -> Double {
        guard let frame = activeMeteringFrame() else {
            // 无可用帧时返回历史平均值或默认值
            return getSmoothedBrightness(fallback: 0.18)
        }

        let samplingPoint = normalizedSamplingPoint(forDisplayPoint: point)
        let rawBrightness = extractBrightness(from: frame, atNormalizedPoint: samplingPoint, regionSize: regionSize)

        // 应用平滑处理
        let smoothedBrightness = addBrightnessToHistoryAndSmooth(rawBrightness)

        return smoothedBrightness
    }

    /// 对冻结帧或当前帧中的主体进行自动测光
    func getSubjectMeteringResult() -> SubjectMeteringResult? {
        guard let frame = activeMeteringFrame() else {
            return nil
        }

        return SubjectMeteringAnalyzer.analyze(gridSize: 9) { point in
            let samplingPoint = normalizedSamplingPoint(forDisplayPoint: point)
            return extractBrightness(from: frame, atNormalizedPoint: samplingPoint, regionSize: 96)
        }
    }

    // MARK: - Private Helper Methods

    /// 当前用于测光的帧。冻结后优先使用冻结帧。
    private func activeMeteringFrame() -> CVImageBuffer? {
        frameLock.lock()
        defer { frameLock.unlock() }

        return frozenFrame ?? currentFrame
    }

    /// 将预览显示坐标转换为当前测光帧的原始采样坐标
    private func normalizedSamplingPoint(forDisplayPoint point: CGPoint) -> CGPoint {
        frameLock.lock()
        let isUsingFrozenFrame = frozenFrame != nil
        frameLock.unlock()

        guard isUsingFrozenFrame else {
            return point
        }

        return StaticFramePreviewGeometry.rawPoint(
            forDisplayPoint: point,
            orientation: .portrait
        )
    }

    /// 从视频帧生成静态预览图
    private func makeCGImage(from frame: CVImageBuffer) -> CGImage? {
        let orientation = StaticFramePreviewGeometry.exifOrientation(for: .portrait)
        let ciImage = CIImage(cvImageBuffer: frame).oriented(orientation)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    /// 将亮度值添加到历史记录并返回平滑后的值
    /// 使用简单移动平均（SMA）进行平滑
    private func addBrightnessToHistoryAndSmooth(_ brightness: Double) -> Double {
        brightnessLock.lock()
        defer { brightnessLock.unlock() }

        // 添加新值到历史记录
        brightnessHistory.append(brightness)

        // 限制历史记录大小
        if brightnessHistory.count > maxHistorySize {
            brightnessHistory.removeFirst()
        }

        // 计算移动平均值
        let average = brightnessHistory.reduce(0, +) / Double(brightnessHistory.count)

        return average
    }

    /// 获取平滑后的亮度值
    /// - Parameter fallback: 无历史记录时的回退值
    /// - Returns: 平滑后的亮度值或回退值
    private func getSmoothedBrightness(fallback: Double) -> Double {
        brightnessLock.lock()
        defer { brightnessLock.unlock() }

        guard !brightnessHistory.isEmpty else {
            return fallback
        }

        return brightnessHistory.reduce(0, +) / Double(brightnessHistory.count)
    }

    // MARK: - Private Helper Methods

    /// 从图像帧中提取指定区域的平均亮度
    /// - Parameters:
    ///   - frame: 视频帧（CVImageBuffer）
    ///   - point: 中心点归一化坐标
    ///   - regionSize: 测光区域大小
    /// - Returns: 归一化亮度值 [0.0, 1.0]
    private func extractBrightness(from frame: CVImageBuffer, atNormalizedPoint point: CGPoint, regionSize: Int) -> Double {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)

        // 计算测光区域边界
        let halfSize = regionSize / 2
        let normalizedX = max(0, min(1, point.x))
        let normalizedY = max(0, min(1, point.y))
        let x = max(halfSize, min(Int(normalizedX * CGFloat(width)), width - halfSize))
        let y = max(halfSize, min(Int(normalizedY * CGFloat(height)), height - halfSize))

        guard let baseAddress = CVPixelBufferGetBaseAddress(frame) else {
            return 0.18 // 默认中灰
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(frame)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var totalBrightness: Double = 0
        var pixelCount = 0

        // 遍历测光区域内的所有像素，计算平均亮度
        for dy in -halfSize..<halfSize {
            for dx in -halfSize..<halfSize {
                let px = x + dx
                let py = y + dy

                // 计算该像素在缓冲区中的偏移
                let offset = py * bytesPerRow + px * 4 // BGRA格式，每像素4字节

                // 读取BGRA值
                let b = Double(buffer[offset])
                let g = Double(buffer[offset + 1])
                let r = Double(buffer[offset + 2])
                // a = buffer[offset + 3] (Alpha通道，忽略)

                // 使用ITU-R BT.709标准转换RGB到亮度
                // Y = 0.2126*R + 0.7152*G + 0.0722*B
                let luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0

                totalBrightness += luminance
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else {
            return 0.18
        }

        return totalBrightness / Double(pixelCount)
    }

    /// 添加视频输入
    private func addVideoInput() throws {
        // 获取后置摄像头
        guard let videoDevice = preferredBackCamera() else {
            throw CameraError.deviceNotFound
        }

        // 配置设备以获得更好曝光控制
        try videoDevice.lockForConfiguration()

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

        videoDevice.unlockForConfiguration()

        // 创建设备输入
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)

        guard self.session.canAddInput(videoInput) else {
            throw CameraError.cannotAddInput
        }

        self.session.addInput(videoInput)
        self.videoDeviceInput = videoInput
        self.updateLensInfo(for: videoDevice)
        self.applyZoom(for: selectedFocalLength, on: videoDevice)
    }

    /// 更新当前镜头焦段信息
    private func updateLensInfo(for device: AVCaptureDevice) {
        let fieldOfView = Double(device.activeFormat.videoFieldOfView)

        if baseEquivalentFocalLength == nil, fieldOfView > 0 {
            let radians = fieldOfView * .pi / 180.0
            baseEquivalentFocalLength = 36.0 / (2.0 * tan(radians / 2.0))
        }

        let base = baseEquivalentFocalLength ?? fallbackEquivalentFocalLength(for: device.deviceType)
        let equivalentFocalLength = base.map { $0 * Double(device.videoZoomFactor) }
        let displayName = CameraLensInfo.makeDisplayName(equivalentFocalLength: equivalentFocalLength)
        let zoomFactor = Double(device.videoZoomFactor)
        let renderingMode = lensRenderingMode(for: device, zoomFactor: device.videoZoomFactor)

        Task { @MainActor in
            self.currentLensInfo = CameraLensInfo(
                equivalentFocalLength: equivalentFocalLength,
                baseEquivalentFocalLength: base,
                zoomFactor: zoomFactor,
                displayName: displayName,
                renderingMode: renderingMode
            )
        }
    }

    /// 优先使用系统虚拟多摄设备，让 iOS 管理物理镜头切换
    private func preferredBackCamera() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]

        for deviceType in preferredTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return device
            }
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// 应用标准焦段对应的 zoom factor
    private func applyZoom(for focalLength: StandardFocalLength, on device: AVCaptureDevice) {
        let base = baseEquivalentFocalLength ?? fallbackEquivalentFocalLength(for: device.deviceType)
        let desiredZoom = FocalLengthPreviewGeometry.zoomFactor(
            baseEquivalentFocalLength: base,
            selectedFocalLength: focalLength
        )
        let clampedZoom = FocalLengthPreviewGeometry.clampedZoomFactor(
            desiredZoom,
            minimum: device.minAvailableVideoZoomFactor,
            maximum: device.maxAvailableVideoZoomFactor
        )

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            updateLensInfo(for: device)
        } catch {
            Task { @MainActor in
                self.error = .configurationFailed(error.localizedDescription)
            }
        }
    }

    /// 当前焦段渲染方式说明
    private func lensRenderingMode(for device: AVCaptureDevice, zoomFactor: CGFloat) -> String {
        guard !device.virtualDeviceSwitchOverVideoZoomFactors.isEmpty else {
            return zoomFactor > 1.01 ? "系统裁切" : "原生镜头"
        }

        return "系统镜头"
    }

    /// 根据设备类型提供焦段降级估算
    private func fallbackEquivalentFocalLength(for deviceType: AVCaptureDevice.DeviceType) -> Double? {
        switch deviceType {
        case .builtInUltraWideCamera:
            return 13
        case .builtInWideAngleCamera:
            return 24
        case .builtInTelephotoCamera:
            return 77
        default:
            return nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 从 sample buffer 中提取图像缓冲区
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // 更新当前帧（线程安全）
        frameLock.lock()
        currentFrame = imageBuffer
        frameLock.unlock()
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
