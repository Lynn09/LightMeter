import Foundation

@main
struct AssetCatalogBuildPhaseTest {
    static func main() throws {
        let project = try String(
            contentsOfFile: "LightMeter.xcodeproj/project.pbxproj",
            encoding: .utf8
        )

        precondition(project.contains("PBXResourcesBuildPhase"))
        precondition(project.contains("Assets.xcassets in Resources"))
        precondition(project.contains("3CF724B12FC6B06000B415E1 /* Assets.xcassets in Resources */,"))
        precondition(!project.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }
}
