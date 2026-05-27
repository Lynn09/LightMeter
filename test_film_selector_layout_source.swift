import Foundation

@main
struct FilmSelectorLayoutSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/Views/FilmSelectorView.swift",
            encoding: .utf8
        )

        precondition(source.contains("private let checkColumnWidth: CGFloat = 28"))
        precondition(source.contains(".frame(width: checkColumnWidth)"))
        precondition(source.contains(".layoutPriority(1)"))
    }
}
