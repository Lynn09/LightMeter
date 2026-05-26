#!/usr/bin/env swift

import Foundation

// 简化版的 ExposureCalculator 用于测试
struct TestExposureCalculator {
    static let calibrationConstant: Double = 12.5
    static let referenceEV: Double = log2(0.18 / 12.5)
    static let baseAperture: Double = 8.0
    static let baseShutterSpeed: Double = 1.0 / 125.0

    static func brightnessToEV(brightness: Double) -> Double {
        guard brightness > 0 else { return 0 }
        return log2(brightness / calibrationConstant)
    }

    static func evToZone(ev: Double) -> Int {
        let rawZone = Int(round((ev - referenceEV) + 5.0))
        return max(0, min(10, rawZone))
    }

    static func zoneToEV(zone: Int) -> Double {
        return referenceEV + (Double(zone) - 5.0)
    }

    static func distanceToLatitude(zone: Double, minZone: Int, maxZone: Int) -> Double {
        if zone < Double(minZone) {
            return Double(minZone) - zone
        } else if zone > Double(maxZone) {
            return zone - Double(maxZone)
        } else {
            return 0
        }
    }

    static func calculateOptimalAdjustment(
        zones: [Int],
        minZone: Int,
        maxZone: Int,
        step: Double = 0.05,
        range: ClosedRange<Double> = -5.0...5.0
    ) -> Double {
        guard !zones.isEmpty else { return 0 }

        let minMeasuredZone = zones.min() ?? 5
        let maxMeasuredZone = zones.max() ?? 5
        let averageZone = Double(zones.reduce(0, +)) / Double(zones.count)
        let theoreticalOptimal = 5.0 - averageZone

        let adjustedMinZone = Double(minMeasuredZone) + theoreticalOptimal
        let adjustedMaxZone = Double(maxMeasuredZone) + theoreticalOptimal
        let canAllFitInLatitude = adjustedMinZone >= Double(minZone) && adjustedMaxZone <= Double(maxZone)

        if canAllFitInLatitude {
            return round(theoreticalOptimal / 0.05) * 0.05
        }

        var bestAdjustment: Double = theoreticalOptimal
        var minScore: Double = Double.infinity

        var current = range.lowerBound
        while current <= range.upperBound {
            var totalDistance: Double = 0
            var pointsOutOfBounds = 0

            for zone in zones {
                let adjustedZone = Double(zone) + current
                let distance = distanceToLatitude(zone: adjustedZone, minZone: minZone, maxZone: maxZone)
                totalDistance += distance
                if distance > 0 {
                    pointsOutOfBounds += 1
                }
            }

            let deviationFromOptimal = abs(current - theoreticalOptimal)
            let score = Double(pointsOutOfBounds) * 1000.0 + totalDistance * 10.0 + deviationFromOptimal

            if score < minScore {
                minScore = score
                bestAdjustment = current
            }

            current += step
        }

        return round(bestAdjustment / 0.05) * 0.05
    }

    static func calculateAperture(baseAperture: Double, stops: Double) -> Double {
        return baseAperture * pow(2.0, stops / 2.0)
    }

    static func calculateShutterSpeed(baseShutterSpeed: Double, stops: Double) -> Double {
        return baseShutterSpeed * pow(2.0, -stops)
    }

    static func calculateExposure(
        zones: [Int],
        minZone: Int,
        maxZone: Int,
        iso: Int = 100
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double, adjustment: Double, hasOutOfBounds: Bool, outOfBoundsCount: Int) {
        guard !zones.isEmpty else {
            return (
                aperture: baseAperture,
                shutterSpeed: baseShutterSpeed,
                iso: iso,
                ev: zoneToEV(zone: 5),
                adjustment: 0,
                hasOutOfBounds: false,
                outOfBoundsCount: 0
            )
        }

        let adjustment = calculateOptimalAdjustment(
            zones: zones,
            minZone: minZone,
            maxZone: maxZone
        )

        let aperture = calculateAperture(baseAperture: baseAperture, stops: adjustment)
        let shutterSpeed = calculateShutterSpeed(baseShutterSpeed: baseShutterSpeed, stops: adjustment)

        let isoAdjustment = log2(Double(iso) / 100.0)
        let adjustedShutterSpeed = shutterSpeed * pow(2.0, -isoAdjustment)

        let adjustedZones = zones.map { Double($0) + adjustment }
        let averageZone = adjustedZones.reduce(0, +) / Double(adjustedZones.count)
        let ev = zoneToEV(zone: Int(round(averageZone)))

        var outOfBoundsCount = 0
        for adjustedZone in adjustedZones {
            if adjustedZone < Double(minZone) || adjustedZone > Double(maxZone) {
                outOfBoundsCount += 1
            }
        }
        let hasOutOfBounds = outOfBoundsCount > 0

        return (aperture, adjustedShutterSpeed, iso, ev, adjustment, hasOutOfBounds, outOfBoundsCount)
    }
}

