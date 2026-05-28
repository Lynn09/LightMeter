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
    @State private var showingSettings = false
    @State private var isMeteringPointDrawerExpanded = false
    @State private var selectedFocalLength: StandardFocalLength = .mm35
    @State private var activeCalibrationMode: CalibrationCaptureMode?
    @State private var professionalReferenceEV: Double?
    @State private var calibrationSamples: [CalibrationSample] = []
    @State private var calibrationMessage: String?

    // MARK: - Constants

    private enum Layout {
        static let toolbarHeight: CGFloat = 64
        static let zoneScaleHeight: CGFloat = 80
        static let exposureInfoHeight: CGFloat = 80
        static let horizontalPadding: CGFloat = 20
        static let filmPopoverTopSpacing: CGFloat = 2
        static let previewControlClearance: CGFloat = 58
        static let exposureSelectorBottomOffset: CGFloat = 112
        static let parameterSelectorHorizontalOffset: CGFloat = 56
        static let parameterSelectorWidth: CGFloat = 342
        static let parameterSelectorScreenMargin: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !isCalibrationActive {
                meteringInterface
            } else {
                calibrationPreviewInterface
            }

            if showingFilmSelector && !isCalibrationActive {
                filmSelectorOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }

            if !isCalibrationActive && (viewModel.isApertureSelectorPresented || viewModel.isShutterSelectorPresented) {
                parameterSelectorOverlay
                    .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }

            if let activeCalibrationMode {
                calibrationCaptureOverlay(mode: activeCalibrationMode)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(4)
            }

        }
        .onReceive(cameraManager.$currentNativeLensInfo) { lensInfo in
            viewModel.updateNativeLensInfo(lensInfo)
        }
        .task {
            await startCameraSessionIfNeeded()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                viewModel: viewModel,
                cameraManager: cameraManager,
                onStartProfessionalCalibration: { referenceEV in
                    startCalibrationCapture(.professional, referenceEV: referenceEV)
                },
                onStartStandardCalibration: {
                    startCalibrationCapture(.standard)
                },
                onStartQuickCalibration: {
                    startCalibrationCapture(.quick)
                }
            )
        }
    }

    private var isCalibrationActive: Bool {
        activeCalibrationMode != nil
    }

    private var meteringInterface: some View {
        VStack(spacing: 0) {
            TopToolbar(
                currentFilm: viewModel.selectedFilm,
                currentEV: viewModel.currentExposure.ev,
                calibrationStatus: viewModel.calibrationStatusLabel,
                isFilmSelectorPresented: showingFilmSelector,
                onSettingsButtonTap: {
                    showingSettings = true
                },
                onFilmButtonTap: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        showingFilmSelector.toggle()
                    }
                }
            )
            .frame(height: Layout.toolbarHeight)

            cameraPreviewContent
                .overlay(alignment: .bottom) {
                    meteringPointDrawerOverlay
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.previewControlClearance)
                }

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

            ExposureInfoView(viewModel: viewModel)
                .frame(height: Layout.exposureInfoHeight)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, 20)
        }
    }

    private var calibrationPreviewInterface: some View {
        cameraPreviewContent
            .ignoresSafeArea(edges: .bottom)
    }

    private var cameraPreviewContent: some View {
        CameraPreviewView(
            session: cameraManager.session,
            meteringPoints: isCalibrationActive ? [] : viewModel.meteringPoints,
            selectedPointId: isCalibrationActive ? nil : viewModel.selectedPointId,
            frozenFrameImage: cameraManager.frozenFrameImage,
            isFrameFrozen: cameraManager.isFrameFrozen,
            selectedFocalLength: selectedFocalLength,
            showsPreviewControls: !isCalibrationActive,
            onTap: { location in
                if !isCalibrationActive {
                    handlePreviewTap(at: location)
                }
            },
            onPointTap: { point in
                if !isCalibrationActive {
                    handlePointTap(point)
                }
            },
            onFreezeToggle: {
                if !isCalibrationActive {
                    handleStaticFrameToggle()
                }
            },
            onSubjectMetering: {
                if !isCalibrationActive {
                    handleSubjectMetering()
                }
            },
            onFocalLengthSelected: { focalLength in
                selectedFocalLength = focalLength
                cameraManager.selectFocalLength(focalLength)
            }
        )
        .frame(maxHeight: .infinity)
    }

    private var filmSelectorOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black
                    .opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            showingFilmSelector = false
                        }
                    }

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
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, proxy.safeAreaInsets.top + Layout.toolbarHeight + Layout.filmPopoverTopSpacing)
            }
        }
    }

    private var meteringPointDrawerOverlay: some View {
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
        .opacity(viewModel.meteringPoints.isEmpty ? 0 : 1)
        .allowsHitTesting(!viewModel.meteringPoints.isEmpty)
    }

    private var parameterSelectorOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            viewModel.closeApertureSelector()
                            viewModel.closeShutterSelector()
                        }
                    }

                Group {
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
                            }
                        )
                    } else if viewModel.isShutterSelectorPresented {
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
                            }
                        )
                    }
                }
                .padding(.bottom, Layout.exposureSelectorBottomOffset)
                .offset(x: parameterSelectorHorizontalOffset(in: proxy.size.width))
            }
        }
    }

    private func calibrationCaptureOverlay(mode: CalibrationCaptureMode) -> some View {
        CalibrationCaptureOverlay(
            mode: mode,
            nativeLensName: viewModel.activeNativeLensInfo?.name ?? "Unknown native lens",
            sampleCount: calibrationSamples.count,
            message: calibrationMessage,
            onCancel: {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                    activeCalibrationMode = nil
                    professionalReferenceEV = nil
                    calibrationSamples = []
                    calibrationMessage = nil
                }
            },
            onCapture: {
                captureCalibrationSample(for: mode)
            }
        )
    }

    private func parameterSelectorHorizontalOffset(in availableWidth: CGFloat) -> CGFloat {
        let maxOffset = max((availableWidth - Layout.parameterSelectorWidth) / 2 - Layout.parameterSelectorScreenMargin, 0)
        let offset = min(Layout.parameterSelectorHorizontalOffset, maxOffset)
        if viewModel.isApertureSelectorPresented {
            return -offset
        }
        if viewModel.isShutterSelectorPresented {
            return offset
        }
        return 0
    }

    // MARK: - Actions

    /// 处理预览区域点击 - 使用真实相机测光
    /// 从相机捕获的帧中提取点击区域的像素亮度
    private func handlePreviewTap(at location: CGPoint) {
        guard viewModel.canAddMeteringPoint else {
            // 可以在这里添加提示：已达到最大测光点数量
            return
        }

        let brightness = cameraManager.getBrightness(at: location)

        viewModel.addMeteringPoint(
            x: location.x,
            y: location.y,
            brightness: brightness,
            cameraReferenceEV: cameraManager.currentMeteringReferenceEV
        )
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
            brightness: result.brightness,
            cameraReferenceEV: cameraManager.currentMeteringReferenceEV
        )
    }

    /// 在同一归一化坐标上重新采样亮度并更新测光数据
    private func remeterPoint(_ point: MeteringPoint) {
        let brightness = cameraManager.getBrightness(
            at: CGPoint(x: point.x, y: point.y)
        )
        viewModel.remeterPoint(
            id: point.id,
            brightness: brightness,
            cameraReferenceEV: cameraManager.currentMeteringReferenceEV
        )
    }

    private func startCalibrationCapture(_ mode: CalibrationCaptureMode, referenceEV: Double? = nil) {
        cameraManager.resumeLivePreview()
        cameraManager.startSession()
        professionalReferenceEV = referenceEV
        calibrationSamples = []
        calibrationMessage = nil
        _ = cameraManager.lockCurrentExposure()

        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            activeCalibrationMode = mode
        }
    }

    private func startCameraSessionIfNeeded() async {
        await cameraManager.requestPermission()
        cameraManager.startSession()
    }

    private func captureCalibrationSample(for mode: CalibrationCaptureMode) {
        switch mode {
        case .professional:
            guard let professionalReferenceEV else {
                calibrationMessage = "Enter a reference EV before sampling."
                return
            }

            let measuredBrightness = cameraManager.getCenterWeightedBrightness()
            guard let cameraReferenceEV = cameraManager.currentMeteringReferenceEV else {
                calibrationMessage = "No camera exposure reference available."
                return
            }
            guard viewModel.saveProfessionalCalibration(
                referenceEV: professionalReferenceEV,
                cameraReferenceEV: cameraReferenceEV,
                measuredBrightness: measuredBrightness
            ) else {
                calibrationMessage = "Calibration sample is invalid. Re-aim and sample again."
                return
            }
            calibrationMessage = "Professional calibration saved."
            activeCalibrationMode = nil

        case .standard:
            guard let sample = cameraManager.captureCalibrationSample() else {
                calibrationMessage = "No camera sample available."
                return
            }

            calibrationSamples.append(sample)
            if calibrationSamples.count >= mode.requiredSamples {
                guard viewModel.saveCalibration(level: .standard, samples: calibrationSamples) else {
                    calibrationMessage = "Samples are outside the trusted range. Re-aim at an 18% gray card."
                    calibrationSamples = []
                    return
                }
                calibrationMessage = "Standard calibration saved."
                activeCalibrationMode = nil
            } else {
                calibrationMessage = "Sample \(calibrationSamples.count)/\(mode.requiredSamples) captured."
            }

        case .quick:
            guard let sample = cameraManager.captureCalibrationSample() else {
                calibrationMessage = "No camera sample available."
                return
            }

            guard viewModel.saveCalibration(level: .quick, samples: [sample]) else {
                calibrationMessage = "Quick calibration was rejected. Aim at a middle-tone area and try again."
                return
            }
            calibrationMessage = "Quick calibration saved."
            activeCalibrationMode = nil
        }
    }
}

