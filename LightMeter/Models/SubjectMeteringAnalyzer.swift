import CoreGraphics
import Foundation

// MARK: - Subject Metering Result

/// 静态帧主体测光结果
struct SubjectMeteringResult {
    let normalizedPoint: CGPoint
    let brightness: Double
    let confidence: Double
}

// MARK: - Subject Metering Analyzer

/// 基于静态帧亮度反差和中心权重估算主体测光位置
enum SubjectMeteringAnalyzer {
    static func analyze(
        gridSize: Int = 9,
        centralInset: CGFloat = 0.12,
        sampler: (CGPoint) -> Double
    ) -> SubjectMeteringResult? {
        guard gridSize >= 3 else { return nil }

        let lower = centralInset
        let upper = 1.0 - centralInset
        let step = (upper - lower) / CGFloat(gridSize - 1)

        var samples: [(point: CGPoint, brightness: Double)] = []
        samples.reserveCapacity(gridSize * gridSize)

        for row in 0..<gridSize {
            for column in 0..<gridSize {
                let point = CGPoint(
                    x: lower + CGFloat(column) * step,
                    y: lower + CGFloat(row) * step
                )
                let brightness = max(0, min(1, sampler(point)))
                samples.append((point, brightness))
            }
        }

        guard !samples.isEmpty else { return nil }

        let averageBrightness = samples.map(\.brightness).reduce(0, +) / Double(samples.count)

        guard let best = samples.max(by: { lhs, rhs in
            score(for: lhs, averageBrightness: averageBrightness) < score(for: rhs, averageBrightness: averageBrightness)
        }) else {
            return nil
        }

        let contrast = abs(best.brightness - averageBrightness)
        let confidence = min(1.0, contrast / 0.45)

        return SubjectMeteringResult(
            normalizedPoint: best.point,
            brightness: best.brightness,
            confidence: confidence
        )
    }

    private static func score(
        for sample: (point: CGPoint, brightness: Double),
        averageBrightness: Double
    ) -> Double {
        let contrast = abs(sample.brightness - averageBrightness)
        let dx = Double(sample.point.x - 0.5)
        let dy = Double(sample.point.y - 0.5)
        let distanceFromCenter = sqrt(dx * dx + dy * dy)
        let centrality = max(0, 1.0 - distanceFromCenter / 0.7)

        return contrast * (0.65 + 0.35 * centrality)
    }
}
