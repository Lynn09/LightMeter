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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Control { case film, aperture }
    @State private var expandedControl: Control?

    var body: some View {
        VStack(spacing: 0) {
            TopToolbar(currentFilm: viewModel.selectedFilm,
                       currentEV: viewModel.selectedPoint?.ev ?? viewModel.currentExposure.ev,
                       lockedDistance: cameraManager.rangefinder.isLocked ? cameraManager.rangefinder.meters : nil,
                       isExpanded: expandedControl == .film) {
                toggle(.film)
            }
            .opacity(isMeteringMode ? 1 : 0)
            .allowsHitTesting(isMeteringMode)
            .accessibilityHidden(!isMeteringMode)
            .overlay {
                if !isMeteringMode { Label("激光测距", systemImage: "ruler").font(.headline) }
            }

            CameraPreviewView(
                session: cameraManager.session,
                meteringPoints: viewModel.meteringPoints,
                selectedPointId: viewModel.selectedPointId,
                onTap: { location in
                    measure(at: location)
                },
                onPointTap: { point in
                    expandedControl = nil
                    viewModel.selectPoint(id: point.id)
                },
                mode: viewModel.mode,
                isDistanceLocked: cameraManager.rangefinder.isLocked,
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
                isMetering: isMeteringMode && cameraManager.isMetering,
                meteringMessage: isMeteringMode ? cameraManager.meteringMessage : nil,
                previewCompensation: !isMeteringMode ? 0 : viewModel.isManualExposure ? viewModel.manualExposureOffset - viewModel.shutterSpeedOffset - viewModel.dragShutterOffset : -viewModel.shutterSpeedOffset - viewModel.dragShutterOffset
            )
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) {
                if isMeteringMode && expandedControl == .film {
                    FilmSelectorView(selectedFilm: viewModel.selectedFilm) { film in
                        if film != viewModel.selectedFilm { viewModel.selectFilm(film) }
                        expandedControl = nil
                    }
                    .padding(.top, 6)
                    .background(.black)
                }
            }
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

            Picker("取景模式", selection: $viewModel.mode) {
                Text("单点").tag(ViewfinderMode.spot)
                Text("多点").tag(ViewfinderMode.metering)
                Text("测距").tag(ViewfinderMode.rangefinder)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 290)
            .padding(.vertical, 6)
            .onChange(of: viewModel.mode) { _ in
                expandedControl = nil
                cameraManager.cancelMetering()
            }

            if isMeteringMode {
                meteringControls
            } else {
                meteringControls.hidden().overlay {
                    DistanceControls(reading: cameraManager.rangefinder,
                                     status: cameraManager.hasPermission ? cameraManager.rangefinderStatus : "需要相机权限",
                                     isSupported: cameraManager.supportsLiDAR,
                                     onToggleLock: cameraManager.toggleDistanceLock)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
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

    private var isMeteringMode: Bool { viewModel.mode != .rangefinder }

    private var meteringControls: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.activeMethod == .spot {
                    Text("用中央方框瞄准主体")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        measure(at: CGPoint(x: 0.5, y: 0.5))
                    } label: {
                        Label(cameraManager.isMetering ? "测光中" : "测光", systemImage: "scope")
                            .frame(minWidth: 76)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!cameraManager.isRunning || cameraManager.isMetering)
                } else if let point = viewModel.selectedPoint {
                    PointEditMenuView(viewModel: viewModel, point: point, cameraManager: cameraManager)
                        .id(point.id)
                } else {
                    Text(viewModel.meteringPoints.isEmpty ? "轻点取景画面测光" : "平均曝光 · \(viewModel.meteringPoints.count) 个点")
                    Spacer()
                    Text(expandedControl == .aperture ? "选择光圈档位" : "滑动分区尺调快门")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            ZStack {
                if expandedControl == .aperture {
                    ApertureSelectorView(selectedAperture: viewModel.lockedAperture) { aperture in
                        if let aperture { viewModel.lockAperture(aperture) }
                        else { viewModel.unlockAperture() }
                    }
                    .transition(.opacity)
                } else {
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
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                }
            }
            .frame(minHeight: 80)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: expandedControl == .aperture)

            ExposureInfoView(viewModel: viewModel, isExpanded: expandedControl == .aperture) {
                toggle(.aperture)
            }
        }
    }

    // MARK: - Actions

    /// 处理预览区域点击 - 使用真实相机测光
    /// Wait for camera AE at the transformed point before recording EV100.
    private func measure(at location: CGPoint) {
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

    private func toggle(_ control: Control) {
        expandedControl = expandedControl == control ? nil : control
    }
}
