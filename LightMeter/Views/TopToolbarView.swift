import SwiftUI

// MARK: - TopToolbarView

/// 顶部工具栏视图
struct TopToolbarView: View {
    @ObservedObject var viewModel: MeteringViewModel
    let onFilmButtonTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 胶片选择按钮
            filmButton

            Spacer()

            // EV 值显示
            evDisplay
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - 胶片按钮

    private var filmButton: some View {
        Button(action: onFilmButtonTap) {
            HStack(spacing: 8) {
                // 胶片颜色指示
                Circle()
                    .fill(viewModel.selectedFilm.swiftColor)
                    .frame(width: 12, height: 12)

                // 胶片名称
                Text(viewModel.selectedFilm.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color.white.opacity(0.1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - EV 显示

    private var evDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)

            Text(viewModel.currentExposure.formattedEV)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.white.opacity(0.1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    TopToolbarView(viewModel: MeteringViewModel()) {}
        .preferredColorScheme(.dark)
}
