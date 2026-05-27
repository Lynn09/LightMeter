import SwiftUI

// MARK: - Main Metering View

/// 主测光界面视图
/// 整合所有组件的完整测光界面
struct MainMeteringView: View {

    // MARK: - View Model

    @StateObject private var viewModel = MeteringViewModel()

    // MARK: - Camera Manager

    @StateObject private var cameraManager = CameraManager()

    // MARK: - State

    @State private var showingFilmSelector = false
    @State private var isMeteringPointDrawerExpanded = false
    @State private var selectedFocalLength: StandardFocalLength = .mm35

    // MARK: - Constants

    private enum Layout {
        static let toolbarHeight: CGFloat = 64
        static let zoneScaleHeight: CGFloat = 80
        static let exposureInfoHeight: CGFloat = 80
        static let horizontalPadding: CGFloat = 20
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 主要内容
            VStack(spacing: 0) {
                // 顶部工具栏
                TopToolbar(
                    currentFilm: viewModel.selectedFilm,
                    currentEV: viewModel.currentExposure.ev,
                    onFilmButtonTap: {
                        showingFilmSelector = true
                    }
                )
                .frame(height: Layout.toolbarHeight)

                // 相机预览区域（真实相机）
                CameraPreviewView(
                    session: cameraManager.session,
                    meteringPoints: viewModel.meteringPoints,
                    selectedPointId: viewModel.selectedPointId,
                    frozenFrameImage: cameraManager.frozenFrameImage,
                    isFrameFrozen: cameraManager.isFrameFrozen,
                    selectedFocalLength: selectedFocalLength,
                    onTap: { location in
                        handlePreviewTap(at: location)
                    },
                    onPointTap: { point in
                        handlePointTap(point)
                    },
                    onFreezeToggle: {
                        handleStaticFrameToggle()
                    },
                    onSubjectMetering: {
                        handleSubjectMetering()
                    },
                    onFocalLengthSelected: { focalLength in
                        selectedFocalLength = focalLength
                        cameraManager.selectFocalLength(focalLength)
                    }
                )
                .frame(maxHeight: .infinity)
                .onAppear {
                    // 启动相机会话
                    Task {
                        await cameraManager.requestPermission()
                        cameraManager.startSession()
                    }
                }
                .onDisappear {
                    // 停止相机会话
                    cameraManager.stopSession()
                }

                // 测光点快速编辑抽屉
                MeteringPointDrawerView(
                    points: viewModel.meteringPoints,
                    selectedPointId: viewModel.selectedPointId,
                    isExpanded: $isMeteringPointDrawerExpanded,
                    onSelect: { pointId in
                        viewModel.selectPointForDrawer(id: pointId)
                    },
                    onDelete: { pointId in
                        viewModel.deleteMeteringPoint(id: pointId)
                        if viewModel.meteringPoints.isEmpty {
                            isMeteringPointDrawerExpanded = false
                        }
                    },
                    onRemeter: { point in
                        remeterPoint(point)
                    }
                )
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, viewModel.meteringPoints.isEmpty ? 0 : 8)

                // 11区梯度条（快门控制版本）
                ZoneScaleView(
                    minZone: viewModel.selectedFilm.minZone,
                    maxZone: viewModel.selectedFilm.maxZone,
                    meteringPoints: viewModel.meteringPoints,
                    shutterSpeedOffset: viewModel.shutterSpeedOffset,
                    dragOffset: viewModel.dragShutterOffset,
                    onShutterOffsetChange: { offset in
                        viewModel.updateShutterDragOffset(offset)
                    },
                    onShutterOffsetEnd: { offset in
                        viewModel.endShutterDragWithOffset(offset)
                    }
                )
                .frame(height: Layout.zoneScaleHeight)
                .padding(.horizontal, Layout.horizontalPadding)

                // 曝光参数栏
                ExposureInfoView(
                    viewModel: viewModel
                )
                .frame(height: Layout.exposureInfoHeight)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, 20)
            }

            // 胶片选择弹窗
            if showingFilmSelector {
                FilmSelectorView(
                    selectedFilm: .init(
                        get: { viewModel.selectedFilm },
                        set: { _ in }
                    ),
                    isPresented: $showingFilmSelector,
                    onFilmSelected: { film in
                        viewModel.selectFilm(film)
                    }
                )
            }

            // 光圈选择弹窗
            if viewModel.isApertureSelectorPresented {
                ApertureSelectorView(
                    selectedAperture: .init(
                        get: { viewModel.lockedAperture },
                        set: { _ in }
                    ),
                    isPresented: .init(
                        get: { viewModel.isApertureSelectorPresented },
                        set: { newValue in
                            if !newValue {
                                viewModel.closeApertureSelector()
                            }
                        }
                    ),
                    onApertureSelected: { aperture in
                        if let aperture = aperture {
                            viewModel.lockAperture(aperture)
                        } else {
                            viewModel.unlockAperture()
                        }
                        viewModel.closeApertureSelector()
                    }
                )
            }

            // 快门选择弹窗
            if viewModel.isShutterSelectorPresented {
                ShutterSelectorView(
                    selectedShutterSpeed: .init(
                        get: { viewModel.lockedShutterSpeed },
                        set: { _ in }
                    ),
                    isPresented: .init(
                        get: { viewModel.isShutterSelectorPresented },
                        set: { newValue in
                            if !newValue {
                                viewModel.closeShutterSelector()
                            }
                        }
                    ),
                    onShutterSelected: { shutterSpeed in
                        if let shutterSpeed = shutterSpeed {
                            viewModel.lockShutterSpeed(shutterSpeed)
                        } else {
                            viewModel.unlockShutterSpeed()
                        }
                        viewModel.closeShutterSelector()
                    }
                )
            }

        }
    }

    // MARK: - Actions

    /// 处理预览区域点击 - 使用真实相机测光
    /// 从相机捕获的帧中提取点击区域的像素亮度
    private func handlePreviewTap(at location: CGPoint) {
        guard viewModel.canAddMeteringPoint else {
            // 可以在这里添加提示：已达到最大测光点数量
            return
        }

        let brightness = cameraManager.getBrightness(at: location, regionSize: 64)

        viewModel.addMeteringPoint(x: location.x, y: location.y, brightness: brightness)
    }

    /// 处理测光点点击
    private func handlePointTap(_ point: MeteringPoint) {
        viewModel.selectPointForDrawer(id: point.id)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
            isMeteringPointDrawerExpanded = true
        }
    }

    /// 处理静态帧截取/恢复
    private func handleStaticFrameToggle() {
        if cameraManager.isFrameFrozen {
            cameraManager.resumeLivePreview()
            cameraManager.startSession()
        } else if cameraManager.captureStaticFrame() {
            cameraManager.stopSession()
        }
    }

    /// 对静态帧或当前帧中的主体进行自动测光
    private func handleSubjectMetering() {
        guard viewModel.canAddMeteringPoint,
              let result = cameraManager.getSubjectMeteringResult() else {
            return
        }

        viewModel.addMeteringPoint(
            x: result.normalizedPoint.x,
            y: result.normalizedPoint.y,
            brightness: result.brightness
        )
    }

    /// 在同一归一化坐标上重新采样亮度并更新测光数据
    private func remeterPoint(_ point: MeteringPoint) {
        let brightness = cameraManager.getBrightness(
            at: CGPoint(x: point.x, y: point.y),
            regionSize: 64
        )
        viewModel.remeterPoint(id: point.id, brightness: brightness)
    }
}

// MARK: - Preview

#Preview("Main Metering View") {
    MainMeteringView()
        .preferredColorScheme(.dark)
}
