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

    // MARK: - Constants

    private enum Constants {
        static let previewHeight: CGFloat = 480
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 相机预览层
                CameraPreviewLayer(session: session)

                // 测光点标记覆盖层
                meteringPointsOverlay(in: geometry)
            }
            .frame(height: Constants.previewHeight)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 将点击坐标转换为归一化坐标 (0~1)
                let normalizedPoint = CGPoint(
                    x: location.x / geometry.size.width,
                    y: location.y / geometry.size.height
                )
                onTap(normalizedPoint)
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

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.configureVideoGravity()
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 更新逻辑（如需要）
    }
}

// MARK: - Video Preview View

/// 视频预览视图
/// 包装 AVCaptureVideoPreviewLayer 的 UIView 子类
private class VideoPreviewView: UIView {

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
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
