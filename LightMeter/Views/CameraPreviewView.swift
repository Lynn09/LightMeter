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

    /// 冻结帧图像
    let frozenFrameImage: CGImage?

    /// 是否处于静态帧模式
    let isFrameFrozen: Bool

    /// 点击预览的回调
    let onTap: (CGPoint) -> Void

    /// 点击测光点的回调
    let onPointTap: (MeteringPoint) -> Void

    /// 冻结/恢复回调
    let onFreezeToggle: () -> Void

    /// 主体测光回调
    let onSubjectMetering: () -> Void

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let contentSize = CameraPreviewLayout.contentSize(for: geometry.size)

            ZStack {
                // 相机预览层或冻结帧
                previewContent(in: contentSize)

                // 测光点标记覆盖层
                meteringPointsOverlay(in: contentSize)

                // 静态帧控制
                staticFrameControls
            }
            .frame(width: contentSize.width, height: contentSize.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { location in
                let normalizedPoint = CameraPreviewLayout.normalizedPoint(
                    from: location,
                    in: contentSize
                )
                onTap(normalizedPoint)
            }
        }
    }

    // MARK: - Subviews

    /// 预览内容
    private func previewContent(in contentSize: CGSize) -> some View {
        ZStack {
            CameraPreviewLayer(session: session)
                .opacity(isFrameFrozen ? 0 : 1)

            if let frozenFrameImage {
                Image(decorative: frozenFrameImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: contentSize.width, height: contentSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: contentSize.width, height: contentSize.height)
    }

    /// 静态帧控制按钮
    private var staticFrameControls: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Button(action: onFreezeToggle) {
                    Image(systemName: isFrameFrozen ? "play.fill" : "pause.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 34)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.68))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                if isFrameFrozen {
                    Button(action: onSubjectMetering) {
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                                .font(.system(size: 14, weight: .semibold))
                            Text("主体测光")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#007AFF")!.opacity(0.88))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, 14)
        }
    }

    /// 测光点覆盖层
    private func meteringPointsOverlay(in contentSize: CGSize) -> some View {
        ForEach(meteringPoints) { point in
            MeteringPointView(
                point: point,
                isSelected: selectedPointId == point.id,
                containerSize: contentSize,
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
        frozenFrameImage: nil,
        isFrameFrozen: false,
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
        },
        onFreezeToggle: {},
        onSubjectMetering: {}
    )
}