private enum CalibrationCaptureMode {
    case professional
    case standard
    case quick

    var title: String {
        switch self {
        case .professional:
            return "Professional Calibration"
        case .standard:
            return "Standard Calibration"
        case .quick:
            return "Quick Calibration"
        }
    }

    var instruction: String {
        switch self {
        case .professional:
            return "Aim the center frame at the gray card measured by your physical meter."
        case .standard:
            return "Fill the center frame with an 18% gray card and capture five samples."
        case .quick:
            return "Aim at the scene you want to use as the temporary iPhone reference."
        }
    }

    var requiredSamples: Int {
        switch self {
        case .standard:
            return 5
        case .professional, .quick:
            return 1
        }
    }
}

private struct CalibrationCaptureOverlay: View {
    let mode: CalibrationCaptureMode
    let nativeLensName: String
    let sampleCount: Int
    let message: String?
    let onCancel: () -> Void
    let onCapture: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topPanel
                .padding(.horizontal, 20)
                .padding(.top, 18)

            Spacer()

            calibrationFrame

            Spacer()

            bottomControls
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .background(Color.black.opacity(0.18).ignoresSafeArea())
    }

    private var topPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(nativeLensName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            Text(mode.instruction)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var calibrationFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 2)
                .frame(width: 176, height: 132)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                .frame(width: 136, height: 96)

            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: 5, height: 5)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(height: 44)
                .frame(maxWidth: .infinity)

            Button(captureTitle, action: onCapture)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .offset(y: -24)
            }
        }
    }

    private var captureTitle: String {
        if mode.requiredSamples > 1 {
            return "Sample \(sampleCount + 1)/\(mode.requiredSamples)"
        }
        return "Capture"
    }
}

// MARK: - Preview

#Preview("Main Metering View") {
    MainMeteringView()
        .preferredColorScheme(.dark)
}
