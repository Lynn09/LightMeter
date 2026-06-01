import Foundation

@main
struct LocalizationSourceTest {
    static func main() throws {
        let fileManager = FileManager.default
        let requiredFiles = [
            "LightMeter/en.lproj/Localizable.strings",
            "LightMeter/zh-Hans.lproj/Localizable.strings",
            "LightMeter/en.lproj/InfoPlist.strings",
            "LightMeter/zh-Hans.lproj/InfoPlist.strings"
        ]

        for path in requiredFiles {
            precondition(fileManager.fileExists(atPath: path), "Missing localization file: \(path)")
        }

        let project = try String(contentsOfFile: "LightMeter.xcodeproj/project.pbxproj", encoding: .utf8)
        precondition(project.contains("zh-Hans"))
        precondition(project.contains("Localizable.strings in Resources"))
        precondition(project.contains("InfoPlist.strings in Resources"))

        let english = try String(contentsOfFile: "LightMeter/en.lproj/Localizable.strings", encoding: .utf8)
        let simplifiedChinese = try String(contentsOfFile: "LightMeter/zh-Hans.lproj/Localizable.strings", encoding: .utf8)
        let requiredKeys = [
            "settings.title",
            "settings.calibration.professional",
            "calibration.standard.instruction",
            "film.selector.title",
            "metering.points.title",
            "preview.subjectMetering",
            "exposure.aperture",
            "exposure.shutter",
            "camera.error.permissionDenied"
        ]

        for key in requiredKeys {
            precondition(english.contains("\"\(key)\""), "Missing English key: \(key)")
            precondition(simplifiedChinese.contains("\"\(key)\""), "Missing zh-Hans key: \(key)")
        }

        let mainView = try String(contentsOfFile: "LightMeter/Views/MainMeteringView.swift", encoding: .utf8)
        let settings = try String(contentsOfFile: "LightMeter/Views/SettingsView.swift", encoding: .utf8)
        let calibration = try String(contentsOfFile: "LightMeter/Models/MeteringCalibration.swift", encoding: .utf8)
        let camera = try String(contentsOfFile: "LightMeter/Managers/CameraManager.swift", encoding: .utf8)

        precondition(mainView.contains("String(localized: \"calibration.professional.title\")"))
        precondition(settings.contains("Text(\"settings.calibration.professional\")"))
        precondition(calibration.contains("String(localized: \"calibration.level.professional\")"))
        precondition(camera.contains("String(localized: \"camera.error.permissionDenied\")"))
    }
}
