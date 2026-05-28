import Foundation

@main
struct MeteringLumaSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/Managers/CameraManager.swift",
            encoding: .utf8
        )

        precondition(source.contains("kCVPixelFormatType_420YpCbCr8BiPlanarFullRange"))
        precondition(source.contains("static let spotMeteringAreaRatio: Double = 0.02"))
        precondition(source.contains("static let minimumMeteringAreaRatio: Double = 0.01"))
        precondition(source.contains("static let maximumMeteringAreaRatio: Double = 0.05"))
        precondition(source.contains("func getBrightness(at point: CGPoint, areaRatio: Double = MeteringSampling.spotMeteringAreaRatio) -> Double"))
        precondition(source.contains("private func meteringSideLength(for frame: CVImageBuffer, areaRatio: Double) -> Int"))
        precondition(source.contains("private func extractLumaBrightness"))
        precondition(source.contains("CVPixelBufferGetBaseAddressOfPlane(frame, 0)"))
        precondition(source.contains("private func extractBGRABrightness"))
        precondition(!source.contains("func getBrightness(at point: CGPoint, regionSize: Int = 64) -> Double"))
    }
}
