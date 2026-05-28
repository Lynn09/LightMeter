import Foundation

@main
struct ExposurePointEVSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/ViewModels/MeteringViewModel.swift",
            encoding: .utf8
        )

        precondition(source.contains("private var averageMeteredEV: Double?"))
        precondition(source.contains("private func refreshMeteringPointZones()"))
        precondition(source.contains("ExposureCalculator.evToZone(ev: point.ev, referenceEV: zoneReferenceEV)"))
        precondition(source.contains("let meteredEV = averageMeteredEV"))
        precondition(source.contains("ev: meteredEV"))
        precondition(source.contains("ExposureCalculator.calculateAutoExposure("))
        precondition(!source.contains("let averageEV = ExposureCalculator.referenceEV + (averageZone - 5.0)"))
    }
}
