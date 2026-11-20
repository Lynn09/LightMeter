import SwiftUI

/// 光圈选择弹窗视图
/// 底部弹窗样式，显示标准光圈值列表
struct ApertureSelectorView: View {

    // MARK: - Properties

    /// 当前选中的光圈值（nil 表示未锁定）
    @Binding var selectedAperture: Double?

    /// 是否显示弹窗
    @Binding var isPresented: Bool

    /// 光圈选择回调
    let onApertureSelected: (Double?) -> Void

    // MARK: - Constants

    private enum Constants {
        static let sheetHeight: CGFloat = 480
        static let cornerRadius: CGFloat = 20
        static let headerHeight: CGFloat = 60
        static let optionHeight: CGFloat = 56
        static let horizontalPadding: CGFloat = 20
        static let optionSpacing: CGFloat = 8
    }

    private enum Colors {
        static let background = Color(hex: "#1C1C1E")!
        static let optionBackground = Color(hex: "#2C2C2E")!
        static let selectedBackground = Color(hex: "#007AFF20")!
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let closeButtonBackground = Color(hex: "#2C2C2E")!
        static let unlockButtonBackground = Color(hex: "#FF3B3020")!
        static let unlockButtonText = Color(hex: "#FF3B30")!
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            // 解锁按钮（如果已锁定）
            if selectedAperture != nil {
                unlockButton
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.bottom, 12)
            }

            // 光圈选项列表
            apertureOptionsList
        }
        .frame(height: Constants.sheetHeight)
        .background(Colors.background)
        .cornerRadius(Constants.cornerRadius, corners: [.topLeft, .topRight])
    }

    // MARK: - Subviews

    /// 头部视图
    private var header: some View {
        HStack {
            // 标题
            Text("选择光圈")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            // 关闭按钮
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

    /// 解锁按钮
    private var unlockButton: some View {
        Button(action: unlockAperture) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("解锁光圈")
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

    /// 光圈选项列表
    private var apertureOptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Constants.optionSpacing) {
                ForEach(ExposureCalculator.standardApertures, id: \.self) { aperture in
                    ApertureOptionRow(
                        aperture: aperture,
                        isSelected: selectedAperture == aperture,
                        onSelect: { selectAperture(aperture) }
                    )
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    /// 选择光圈
    private func selectAperture(_ aperture: Double) {
        selectedAperture = aperture
        onApertureSelected(aperture)
    }

    /// 解锁光圈
    private func unlockAperture() {
        selectedAperture = nil
        onApertureSelected(nil)
    }
}

// MARK: - Aperture Option Row

/// 单个光圈选项行
private struct ApertureOptionRow: View {
    let aperture: Double
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 光圈图标
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#007AFF")!.opacity(0.2) : Color(hex: "#3A3A3C")!)
                        .frame(width: 44, height: 44)

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? Color(hex: "#007AFF") : .white)
                }

                // 光圈值
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "f/%.1f", aperture))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    // 描述
                    Text(apertureDescription)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8E8E93")!)
                }

                Spacer()

                // 选中图标
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
        if isSelected {
            return Color(hex: "#007AFF")!.opacity(0.15)
        } else {
            return Color(hex: "#2C2C2E")!
        }
    }

    private var apertureDescription: String {
        switch aperture {
        case 1.4: return "大光圈 · 浅景深"
        case 2.0: return "大光圈 · 人像"
        case 2.8: return "常用光圈 · 锐利"
        case 4.0: return "标准光圈 · 通用"
        case 5.6: return "标准光圈 · 锐利"
        case 8.0: return "最佳画质 · 风光"
        case 11.0: return "小光圈 · 全景清晰"
        case 16.0: return "小光圈 · 衍射限制"
        case 22.0: return "最小光圈 · 特殊效果"
        case 32.0: return "极小光圈 · 星芒"
        default: return "标准光圈"
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
#Preview("Aperture Selector") {
    @Previewable @State var selectedAperture: Double? = 8.0
    @Previewable @State var isPresented = true

    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Text("背景内容")
                .foregroundColor(.white)

            Spacer()
        }

        // 光圈选择弹窗
        VStack {
            Spacer()

            ApertureSelectorView(
                selectedAperture: $selectedAperture,
                isPresented: $isPresented,
                onApertureSelected: { aperture in
                    if let aperture = aperture {
                        print("Selected aperture: f/\(aperture)")
                    } else {
                        print("Aperture unlocked")
                    }
                }
            )
        }
        .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}
