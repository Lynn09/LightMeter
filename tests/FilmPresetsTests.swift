import Foundation
@main enum FilmPresetsTests {
    static func main() {
        let expected: [(String, Int, Int, Int)] = [
            ("Velvia 50", 50, 4, 8), ("Velvia 100", 100, 4, 8),
            ("Provia 100F", 100, 3, 8), ("Ektachrome", 100, 3, 7),
            ("Portra 160", 160, 2, 9), ("Portra 400", 400, 2, 9),
            ("Gold 200", 200, 2, 8), ("Ultramax 400", 400, 2, 8)
        ]
        precondition(FilmPreset.allPresets.count == 8, "All eight film presets must be restored")
        for (name, iso, low, high) in expected {
            guard let film = FilmPreset.allPresets.first(where: { $0.name == name }) else { fatalError("Missing \(name)") }
            precondition(film.iso == iso && film.minZone == low && film.maxZone == high, "Incorrect ISO or latitude for \(name)")
            let folder = URL(fileURLWithPath: "LightMeter/Assets.xcassets/\(film.packagingImageName).imageset")
            let data = try! Data(contentsOf: folder.appendingPathComponent("Contents.json"))
            let catalog = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            let entries = catalog["images"] as! [[String: Any]]
            let files = entries.compactMap { $0["filename"] as? String }
            precondition(!files.isEmpty, "Missing film image reference")
            for file in files {
                precondition(FileManager.default.fileExists(atPath: folder.appendingPathComponent(file).path), "Missing PNG for \(name)")
            }
        }
        print("FilmPresetsTests passed")
    }
}
