import CoreGraphics
import Foundation

@main
struct StaticSubjectMeteringTest {
    static func main() {
        let result = SubjectMeteringAnalyzer.analyze(gridSize: 9) { point in
            let dx = point.x - 0.5
            let dy = point.y - 0.5
            let distance = sqrt(dx * dx + dy * dy)
            return distance < 0.16 ? 0.22 : 0.78
        }

        guard let result else {
            preconditionFailure("Expected subject metering result")
        }

        precondition(abs(result.normalizedPoint.x - 0.5) < 0.13)
        precondition(abs(result.normalizedPoint.y - 0.5) < 0.13)
        precondition(abs(result.brightness - 0.22) < 0.01)
        precondition(result.confidence > 0.4)
    }
}
