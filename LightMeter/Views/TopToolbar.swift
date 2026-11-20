import SwiftUI

/// 顶部工具栏视图
/// 显示胶片选择按钮和当前 EV 值
struct TopToolbar: View {

    // MARK: - Properties

    /// 当前选中的胶片
    let currentFilm: FilmPreset

    /// 当前 EV 值
    let currentEV: Double?

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
    }

    private enum Colors {
        static let background = Color.black
        static let buttonBackground = Color(hex: "#1C1C1E")!
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let filmIcon = Color(hex: "#007AFF")!
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：胶片选择按钮
            filmButton

            Spacer()

            // 右侧：EV 值显示
            evDisplay
        }
        .frame(height: Constants.height)
        .padding(.horizontal, Constants.horizontalPadding)
        .background(Colors.background)
    }

    // MARK: - Subviews

    /// 胶片选择按钮
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
            .background(Colors.buttonBackground)
            .cornerRadius(Constants.buttonCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// EV 值显示
    private var evDisplay: some View {
        HStack(spacing: 4) {
            // EV 标签
            Text("EV100:")
                .font(.system(size: Constants.evLabelSize))
                .foregroundColor(Colors.textSecondary)

            // EV 数值
            Text(currentEV.flatMap { $0.isFinite ? String(format: "%.1f", $0) : nil } ?? "—")
                .font(.system(size: Constants.evValueSize, weight: .semibold, design: .monospaced))
                .foregroundColor(Colors.textPrimary)
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
            onFilmButtonTap: {}
        )

        Divider()

        // Provia 100F
        TopToolbar(
            currentFilm: .provia100F,
            currentEV: 14.0,
            onFilmButtonTap: {}
        )

        Divider()

        // Ektachrome
        TopToolbar(
            currentFilm: .ektachrome,
            currentEV: 11.0,
            onFilmButtonTap: {}
        )

        Spacer()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
