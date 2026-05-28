import Foundation

@main
struct AppIconSourceTest {
    static func main() throws {
        let project = try String(
            contentsOfFile: "LightMeter.xcodeproj/project.pbxproj",
            encoding: .utf8
        )
        let contents = try String(
            contentsOfFile: "LightMeter/Assets.xcassets/AppIcon.appiconset/Contents.json",
            encoding: .utf8
        )

        precondition(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
        precondition(contents.contains("\"filename\" : \"light.png\""))
        precondition(contents.contains("\"filename\" : \"dark.png\""))
        precondition(contents.contains("\"filename\" : \"light 1.png\""))
    }
}
