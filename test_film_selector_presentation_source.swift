import Foundation

@main
struct FilmSelectorPresentationSourceTest {
    static func main() throws {
        let mainView = try String(
            contentsOfFile: "LightMeter/Views/MainMeteringView.swift",
            encoding: .utf8
        )
        let selectorView = try String(
            contentsOfFile: "LightMeter/Views/FilmSelectorView.swift",
            encoding: .utf8
        )

        precondition(mainView.contains("filmSelectorOverlay"))
        precondition(mainView.contains(".transition(.move(edge: .top).combined(with: .opacity))"))
        precondition(mainView.contains("proxy.safeAreaInsets.top"))
        precondition(!mainView.contains(".ignoresSafeArea(edges: .top)"))
        precondition(!mainView.contains("Spacer()\n\n            FilmSelectorView"))
        precondition(selectorView.contains("static let drawerHeight: CGFloat = 420"))
        precondition(selectorView.contains("corners: [.bottomLeft, .bottomRight]"))
    }
}
