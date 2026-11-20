import SwiftUI

struct TopToolbar: View {
    let currentFilm: FilmPreset
    let currentEV: Double?
    let isExpanded: Bool
    let onFilmButtonTap: () -> Void

    var body: some View {
        HStack {
            Button(action: onFilmButtonTap) {
                HStack(spacing: 10) {
                    Image(currentFilm.packagingImageName)
                        .resizable().scaledToFit().frame(width: 34, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentFilm.name).font(.headline)
                        Text(currentFilm.zoneRange).font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("展开或收起胶片选择")
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("EV100").font(.caption).foregroundStyle(.secondary)
                Text(currentEV.flatMap { $0.isFinite ? String(format: "%.1f", $0) : nil } ?? "—")
                    .font(.title2.weight(.semibold)).monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
