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

    enum MeteringSampling {
        static let minimumMeteringAreaRatio: Double = 0.01
        static let spotMeteringAreaRatio: Double = 0.02
        static let subjectMeteringAreaRatio: Double = 0.03
        static let calibrationMeteringAreaRatio: Double = 0.02
        static let maximumMeteringAreaRatio: Double = 0.05
    }

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

    /// 当前原生 iPhone 镜头信息，用作校准 key
    @Published private(set) var currentNativeLensInfo: NativeLensInfo?

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

    /// 冻结帧对应的相机曝光参数
    private var frozenExposureSnapshot: CameraExposureSnapshot?

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
        frozenExposureSnapshot = currentExposureSnapshot
        frameLock.unlock()

        frozenFrameImage = makeCGImage(from: frame)
        isFrameFrozen = frozenFrameImage != nil
        return isFrameFrozen
    }

    /// 恢复实时取景
    func resumeLivePreview() {
        frameLock.lock()
        frozenFrame = nil
        frozenExposureSnapshot = nil
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

    /// 当前相机曝光参数快照，用于从 iPhone 曝光元数据反推 EV100
    var currentExposureSnapshot: CameraExposureSnapshot? {
        guard let device = videoDeviceInput?.device else { return nil }
        let duration = CMTimeGetSeconds(device.exposureDuration)
        guard duration.isFinite, duration > 0 else { return nil }

        return CameraExposureSnapshot(
            aperture: Double(device.lensAperture),
            exposureDuration: duration,
            iso: Double(device.iso)
        )
    }

    /// 当前测光帧对应的场景 EV100。冻结帧使用截取瞬间的曝光参数。
    var currentMeteringReferenceEV: Double? {
        let snapshot = frozenExposureSnapshot ?? currentExposureSnapshot
        guard let snapshot else { return nil }
        return MeteringCalibrationMath.ev100(
            aperture: snapshot.aperture,
            exposureDuration: snapshot.exposureDuration,
            iso: snapshot.iso
        )
    }

    /// 获取中心加权亮度，用于快速/标准校准
    func getCenterWeightedBrightness() -> Double {
        getBrightness(
            at: CGPoint(x: 0.5, y: 0.5),
            areaRatio: MeteringSampling.calibrationMeteringAreaRatio
        )
    }

    /// 锁定当前稳定曝光，避免校准采样期间自动曝光继续漂移
    @discardableResult
    func lockCurrentExposure() -> Bool {
        guard videoDeviceInput?.device != nil else {
            return false
        }

        sessionQueue.async { [weak self] in
            guard let self,
                  let device = self.videoDeviceInput?.device,
                  device.isExposureModeSupported(.locked) else {
                return
            }

            do {
                try device.lockForConfiguration()
                device.exposureMode = .locked
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor in
                    self.error = .configurationFailed(error.localizedDescription)
                }
            }
        }

        return true
    }

    /// 捕获一次校准样本：图像测得 EV 与 iPhone 曝光参数推导 EV100 的差异
    func captureCalibrationSample() -> CalibrationSample? {
        guard let snapshot = currentExposureSnapshot else { return nil }

        let brightness = getCenterWeightedBrightness()
        let measuredEV = ExposureCalculator.brightnessToEV(brightness: brightness)
        let referenceEV = MeteringCalibrationMath.ev100(
            aperture: snapshot.aperture,
            exposureDuration: snapshot.exposureDuration,
            iso: snapshot.iso
        )

        return CalibrationSample(
            measuredEV: measuredEV,
            referenceEV: referenceEV,
            brightness: brightness
        )
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

        // Prefer YUV luma data so metering reads the camera signal before RGB display conversion.
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
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
    ///   - areaRatio: 测光区域面积比例，点测光默认 2%，并限制在 1%...5%
    /// - Returns: 归一化亮度值 [0.0, 1.0]
    func getBrightness(at point: CGPoint, areaRatio: Double = MeteringSampling.spotMeteringAreaRatio) -> Double {
        guard let frame = activeMeteringFrame() else {
            // 无可用帧时返回历史平均值或默认值
            return getSmoothedBrightness(fallback: 0.18)
        }

        let samplingPoint = normalizedSamplingPoint(forDisplayPoint: point)
        let rawBrightness = extractBrightness(from: frame, atNormalizedPoint: samplingPoint, areaRatio: areaRatio)

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
            return extractBrightness(
                from: frame,
                atNormalizedPoint: samplingPoint,
                areaRatio: MeteringSampling.subjectMeteringAreaRatio
            )
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

    /// 从图像帧中提取指定区域的平均亮度，优先使用 YUV luma plane，BGRA 仅作兼容 fallback。
    private func extractBrightness(from frame: CVImageBuffer, atNormalizedPoint point: CGPoint, areaRatio: Double) -> Double {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        if CVPixelBufferIsPlanar(frame),
           CVPixelBufferGetPlaneCount(frame) > 0,
           let luma = extractLumaBrightness(from: frame, atNormalizedPoint: point, areaRatio: areaRatio) {
            return luma
        }

        return extractBGRABrightness(from: frame, atNormalizedPoint: point, areaRatio: areaRatio)
    }

    private func meteringSideLength(for frame: CVImageBuffer, areaRatio: Double) -> Int {
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        let ratio = max(
            MeteringSampling.minimumMeteringAreaRatio,
            min(MeteringSampling.maximumMeteringAreaRatio, areaRatio)
        )
        return max(1, Int(round(sqrt(Double(width * height) * ratio))))
    }

    private func extractLumaBrightness(from frame: CVImageBuffer, atNormalizedPoint point: CGPoint, areaRatio: Double) -> Double? {
        let width = CVPixelBufferGetWidthOfPlane(frame, 0)
        let height = CVPixelBufferGetHeightOfPlane(frame, 0)
        let regionSize = meteringSideLength(for: frame, areaRatio: areaRatio)

        let halfSize = regionSize / 2
        let normalizedX = max(0, min(1, point.x))
        let normalizedY = max(0, min(1, point.y))
        let x = max(halfSize, min(Int(normalizedX * CGFloat(width)), width - halfSize))
        let y = max(halfSize, min(Int(normalizedY * CGFloat(height)), height - halfSize))

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(frame, 0) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var totalBrightness: Double = 0
        var pixelCount = 0

        for dy in -halfSize..<halfSize {
            for dx in -halfSize..<halfSize {
                let px = x + dx
                let py = y + dy
                let offset = py * bytesPerRow + px
                totalBrightness += Double(buffer[offset]) / 255.0
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else { return nil }
        return totalBrightness / Double(pixelCount)
    }

    private func extractBGRABrightness(from frame: CVImageBuffer, atNormalizedPoint point: CGPoint, areaRatio: Double) -> Double {
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        let regionSize = meteringSideLength(for: frame, areaRatio: areaRatio)

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
        self.updateNativeLensInfo(for: videoDevice)
        self.updateLensInfo(for: videoDevice)
        self.applyZoom(for: selectedFocalLength, on: videoDevice)
    }

    /// 更新当前原生镜头标识。模拟焦段不改变这个校准 key。
    private func updateNativeLensInfo(for device: AVCaptureDevice) {
        let key = [
            device.position == .back ? "back" : "front",
            device.deviceType.rawValue,
            device.uniqueID
        ].joined(separator: "|")

        let info = NativeLensInfo(
            key: key,
            name: nativeLensDisplayName(for: device),
            deviceType: device.deviceType.rawValue
        )

        Task { @MainActor in
            self.currentNativeLensInfo = info
        }
    }

    private func nativeLensDisplayName(for device: AVCaptureDevice) -> String {
        switch device.deviceType {
        case .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera:
            return String(localized: "camera.native.main")
        case .builtInUltraWideCamera:
            return String(localized: "camera.native.ultraWide")
        case .builtInTelephotoCamera:
            return String(localized: "camera.native.telephoto")
        default:
            return device.localizedName
        }
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
            return String(localized: "camera.lens.system")
        }

        return String(localized: "camera.lens.system")
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
            return String(localized: "camera.error.permissionDenied")
        case .deviceNotFound:
            return String(localized: "camera.error.deviceNotFound")
        case .cannotAddInput:
            return String(localized: "camera.error.cannotAddInput")
        case .cannotAddOutput:
            return String(localized: "camera.error.cannotAddOutput")
        case .configurationFailed(let message):
            return String(format: String(localized: "camera.error.configurationFailed"), message)
        }
    }
}
