import SwiftUI

struct FilmSelectorView: View {
    let selectedFilm: FilmPreset
    let onFilmSelected: (FilmPreset) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilmPreset.allPresets) { film in
                        Button { onFilmSelected(film) } label: {
                            HStack {
                                Image(film.packagingImageName)
                                    .resizable().scaledToFit().frame(width: 34, height: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(film.name).font(.subheadline.bold())
                                    Text("ISO \(film.iso) · \(film.zoneRange)").font(.caption2)
                                    Text(film.localizedDescription).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(6)
                            .background(.white.opacity(film == selectedFilm ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(film == selectedFilm ? .isSelected : [])
                        .id(film.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(selectedFilm.id, anchor: .center) }
        }
        .padding(.bottom, 6)
    }
}
