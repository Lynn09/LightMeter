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
        precondition(mainView.contains("meteringPointDrawerOverlay"))
        precondition(mainView.contains("isFilmSelectorPresented: showingFilmSelector"))
        precondition(mainView.contains(".transition(.move(edge: .top).combined(with: .opacity))"))
        precondition(mainView.contains(".overlay(alignment: .bottom)"))
        precondition(mainView.contains("proxy.safeAreaInsets.top"))
        precondition(mainView.contains("Layout.filmPopoverTopSpacing"))
        precondition(mainView.contains("static let filmPopoverTopSpacing: CGFloat = 2"))
        precondition(mainView.contains(".padding(.horizontal, Layout.horizontalPadding)"))
        precondition(!mainView.contains(".ignoresSafeArea(edges: .top)"))
        precondition(!mainView.contains("Spacer()\n\n            FilmSelectorView"))
        precondition(!mainView.contains("// 测光点快速编辑抽屉\n                MeteringPointDrawerView"))
        precondition(selectorView.contains("static let popoverMaxHeight: CGFloat = 420"))
        precondition(selectorView.contains(".clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius"))
        precondition(!selectorView.contains("corners: [.bottomLeft, .bottomRight]"))
        precondition(selectorView.contains("filmAnchorTriangle"))
    }
}
