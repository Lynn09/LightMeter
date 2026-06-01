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

    /// 当前选择的标准定焦焦段
    let selectedFocalLength: StandardFocalLength

    /// 是否显示静帧、主体测光和模拟焦段控制
    let showsPreviewControls: Bool

    /// 点击预览的回调
    let onTap: (CGPoint) -> Void

    /// 点击测光点的回调
    let onPointTap: (MeteringPoint) -> Void

    /// 冻结/恢复回调
    let onFreezeToggle: () -> Void

    /// 主体测光回调
    let onSubjectMetering: () -> Void

    /// 标准定焦选择回调
    let onFocalLengthSelected: (StandardFocalLength) -> Void

    // MARK: - State

    @State private var isFocalLengthDrawerExpanded = false

    private enum Layout {
        static let centerControlWidth: CGFloat = 58
        static let controlHeight: CGFloat = 34
        static let controlSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 14
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let contentSize = CameraPreviewLayout.contentSize(for: geometry.size)

            ZStack {
                // 相机预览层或冻结帧
                previewContent(in: contentSize)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let normalizedPoint = CameraPreviewLayout.normalizedPoint(
                            from: location,
                            in: contentSize
                        )
                        onTap(normalizedPoint)
                    }

                // 测光点标记覆盖层
                meteringPointsOverlay(in: contentSize)

                if showsPreviewControls {
                    // 取景控制条始终置顶，避免冻结帧后无法恢复
                    previewControlBar
                        .zIndex(30)
                }
            }
            .frame(width: contentSize.width, height: contentSize.height)
            .clipped()
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

    /// 取景控制条：静帧、主体测光和焦段选择
    private var previewControlBar: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if isFocalLengthDrawerExpanded {
                    focalLengthOptionsOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                previewControlSlots
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private var previewControlSlots: some View {
        ZStack {
            HStack(spacing: Layout.controlSpacing) {
                focalLengthToggleButton
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Color.clear
                    .frame(width: Layout.centerControlWidth, height: Layout.controlHeight)

                Group {
                    if isFrameFrozen {
                        subjectMeteringButton
                    } else {
                        Color.clear
                            .frame(height: Layout.controlHeight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            freezeButton
                .frame(width: Layout.centerControlWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private var freezeButton: some View {
        Button(action: onFreezeToggle) {
            Image(systemName: isFrameFrozen ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, height: Layout.controlHeight)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.68))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var focalLengthToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isFocalLengthDrawerExpanded.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Text(selectedFocalLength.displayLabel)
                    .font(.system(size: 12, weight: .semibold))

                Image(systemName: isFocalLengthDrawerExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .frame(height: Layout.controlHeight)
            .background(
                Capsule()
                    .fill(isFocalLengthDrawerExpanded ? Color.white.opacity(0.18) : Color.black.opacity(0.68))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var subjectMeteringButton: some View {
        Button(action: onSubjectMetering) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                Text("preview.subjectMetering")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: Layout.controlHeight)
            .background(
                Capsule()
                    .fill(Color(hex: "#007AFF")!.opacity(0.88))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 标准定焦选择浮层，展示在取景控制条上方
    private var focalLengthOptionsOverlay: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StandardFocalLength.allCases) { focalLength in
                        Button {
                            onFocalLengthSelected(focalLength)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isFocalLengthDrawerExpanded = false
                            }
                        } label: {
                            focalLengthOptionLabel(for: focalLength)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: 330)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )

            popoverAnchorTriangle
                .offset(x: -52)
        }
    }

    private var popoverAnchorTriangle: some View {
        Triangle()
            .fill(Color.black.opacity(0.72))
            .frame(width: 14, height: 7)
    }

    private func focalLengthOptionLabel(for focalLength: StandardFocalLength) -> some View {
        Text(focalLength.displayLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(selectedFocalLength == focalLength ? .black : .white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(selectedFocalLength == focalLength ? Color.white : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
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

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
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
        selectedFocalLength: .mm35,
        showsPreviewControls: true,
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
        onSubjectMetering: {},
        onFocalLengthSelected: { _ in }
    )
}
