import Foundation

@main
struct FilmPackagingMetadataTest {
    static func main() {
        let presets = FilmPreset.allPresets

        precondition(presets.count == 8)
        precondition(presets.allSatisfy { !$0.packagingImageName.isEmpty })
        precondition(FilmPreset.velvia50.packagingImageName == "film_pack_velvia_50")
        precondition(FilmPreset.velvia100.packagingImageName == "film_pack_velvia_100")
        precondition(FilmPreset.provia100F.packagingImageName == "film_pack_provia_100f")
        precondition(FilmPreset.ektachrome.packagingImageName == "film_pack_ektachrome")
        precondition(FilmPreset.portra160.packagingImageName == "film_pack_portra_160")
        precondition(FilmPreset.portra400.packagingImageName == "film_pack_portra_400")
        precondition(FilmPreset.gold200.packagingImageName == "film_pack_gold_200")
        precondition(FilmPreset.ultramax400.packagingImageName == "film_pack_ultramax_400")
    }
}
