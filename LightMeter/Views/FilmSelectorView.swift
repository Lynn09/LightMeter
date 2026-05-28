import SwiftUI

/// 胶片选择抽屉视图
/// 顶部下拉样式，显示可用的胶片预设列表
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
        static let popoverMaxHeight: CGFloat = 420
        static let cornerRadius: CGFloat = 18
        static let headerHeight: CGFloat = 60
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
        .frame(maxHeight: Constants.popoverMaxHeight)
        .background(Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 12)
        .overlay(alignment: .topLeading) {
            filmAnchorTriangle
                .offset(x: 56, y: -7)
        }
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

    private var filmAnchorTriangle: some View {
        Triangle()
            .fill(Colors.background)
            .frame(width: 14, height: 7)
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

    private let packagingSize: CGFloat = 72
    private let checkColumnWidth: CGFloat = 28

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                FilmPackagingImageView(film: film)
                    .frame(
                        width: packagingSize,
                        height: packagingSize
                    )

                // 胶片信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(film.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(film.zoneRange) · \(film.description)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8E8E93")!)

                    Text("ISO \(film.iso)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(film.swiftColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(film.swiftColor)
                            .accessibilityLabel("已选择")
                    } else {
                        Color.clear
                    }
                }
                .frame(width: checkColumnWidth)
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

// MARK: - Film Packaging Image View

private struct FilmPackagingImageView: View {
    let film: FilmPreset

    var body: some View {
        ZStack {
            if let image = UIImage(named: film.packagingImageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(film.swiftColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    film.swiftColor.opacity(0.55),
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 5) {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))

                Text(film.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 5)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
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

        FilmSelectorView(
            selectedFilm: $selectedFilm,
            isPresented: $isPresented,
            onFilmSelected: { film in
                print("Selected: \(film.name)")
            }
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
    .preferredColorScheme(.dark)
}