// MARK: - 测试用例

func runTests() {
    print(String(repeating: "=", count: 70))
    print("曝光计算行为测试")
    print(String(repeating: "=", count: 70))
    print()

    // 使用 Provia 100F: Zone III-VIII
    let filmMinZone = 3
    let filmMaxZone = 8

    print("胶片: Provia 100F (宽容度 Zone \(filmMinZone)-\(filmMaxZone))")
    print()

    // 测试场景1: 只测天空（亮部）
    print("测试1: 只测天空（亮部，Zone VIII-IX）")
    print(String(repeating: "-", count: 50))
    let skyZones = [8, 9]
    let exposure1 = TestExposureCalculator.calculateExposure(
        zones: skyZones,
        minZone: filmMinZone,
        maxZone: filmMaxZone
    )
    print("测光点 Zones: \(skyZones)")
    print("调整后 Zones: \(skyZones.map { Double($0) + exposure1.adjustment })")
    print("曝光调整: \(String(format: "%.2f", exposure1.adjustment)) 档 \(exposure1.adjustment > 0 ? "(增加曝光/提亮)" : "(减少曝光/压暗)")")
    print("光圈: f/\(String(format: "%.1f", exposure1.aperture))")
    print("快门: \(String(format: "%.4f", exposure1.shutterSpeed))s")
    print()

    // 测试场景2: 只测前景（暗部）
    print("测试2: 只测前景（暗部，Zone II-III）")
    print(String(repeating: "-", count: 50))
    let foregroundZones = [2, 3]
    let exposure2 = TestExposureCalculator.calculateExposure(
        zones: foregroundZones,
        minZone: filmMinZone,
        maxZone: filmMaxZone
    )
    print("测光点 Zones: \(foregroundZones)")
    print("调整后 Zones: \(foregroundZones.map { Double($0) + exposure2.adjustment })")
    print("曝光调整: \(String(format: "%.2f", exposure2.adjustment)) 档 \(exposure2.adjustment > 0 ? "(增加曝光/提亮)" : "(减少曝光/压暗)")")
    print("光圈: f/\(String(format: "%.1f", exposure2.aperture))")
    print("快门: \(String(format: "%.4f", exposure2.shutterSpeed))s")
    print()

    // 测试场景3: 同时测天空和前景
    print("测试3: 同时测天空和前景（Zone II + Zone VIII）")
    print(String(repeating: "-", count: 50))
    let mixedZones = [2, 8]
    let exposure3 = TestExposureCalculator.calculateExposure(
        zones: mixedZones,
        minZone: filmMinZone,
        maxZone: filmMaxZone
    )
    print("测光点 Zones: \(mixedZones)")
    print("调整后 Zones: \(mixedZones.map { Double($0) + exposure3.adjustment })")
    print("曝光调整: \(String(format: "%.2f", exposure3.adjustment)) 档 \(exposure3.adjustment > 0 ? "(增加曝光/提亮)" : "(减少曝光/压暗)")")
    print("光圈: f/\(String(format: "%.1f", exposure3.aperture))")
    print("快门: \(String(format: "%.4f", exposure3.shutterSpeed))s")
    print()

    print(String(repeating: "=", count: 70))
    print("测试完成")
    print(String(repeating: "=", count: 70))
    print()
    print("总结:")
    print("- 只测天空(亮部): 调整量 \(String(format: "%.2f", exposure1.adjustment)) 档")
    print("- 只测前景(暗部): 调整量 \(String(format: "%.2f", exposure2.adjustment)) 档")
    print("- 同时测光: 调整量 \(String(format: "%.2f", exposure3.adjustment)) 档")
}

// 运行测试
runTests()
