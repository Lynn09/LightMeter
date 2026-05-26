import SwiftUI

/// 快门选择弹窗视图
/// 底部弹窗样式，显示标准快门速度列表
struct ShutterSelectorView: View {

    // MARK: - Properties

    /// 当前选中的快门速度（nil 表示未锁定）
    @Binding var selectedShutterSpeed: Double?

    /// 是否显示弹窗
    @Binding var isPresented: Bool

    /// 快门选择回调
    let onShutterSelected: (Double?) -> Void

    // MARK: - Constants

    private enum Constants {
        static let sheetHeight: CGFloat = 520
        static let cornerRadius: CGFloat = 20
        static let headerHeight: CGFloat = 60
        static let horizontalPadding: CGFloat = 20
        static let optionSpacing: CGFloat = 8
    }

    private enum Colors {
        static let background = Color(hex: "#1C1C1E")!
        static let optionBackground = Color(hex: "#2C2C2E")!
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let closeButtonBackground = Color(hex: "#2C2C2E")!
        static let unlockButtonBackground = Color(hex: "#FF3B3020")!
        static let unlockButtonText = Color(hex: "#FF3B30")!
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            if selectedShutterSpeed != nil {
                unlockButton
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.bottom, 12)
            }

            shutterOptionsList
        }
        .frame(height: Constants.sheetHeight)
        .background(Colors.background)
        .cornerRadius(Constants.cornerRadius, corners: [.topLeft, .topRight])
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("选择快门")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Colors.closeButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: Constants.headerHeight)
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private var unlockButton: some View {
        Button(action: unlockShutter) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("解锁快门")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Colors.unlockButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Colors.unlockButtonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Colors.unlockButtonText.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var shutterOptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Constants.optionSpacing) {
                ForEach(ExposureCalculator.standardShutterSpeeds, id: \.self) { shutterSpeed in
                    ShutterOptionRow(
                        shutterSpeed: shutterSpeed,
                        isSelected: selectedShutterSpeed == shutterSpeed,
                        onSelect: { selectShutter(shutterSpeed) }
                    )
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    private func selectShutter(_ shutterSpeed: Double) {
        selectedShutterSpeed = shutterSpeed
        onShutterSelected(shutterSpeed)
    }

    private func unlockShutter() {
        selectedShutterSpeed = nil
        onShutterSelected(nil)
    }
}

// MARK: - Shutter Option Row

private struct ShutterOptionRow: View {
    let shutterSpeed: Double
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#007AFF")!.opacity(0.2) : Color(hex: "#3A3A3C")!)
                        .frame(width: 44, height: 44)

                    Image(systemName: "stopwatch")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? Color(hex: "#007AFF") : .white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ExposureCalculator.formatShutterSpeed(shutterSpeed))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(shutterDescription)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8E8E93")!)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#007AFF")!)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        isSelected ? Color(hex: "#007AFF")!.opacity(0.15) : Color(hex: "#2C2C2E")!
    }

    private var shutterDescription: String {
        if shutterSpeed < 1.0 / 1000.0 {
            return "高速快门 · 凝固动作"
        } else if shutterSpeed < 1.0 / 125.0 {
            return "常用手持 · 日间"
        } else if shutterSpeed < 1.0 / 30.0 {
            return "慢速手持 · 注意稳定"
        } else if shutterSpeed < 1.0 {
            return "慢门 · 建议支撑"
        } else {
            return "长曝光 · 建议三脚架"
        }
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Shutter Selector") {
    @Previewable @State var selectedShutterSpeed: Double? = 1.0 / 125.0
    @Previewable @State var isPresented = true

    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            ShutterSelectorView(
                selectedShutterSpeed: $selectedShutterSpeed,
                isPresented: $isPresented,
                onShutterSelected: { _ in }
            )
        }
        .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}
