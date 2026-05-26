#!/usr/bin/env swift

import Foundation

// 直接复制当前的 ExposureCalculator 实现

struct ExposureCalculator {
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
        // 修复后的公式: aperture = baseAperture / pow(2.0, stops / 2.0)
        // 正数 stops（增加曝光）-> f值变小（光圈变大）
        // 负数 stops（减少曝光）-> f值变大（光圈变小）
        return baseAperture / pow(2.0, stops / 2.0)
    }

    static func calculateShutterSpeed(baseShutterSpeed: Double, stops: Double) -> Double {
        // 修复后的公式: shutterSpeed = baseShutterSpeed / pow(2.0, stops)
        // 正数 stops（增加曝光）-> 快门变慢（数值变大）
        // 负数 stops（减少曝光）-> 快门变快（数值变小）
        return baseShutterSpeed / pow(2.0, stops)
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

// MARK: - 测试

print("=" * 70)
print("验证修复后的曝光计算")
print("=" * 70)
print()

let filmMinZone = 3
let filmMaxZone = 8

// 测试1: 只测前景（暗部 Zone II-III）
print("测试1: 只测前景（暗部 Zone II-III）")
print("-" * 50)
let foregroundZones = [2, 3]
let exposure1 = ExposureCalculator.calculateExposure(
    zones: foregroundZones,
    minZone: filmMinZone,
    maxZone: filmMaxZone
)
print("测光点 Zones: \(foregroundZones)")
print("曝光调整: \(String(format: "%.2f", exposure1.adjustment)) 档")
print("  \(exposure1.adjustment > 0 ? "↑ 增加曝光（提亮）" : "↓ 减少曝光（压暗）")")
print("光圈: f/\(String(format: "%.1f", exposure1.aperture)) \(exposure1.aperture < 8.0 ? "(变大)" : "(变小)")")
print("快门: \(String(format: "%.4f", exposure1.shutterSpeed))s \(exposure1.shutterSpeed > 0.008 ? "(变慢)" : "(变快)")")
print()

// 测试2: 只测天空（亮部 Zone VIII-IX）
print("测试2: 只测天空（亮部 Zone VIII-IX）")
print("-" * 50)
let skyZones = [8, 9]
let exposure2 = ExposureCalculator.calculateExposure(
    zones: skyZones,
    minZone: filmMinZone,
    maxZone: filmMaxZone
)
print("测光点 Zones: \(skyZones)")
print("曝光调整: \(String(format: "%.2f", exposure2.adjustment)) 档")
print("  \(exposure2.adjustment > 0 ? "↑ 增加曝光（提亮）" : "↓ 减少曝光（压暗）")")
print("光圈: f/\(String(format: "%.1f", exposure2.aperture)) \(exposure2.aperture < 8.0 ? "(变大)" : "(变小)")")
print("快门: \(String(format: "%.4f", exposure2.shutterSpeed))s \(exposure2.shutterSpeed > 0.008 ? "(变慢)" : "(变快)")")
print()

// 验证公式正确性
print("=" * 70)
print("验证公式正确性")
print("=" * 70)
print()

let baseAperture = 8.0
let baseShutter = 1.0/125.0

print("基准值: f/\(baseAperture), \(String(format: "%.4f", baseShutter))s")
print()

// 增加曝光 +2 档
let stopsIncrease = 2.0
let apertureIncrease = baseAperture / pow(2.0, stopsIncrease / 2.0)
let shutterIncrease = baseShutter / pow(2.0, stopsIncrease)
print("增加曝光 +\(Int(stopsIncrease)) 档:")
print("  光圈: f/\(baseAperture) → f/\(String(format: "%.1f", apertureIncrease)) \(apertureIncrease < baseAperture ? "✓ (f值变小/光圈变大)" : "✗")")
print("  快门: \(String(format: "%.4f", baseShutter))s → \(String(format: "%.4f", shutterIncrease))s \(shutterIncrease > baseShutter ? "✓ (变慢)" : "✗")")
print()

// 减少曝光 -2 档
let stopsDecrease = -2.0
let apertureDecrease = baseAperture / pow(2.0, stopsDecrease / 2.0)
let shutterDecrease = baseShutter / pow(2.0, stopsDecrease)
print("减少曝光 \(Int(stopsDecrease)) 档:")
print("  光圈: f/\(baseAperture) → f/\(String(format: "%.1f", apertureDecrease)) \(apertureDecrease > baseAperture ? "✓ (f值变大/光圈变小)" : "✗")")
print("  快门: \(String(format: "%.4f", baseShutter))s → \(String(format: "%.4f", shutterDecrease))s \(shutterDecrease < baseShutter ? "✓ (变快)" : "✗")")
