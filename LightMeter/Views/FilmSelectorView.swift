import SwiftUI

/// 胶片选择弹窗视图
/// 底部弹窗样式，显示可用的胶片预设列表
struct FilmSelectorView: View {

    // MARK: - Properties

    /// 当前选中的胶片
    @Binding var selectedFilm: FilmPreset

    /// 是否显示弹窗
    @Binding var isPresented: Bool

    /// 胶片选择回调
    let onFilmSelected: (FilmPreset) -> Void

    // MARK: - Constants

    private enum Constants {
        static let sheetHeight: CGFloat = 400
        static let cornerRadius: CGFloat = 20
        static let headerHeight: CGFloat = 60
        static let optionHeight: CGFloat = 100
        static let horizontalPadding: CGFloat = 20
        static let optionSpacing: CGFloat = 12
    }

    private enum Colors {
        static let background = Color(hex: "#1C1C1E")!
        static let optionBackground = Color(hex: "#2C2C2E")!
        static let selectedBackground = Color(hex: "#007AFF20")!
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "#8E8E93")!
        static let closeButtonBackground = Color(hex: "#2C2C2E")!
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            header

            // 胶片选项列表
            filmOptionsList
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
            Text("选择胶片")
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

    /// 胶片选项列表
    private var filmOptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Constants.optionSpacing) {
                ForEach(FilmPreset.allPresets) { film in
                    FilmOptionRow(
                        film: film,
                        isSelected: film == selectedFilm,
                        onSelect: { selectFilm(film) }
                    )
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    /// 选择胶片
    private func selectFilm(_ film: FilmPreset) {
        selectedFilm = film
        onFilmSelected(film)
    }
}

// MARK: - Film Option Row

/// 单个胶片选项行
private struct FilmOptionRow: View {
    let film: FilmPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 颜色圆点
                Image(film.packagingImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 72)
                    .accessibilityLabel(film.name)

                // 胶片信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(film.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(film.zoneRange) · \(film.localizedDescription)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8E8E93")!)
                }

                Spacer()

                Text("ISO \(film.iso)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(film.swiftColor)

                // 选中图标
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(film.swiftColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return film.swiftColor.opacity(0.15)
        } else {
            return Color(hex: "#2C2C2E")!
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
#Preview("Film Selector") {
    @Previewable @State var selectedFilm: FilmPreset = .velvia50
    @Previewable @State var isPresented = true

    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Text("背景内容")
                .foregroundColor(.white)

            Spacer()
        }

        // 胶片选择弹窗
        VStack {
            Spacer()

            FilmSelectorView(
                selectedFilm: $selectedFilm,
                isPresented: $isPresented,
                onFilmSelected: { film in
                    print("Selected: \(film.name)")
                }
            )
        }
        .ignoresSafeArea()
    }
    .preferredColorScheme(.dark)
}
