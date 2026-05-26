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

    /// 帧访问锁
    private let frameLock = NSLock()

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
    ///   - point: 点击位置（相对于预览层的坐标）
    ///   - regionSize: 测光区域大小（正方形边长，像素）
    /// - Returns: 归一化亮度值 [0.0, 1.0]
    func getBrightness(at point: CGPoint, regionSize: Int = 64) -> Double {
        frameLock.lock()
        guard let frame = currentFrame else {
            frameLock.unlock()
            // 无可用帧时返回历史平均值或默认值
            return getSmoothedBrightness(fallback: 0.18)
        }
        frameLock.unlock()

        // 从帧中提取指定区域的亮度
        let rawBrightness = extractBrightness(from: frame, at: point, regionSize: regionSize)

        // 应用平滑处理
        let smoothedBrightness = addBrightnessToHistoryAndSmooth(rawBrightness)

        return smoothedBrightness
    }

    // MARK: - Private Helper Methods

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
    ///   - point: 中心点坐标
    ///   - regionSize: 测光区域大小
    /// - Returns: 归一化亮度值 [0.0, 1.0]
    private func extractBrightness(from frame: CVImageBuffer, at point: CGPoint, regionSize: Int) -> Double {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)

        // 计算测光区域边界
        let halfSize = regionSize / 2
        let x = max(halfSize, min(Int(point.x), width - halfSize))
        let y = max(halfSize, min(Int(point.y), height - halfSize))

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
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
