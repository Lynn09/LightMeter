import SwiftUI
import Combine

// MARK: - Main Metering View

/// 主测光界面视图
/// 整合所有组件的完整测光界面
struct MainMeteringView: View {

    // MARK: - View Model

    @StateObject private var viewModel = MeteringViewModel()

    // MARK: - Camera Manager

    @StateObject private var cameraManager = CameraManager()
    @Environment(\.scenePhase) private var scenePhase
    private let distanceClock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    // MARK: - State

    @State private var showingFilmSelector = false
    @State private var showingPointEditMenu = false
    @State private var selectedPoint: MeteringPoint?

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
                    currentEV: viewModel.meteringPoints.isEmpty ? nil : viewModel.currentExposure.ev,
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
                    onTap: { location in
                        handlePreviewTap(at: location)
                    },
                    onPointTap: { point in
                        handlePointTap(point)
                    },
                    rangefinder: cameraManager.rangefinder,
                    rangefinderStatus: cameraManager.hasPermission ? cameraManager.rangefinderStatus : "需要相机权限",
                    supportsLiDAR: cameraManager.supportsLiDAR,
                    onToggleDistanceLock: { cameraManager.toggleDistanceLock() },
                    cameraError: cameraManager.error?.localizedDescription,
                    onRetryCamera: {
                        cameraManager.stopSession()
                        Task {
                            await cameraManager.requestPermission()
                            if scenePhase != .background { cameraManager.startSession() }
                        }
                    },
                    isSessionRunning: cameraManager.isRunning,
                    previewRevision: cameraManager.previewRevision,
                    onPreviewStateChange: { cameraManager.previewDidChange($0) },
                    onPreviewLayerAvailable: { cameraManager.registerPreviewLayer($0) },
                    isMetering: cameraManager.isMetering,
                    meteringMessage: cameraManager.meteringMessage,
                    previewCompensation: viewModel.isManualExposure ? viewModel.manualExposureOffset - viewModel.shutterSpeedOffset - viewModel.dragShutterOffset : -viewModel.shutterSpeedOffset - viewModel.dragShutterOffset
                )
                .frame(maxHeight: .infinity)
                .task {
                    await cameraManager.requestPermission()
                    guard !Task.isCancelled else { return }
                    // Initial appearance and permission sheets may still report .inactive.
                    if scenePhase != .background { cameraManager.startSession() }
                }
                .onDisappear {
                    // 停止相机会话
                    cameraManager.stopSession()
                }

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

            // 测光点编辑菜单
            if showingPointEditMenu,
               let point = selectedPoint {
                // 透明遮罩层 - 点击关闭菜单
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingPointEditMenu = false
                        selectedPoint = nil
                    }

                PointEditMenuView(
                    viewModel: viewModel,
                    point: point,
                    onDismiss: {
                        showingPointEditMenu = false
                        selectedPoint = nil
                    },
                    cameraManager: cameraManager
                )
            }
        }
        .onReceive(distanceClock) { _ in cameraManager.expireDistance() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await cameraManager.requestPermission()
                    if scenePhase != .background { cameraManager.startSession() }
                }
            } else if phase == .background {
                cameraManager.stopSession()
            }
        }
    }

    // MARK: - Actions

    /// 处理预览区域点击 - 使用真实相机测光
    /// Wait for camera AE at the transformed point before recording EV100.
    private func handlePreviewTap(at location: CGPoint) {
        guard viewModel.canAddMeteringPoint else {
            // 可以在这里添加提示：已达到最大测光点数量
            return
        }

        Task {
            guard let reading = await cameraManager.meter(at: location) else { return }
            viewModel.addMeteringPoint(x: location.x, y: location.y, ev100: reading.ev100,
                                       rawEV100: reading.rawEV100, cameraID: reading.cameraID)
        }
    }

    /// 处理测光点点击
    private func handlePointTap(_ point: MeteringPoint) {
        viewModel.selectPoint(id: point.id)
        selectedPoint = point
        showingPointEditMenu = true
    }
}

// MARK: - Preview

#Preview("Main Metering View") {
    MainMeteringView()
        .preferredColorScheme(.dark)
}
