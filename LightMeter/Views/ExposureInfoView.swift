import SwiftUI

// MARK: - ExposureInfoView

/// 曝光参数栏视图，显示可调整的光圈和快门
struct ExposureInfoView: View {
    @ObservedObject var viewModel: MeteringViewModel

    /// 格式化曝光补偿显示
    private var compensationText: String {
        let compensation = viewModel.isManualExposure ? viewModel.manualExposureOffset : viewModel.shutterSpeedOffset
        if compensation > 0 {
            return String(format: "+%.1f", compensation)
        } else if compensation < 0 {
            return String(format: "%.1f", compensation)
        } else {
            return "±0.0"
        }
    }

    /// 获取当前要显示的光圈值
    /// 优先级：1. 选中测光点的曝光参数 2. 锁定的光圈值 3. 全局平均曝光
    private var displayAperture: String {
        // 1. 如果有选中的测光点，优先显示该点的光圈
        if let selectedPoint = viewModel.selectedPoint {
            // 如果该点有曝光参数，直接显示
            if let params = selectedPoint.exposureParams {
                return params.formattedAperture
            }

            // 如果该点没有曝光参数，但已锁定光圈，使用锁定的光圈值
            if viewModel.isApertureLocked, let lockedAperture = viewModel.lockedAperture {
                return ExposureCalculator.formatAperture(lockedAperture)
            }
        }

        // 2. 如果没有选中测光点，但已锁定光圈，显示锁定的光圈值
        if viewModel.isApertureLocked, let lockedAperture = viewModel.lockedAperture {
            return ExposureCalculator.formatAperture(lockedAperture)
        }

        // 3. 默认显示全局平均曝光的光圈
        return viewModel.currentExposure.formattedAperture
    }

    /// 获取当前要显示的快门速度
    /// 如果有选中的测光点且该点有曝光参数，显示该点的快门；否则显示全局快门
    private var displayShutterSpeed: String {
        if let selectedPoint = viewModel.selectedPoint,
           let params = selectedPoint.exposureParams {
            return params.formattedShutterSpeed
        }
        return viewModel.currentExposure.formattedShutterSpeed
    }

    var body: some View {
        VStack(spacing: 4) {
            // 曝光补偿指示器
            HStack(spacing: 4) {
                Image(systemName: modeIcon)
                    .font(.system(size: 10))
                Text(viewModel.exposureControlMode.displayName)
                    .font(.system(size: 11, weight: .medium))
                Text("·")
                    .font(.system(size: 11))
                Text(compensationText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(viewModel.exposureControlMode == .automatic ? .gray : Color(hex: "#34C759"))
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
            )

            // 光圈、快门
            HStack(spacing: 0) {
                // 光圈（可点击）
                apertureParameterItem

                Divider()
                    .background(Color.white.opacity(0.2))

                // 快门（可点击）
                shutterParameterItem
            }
            .frame(height: 70)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - 光圈参数项（带锁定状态和点击）

    private var modeIcon: String {
        switch viewModel.exposureControlMode {
        case .automatic:
            return "link"
        case .aperturePriority:
            return "camera.aperture"
        case .shutterPriority:
            return "stopwatch.fill"
        }
    }

    private var apertureParameterItem: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                viewModel.toggleApertureSelector()
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.isApertureLocked ? Color(hex: "#007AFF") : .gray)
                    Text("光圈")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.isApertureLocked ? Color(hex: "#007AFF") : .gray)

                    // 锁定图标
                    if viewModel.isApertureLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#007AFF"))
                    }
                }

                HStack(spacing: 4) {
                    Text(displayAperture)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.isApertureLocked ? Color(hex: "#007AFF") : .white)
                        .minimumScaleFactor(0.8)

                    // 锁定状态下的指示器
                    if viewModel.isApertureLocked {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#007AFF")!.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 快门参数项（带锁定状态和点击）

    private var shutterParameterItem: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                viewModel.toggleShutterSelector()
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.isShutterLocked ? Color(hex: "#007AFF") : .gray)
                    Text("快门")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.isShutterLocked ? Color(hex: "#007AFF") : .gray)

                    if viewModel.isShutterLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#007AFF"))
                    }
                }

                HStack(spacing: 4) {
                    Text(displayShutterSpeed)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.isShutterLocked ? Color(hex: "#007AFF") : .white)
                        .minimumScaleFactor(0.8)

                    if viewModel.isShutterLocked {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#007AFF")!.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

}
