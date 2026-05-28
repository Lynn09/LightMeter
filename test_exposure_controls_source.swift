import Foundation

@main
struct ExposureControlsSourceTest {
    static func main() throws {
        let toolbar = try String(
            contentsOfFile: "LightMeter/Views/TopToolbar.swift",
            encoding: .utf8
        )
        let exposureInfo = try String(
            contentsOfFile: "LightMeter/Views/ExposureInfoView.swift",
            encoding: .utf8
        )
        let apertureSelector = try String(
            contentsOfFile: "LightMeter/Views/ApertureSelectorView.swift",
            encoding: .utf8
        )
        let shutterSelector = try String(
            contentsOfFile: "LightMeter/Views/ShutterSelectorView.swift",
            encoding: .utf8
        )
        let mainView = try String(
            contentsOfFile: "LightMeter/Views/MainMeteringView.swift",
            encoding: .utf8
        )
        let drawer = try String(
            contentsOfFile: "LightMeter/Views/MeteringPointDrawerView.swift",
            encoding: .utf8
        )

        precondition(toolbar.contains("ISO \\(currentFilm.iso)"))
        precondition(toolbar.contains("evAndIsoDisplay"))
        precondition(exposureInfo.contains("HStack(spacing: 0)"))
        precondition(!exposureInfo.contains("label: \"ISO\""))
        precondition(!exposureInfo.contains("private var displayISO"))

        precondition(drawer.contains("Color.black.opacity(0.72)"))
        precondition(drawer.contains(".shadow(color: Color.black.opacity(0.28)"))

        precondition(mainView.contains("parameterSelectorOverlay"))
        precondition(mainView.contains(".padding(.bottom, Layout.exposureSelectorBottomOffset)"))
        precondition(mainView.contains("GeometryReader { proxy in"))
        precondition(mainView.contains(".offset(x: parameterSelectorHorizontalOffset(in: proxy.size.width))"))
        precondition(mainView.contains("private func parameterSelectorHorizontalOffset(in availableWidth: CGFloat) -> CGFloat"))
        precondition(mainView.contains("max((availableWidth - Layout.parameterSelectorWidth) / 2 - Layout.parameterSelectorScreenMargin, 0)"))
        precondition(mainView.contains(".transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))"))
        precondition(mainView.contains("withAnimation(.spring(response: 0.28, dampingFraction: 0.9))"))
        precondition(!mainView.contains(".transition(.move(edge: .bottom).combined(with: .opacity))"))
        precondition(mainView.contains("viewModel.lockAperture(aperture)"))
        precondition(mainView.contains("viewModel.lockShutterSpeed(shutterSpeed)"))
        precondition(!mainView.contains("viewModel.closeApertureSelector()\n                        } else {"))
        precondition(!mainView.contains("viewModel.closeShutterSelector()\n                        } else {"))

        precondition(apertureSelector.contains("ApertureRulerPicker"))
        precondition(apertureSelector.contains("lockPriorityButton"))
        precondition(apertureSelector.contains("parameterAnchorTriangle"))
        precondition(apertureSelector.contains("static let overlayMaxWidth: CGFloat = 342"))
        precondition(apertureSelector.contains(".offset(x: -72, y: -1)"))
        precondition(apertureSelector.contains("private let tickWidth: CGFloat = 34"))
        precondition(apertureSelector.contains("private let tickSpacing: CGFloat = 2"))
        precondition(apertureSelector.contains("centerSelectionIndicator"))
        precondition(apertureSelector.contains("Color.white.opacity(0.55)"))
        precondition(!apertureSelector.contains("Rectangle()\n                .fill(Color(hex: \"#007AFF\")!)\n                .frame(width: 2, height: 28)"))
        precondition(apertureSelector.contains("DragGesture(minimumDistance: 0)"))
        precondition(apertureSelector.contains("nearestIndex(for:"))
        precondition(apertureSelector.contains(".clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius"))
        precondition(!apertureSelector.contains("Button {\n            onSelect(aperture)"))
        precondition(!apertureSelector.contains("standardTickSnapping()"))
        precondition(!apertureSelector.contains("apertureDescription"))
        precondition(!apertureSelector.contains("corners: [.topLeft, .topRight]"))

        precondition(shutterSelector.contains("ShutterRulerPicker"))
        precondition(shutterSelector.contains("lockPriorityButton"))
        precondition(shutterSelector.contains("parameterAnchorTriangle"))
        precondition(shutterSelector.contains("static let overlayMaxWidth: CGFloat = 342"))
        precondition(shutterSelector.contains(".offset(x: 72, y: -1)"))
        precondition(shutterSelector.contains("private let tickWidth: CGFloat = 42"))
        precondition(shutterSelector.contains("private let tickSpacing: CGFloat = 2"))
        precondition(shutterSelector.contains("centerSelectionIndicator"))
        precondition(shutterSelector.contains("DragGesture(minimumDistance: 0)"))
        precondition(shutterSelector.contains("nearestIndex(for:"))
        precondition(shutterSelector.contains(".clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius"))
        precondition(!shutterSelector.contains("Button {\n            onSelect(shutterSpeed)"))
        precondition(!shutterSelector.contains("standardTickSnapping()"))
        precondition(!shutterSelector.contains("shutterDescription"))
        precondition(!shutterSelector.contains("corners: [.topLeft, .topRight]"))
    }
}
