import SwiftUI

struct TopToolbar: View {
    let currentFilm: FilmPreset
    let currentEV: Double?
    let lockedDistance: Double?
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
                        HStack(spacing: 6) {
                            Text(currentFilm.zoneRange)
                            if let lockedDistance {
                                Label(String(format: "%.2f m", lockedDistance), systemImage: "lock.fill")
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel(String(format: "距离已锁定 %.2f 米", lockedDistance))
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
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
