import SwiftUI

/// 顶部工具栏视图
/// 显示胶片选择按钮和当前 EV 值
struct TopToolbar: View {

    // MARK: - Properties

    /// 当前选中的胶片
    let currentFilm: FilmPreset

    /// 当前 EV 值
    let currentEV: Double

    /// 当前校准状态
    let calibrationStatus: String

    /// 胶片选择抽屉是否展开
    let isFilmSelectorPresented: Bool

    /// 设置按钮点击回调
    let onSettingsButtonTap: () -> Void

    /// 胶片选择按钮点击回调
    let onFilmButtonTap: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let height: CGFloat = 64
        static let horizontalPadding: CGFloat = 20
        static let buttonCornerRadius: CGFloat = 8
        static let buttonPaddingH: CGFloat = 12
        static let buttonPaddingV: CGFloat = 8
        static let filmIconSize: CGFloat = 20
        static let evLabelSize: CGFloat = 13
        static let evValueSize: CGFloat = 20
        static let statusWidth: CGFloat = 144
        static let settingsWidth: CGFloat = 48
        static let filmButtonMaxWidth: CGFloat = 136
    }

    private enum Colors {
        static let background = Color.black
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let filmIcon = Color(hex: "#007AFF")!
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                settingsButton
                    .frame(width: Constants.settingsWidth, alignment: .leading)

                Spacer()

                evAndIsoDisplay
                    .frame(width: Constants.statusWidth, alignment: .trailing)
            }

            filmButton
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: Constants.height)
        .padding(.horizontal, Constants.horizontalPadding)
        .background(Colors.background)
    }

    // MARK: - Subviews

    private var settingsButton: some View {
        Button(action: onSettingsButtonTap) {
            Image(systemName: "gearshape")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(Color.clear)
                .overlay(activeHighlight(isActive: false, color: Colors.textPrimary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    private var filmButton: some View {
        Button(action: onFilmButtonTap) {
            HStack(spacing: 8) {
                // 胶片图标
                Image(systemName: "film")
                    .font(.system(size: Constants.filmIconSize))
                    .foregroundColor(currentFilm.swiftColor)

                // 胶片名称
                Text(currentFilm.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
            .padding(.horizontal, Constants.buttonPaddingH)
            .padding(.vertical, Constants.buttonPaddingV)
            .frame(maxWidth: Constants.filmButtonMaxWidth)
            .background(Color.clear)
            .overlay(activeHighlight(isActive: isFilmSelectorPresented, color: currentFilm.swiftColor))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// EV 与固定胶片 ISO 显示
    private var evAndIsoDisplay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 8) {
                Text("ISO \(currentFilm.iso)")
                    .font(.system(size: Constants.evLabelSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentFilm.swiftColor)

                HStack(spacing: 4) {
                    Text("EV:")
                        .font(.system(size: Constants.evLabelSize))
                        .foregroundColor(Colors.textSecondary)

                    Text(String(format: "%.1f", currentEV))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(Colors.textPrimary)
                }
            }

            Text(calibrationStatus)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func activeHighlight(isActive: Bool, color: Color) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Capsule()
                .fill(color.opacity(isActive ? 0.88 : 0))
                .frame(width: isActive ? 22 : 0, height: 2)
        }
    }
}

// MARK: - Preview

#Preview("Top Toolbar") {
    VStack(spacing: 0) {
        // Velvia 50
        TopToolbar(
            currentFilm: .velvia50,
            currentEV: 12.5,
            calibrationStatus: "Uncalibrated",
            isFilmSelectorPresented: false,
            onSettingsButtonTap: {},
            onFilmButtonTap: {}
        )

        Divider()

        // Provia 100F
        TopToolbar(
            currentFilm: .provia100F,
            currentEV: 14.0,
            calibrationStatus: "Standard +0.1 EV",
            isFilmSelectorPresented: true,
            onSettingsButtonTap: {},
            onFilmButtonTap: {}
        )

        Divider()

        // Ektachrome
        TopToolbar(
            currentFilm: .ektachrome,
            currentEV: 11.0,
            calibrationStatus: "Professional -0.2 EV",
            isFilmSelectorPresented: false,
            onSettingsButtonTap: {},
            onFilmButtonTap: {}
        )

        Spacer()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
