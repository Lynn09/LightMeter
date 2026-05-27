import Foundation

@main
struct FilmPackagingMetadataTest {
    static func main() {
        let presets = FilmPreset.allPresets

        precondition(!presets.isEmpty)
        precondition(presets.allSatisfy { !$0.packagingImageName.isEmpty })
        precondition(FilmPreset.velvia50.packagingImageName == "film_pack_velvia_50")
        precondition(FilmPreset.provia100F.packagingImageName == "film_pack_provia_100f")
        precondition(FilmPreset.ektachrome.packagingImageName == "film_pack_ektachrome")
    }
}
