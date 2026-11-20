import SwiftUI
import AVFoundation

// MARK: - Camera Preview View

/// 相机预览视图（真实相机）
/// 使用 AVCaptureVideoPreviewLayer 显示实时相机画面
struct CameraPreviewView: View {

    // MARK: - Properties

    /// 相机会话（从外部传入）
    let session: AVCaptureSession

    /// 测光点数组
    let meteringPoints: [MeteringPoint]

    /// 选中的测光点 ID
    let selectedPointId: UUID?

    /// 点击预览的回调
    let onTap: (CGPoint) -> Void

    /// 点击测光点的回调
    let onPointTap: (MeteringPoint) -> Void

    var mode: ViewfinderMode = .metering
    var isDistanceLocked = false
    var cameraError: String?
    var onRetryCamera: () -> Void = {}
    var isSessionRunning = false
    var previewRevision = 0
    var onPreviewStateChange: (Bool) -> Void = { _ in }
    var onPreviewLayerAvailable: (AVCaptureVideoPreviewLayer) -> Void = { _ in }
    var isMetering = false
    var meteringMessage: String?
    var previewCompensation = 0.0

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 相机预览层
                if isSessionRunning {
                    // Attach only after inputs/outputs are committed and startRunning returns.
                    CameraPreviewLayer(session: session, onPreviewStateChange: onPreviewStateChange,
                                       onPreviewLayerAvailable: onPreviewLayerAvailable)
                        .id(previewRevision)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            (previewCompensation > 0 ? Color.white : Color.black)
                                .opacity(ExposureCalculator.previewOverlayOpacity(stops: previewCompensation))
                                .allowsHitTesting(false)
                        }
                } else {
                    Color.black
                }

                // 测光点标记覆盖层
                if mode == .metering {
                    meteringPointsOverlay(in: geometry)
                } else {
                    CenterRangefinderView(isLocked: isDistanceLocked)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 将点击坐标转换为归一化坐标 (0~1)
                guard mode == .metering else { return }
                let normalizedPoint = CGPoint(
                    x: location.x / geometry.size.width,
                    y: location.y / geometry.size.height
                )
                onTap(normalizedPoint)
            }
            .overlay(alignment: .top) {
                if let cameraError {
                    VStack(spacing: 8) {
                        Text(cameraError)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                        Button("重试相机", action: onRetryCamera)
                            .buttonStyle(.bordered)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    .padding(16)
                } else if !isSessionRunning || isMetering {
                    ProgressView(isMetering ? "正在测光…" : "正在启动相机…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(16)
                } else if let meteringMessage {
                    Text(meteringMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                        .padding(16)
                }
            }
            .overlay(alignment: .topTrailing) {
                if abs(previewCompensation) > 0.01 {
                    Text(String(format: "模拟预览 %+.1f EV", previewCompensation))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Subviews

    /// 测光点覆盖层
    private func meteringPointsOverlay(in geometry: GeometryProxy) -> some View {
        ForEach(meteringPoints) { point in
            MeteringPointView(
                point: point,
                isSelected: selectedPointId == point.id,
                containerSize: geometry.size,
                onTap: {
                    onPointTap(point)
                }
            )
        }
    }
}

// MARK: - Camera Preview Layer

/// 相机预览层包装器
/// 将 AVCaptureVideoPreviewLayer 包装为 SwiftUI 视图
private struct CameraPreviewLayer: UIViewRepresentable {

    let session: AVCaptureSession
    let onPreviewStateChange: (Bool) -> Void
    let onPreviewLayerAvailable: (AVCaptureVideoPreviewLayer) -> Void

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.configureVideoGravity()
        view.connect(session, onPreviewStateChange: onPreviewStateChange)
        onPreviewLayerAvailable(view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.connect(session, onPreviewStateChange: onPreviewStateChange)
        onPreviewLayerAvailable(uiView.videoPreviewLayer)
        uiView.setNeedsLayout()
    }
}

// MARK: - Video Preview View

/// 视频预览视图
/// 包装 AVCaptureVideoPreviewLayer 的 UIView 子类
private class VideoPreviewView: UIView {
    private var previewObservation: NSKeyValueObservation?
    private var onPreviewStateChange: ((Bool) -> Void)?

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    func connect(_ session: AVCaptureSession, onPreviewStateChange: @escaping (Bool) -> Void) {
        self.onPreviewStateChange = onPreviewStateChange
        if videoPreviewLayer.session !== session {
            videoPreviewLayer.session = session
        }
        if previewObservation == nil {
            previewObservation = videoPreviewLayer.observe(\.isPreviewing, options: [.initial, .new]) { [weak self] layer, _ in
                let visible = layer.isPreviewing
                Task { @MainActor [weak self] in
                    self?.onPreviewStateChange?(visible)
                }
            }
        }
    }

    /// 配置视频重力为填满模式
    func configureVideoGravity() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Camera Preview") {
    @Previewable @State var points: [MeteringPoint] = [
        MeteringPoint(x: 0.25, y: 0.31, color: "#34C759", zone: 4, ev: 11.5, isSelected: true),
        MeteringPoint(x: 0.64, y: 0.42, color: "#FF9500", zone: 5, ev: 12.5, isSelected: false),
        MeteringPoint(x: 0.46, y: 0.62, color: "#FF3B30", zone: 6, ev: 13.5, isSelected: false)
    ]

    // Preview uses an empty AVCaptureSession
    CameraPreviewView(
        session: AVCaptureSession(),
        meteringPoints: points,
        selectedPointId: points.first?.id,
        onTap: { location in
            print("Tapped at: \(location)")
            let colorIndex = points.count % MeteringPoint.colors.count
            // location is now normalized (0~1), pass directly
            let newPoint = MeteringPoint(
                x: location.x,
                y: location.y,
                color: MeteringPoint.colors[colorIndex],
                zone: Int.random(in: 3...8),
                ev: Double.random(in: 10...15)
            )
            points.append(newPoint)
        },
        onPointTap: { point in
            print("Selected point: \(point.id)")
        }
    )
}
