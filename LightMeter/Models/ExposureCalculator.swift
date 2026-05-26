import Foundation
import SwiftUI

// MARK: - ExposureCalculator

/// 曝光计算工具，负责 EV 到 Zone 的转换和曝光参数计算
struct ExposureCalculator {

    // MARK: - 常数

    /// 测光表校准常数 K = 12.5
    static let calibrationConstant: Double = 12.5

    /// 参考 EV 值（Zone V 对应的 EV）
    static let referenceEV: Double = 12.5  // 标准参考值

    /// 基准光圈值（f/8）
    static let baseAperture: Double = 8.0

    /// 基准快门速度（1/125s）
    static let baseShutterSpeed: Double = 1.0 / 125.0

    // MARK: - 标准档位

    /// 标准光圈值数组
    static let standardApertures: [Double] = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0]

    /// 标准快门速度数组（从快到慢）
    static let standardShutterSpeeds: [Double] = [
        1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
        1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2,
        1.0, 2.0, 4.0, 8.0, 15.0, 30.0
    ]

    // MARK: - EV 与 Zone 转换

    /// 将亮度值转换为 EV 值
    /// 公式: EV = log2(brightness / 0.18) + referenceEV
    /// 其中 0.18 是 Zone V (18%灰卡) 的反射率, referenceEV 是 12.5
    /// 重要: 不可使用 calibrationConstant (12.5) 替代 0.18, 否则会导致所有测光点显示为 Zone 0
    static func brightnessToEV(brightness: Double, referenceEV: Double = ExposureCalculator.referenceEV) -> Double {
        guard brightness > 0 else { return referenceEV }
        // Zone V = 18%反射率 = 0.18, 对应 referenceEV
        return log2(brightness / 0.18) + referenceEV
    }

    /// 将 EV 值映射到 Zone
    static func evToZone(ev: Double, referenceEV: Double = ExposureCalculator.referenceEV) -> Int {
        let rawZone = Int(round((ev - referenceEV) + 5.0))
        return max(0, min(10, rawZone))
    }

    /// 将 Zone 转换为 EV 值
    static func zoneToEV(zone: Int, referenceEV: Double = ExposureCalculator.referenceEV) -> Double {
        return referenceEV + (Double(zone) - 5.0)
    }

    // MARK: - 曝光计算

    /// 计算曝光调整档数
    static func calculateExposureAdjustment(currentZones: [Int], targetZone: Int = 5) -> Double {
        guard !currentZones.isEmpty else { return 0 }
        let averageZone = Double(currentZones.reduce(0, +)) / Double(currentZones.count)
        return Double(targetZone) - averageZone
    }

    /// 根据调整档数计算光圈值
    static func calculateAperture(baseAperture: Double, stops: Double) -> Double {
        return baseAperture / pow(2.0, stops / 2.0)
    }

    /// 根据调整档数计算快门速度
    static func calculateShutterSpeed(baseShutterSpeed: Double, stops: Double) -> Double {
        return baseShutterSpeed / pow(2.0, stops)
    }

    /// 计算点与宽容度边界的距离
    static func distanceToLatitude(zone: Double, minZone: Int, maxZone: Int) -> Double {
        if zone < Double(minZone) {
            return Double(minZone) - zone
        } else if zone > Double(maxZone) {
            return zone - Double(maxZone)
        } else {
            return 0
        }
    }

    /// 计算最优曝光调整量
    static func calculateOptimalAdjustment(
        zones: [Int],
        minZone: Int,
        maxZone: Int,
        step: Double = 0.05,
        range: ClosedRange<Double> = -5.0...5.0
    ) -> Double {
        guard !zones.isEmpty else { return 0 }

        let averageZone = Double(zones.reduce(0, +)) / Double(zones.count)
        let theoreticalOptimal = 5.0 - averageZone

        // 检查是否所有点都能在宽容度内
        let minMeasuredZone = zones.min() ?? 5
        let maxMeasuredZone = zones.max() ?? 5
        let adjustedMinZone = Double(minMeasuredZone) + theoreticalOptimal
        let adjustedMaxZone = Double(maxMeasuredZone) + theoreticalOptimal

        let canAllFitInLatitude = adjustedMinZone >= Double(minZone) && adjustedMaxZone <= Double(maxZone)

        if canAllFitInLatitude {
            return round(theoreticalOptimal / 0.05) * 0.05
        }

        // 搜索最优解
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

    // MARK: - 光圈锁定计算

    /// 根据锁定光圈和测光点 EV 计算快门速度
    /// - Parameters:
    ///   - aperture: 锁定的光圈值
    ///   - pointEV: 测光点的 EV 值
    ///   - iso: 当前 ISO 值
    /// - Returns: 计算后的快门速度（已取整到标准档位）
    static func calculateShutterForLockedAperture(
        aperture: Double,
        pointEV: Double,
        iso: Int
    ) -> Double {
        // 基准: f/8, 1/125s, ISO 100, EV 12.5
        // 计算光圈差异（档数）: diff = 2 * log2(aperture / 8)
        // 当光圈从 f/8 变为 f/11 (大一档)，需要2倍曝光时间
        let apertureStops = 2 * log2(aperture / baseAperture)

        // EV 差异: pointEV - referenceEV
        let evDiff = pointEV - referenceEV

        // ISO 调整（ISO 增加一档，快门可以快一档）
        let isoStops = log2(Double(iso) / 100.0)

        // 快门计算：
        // 基础快门 * 2^(apertureStops - evDiff + isoStops)
        // apertureStops: 光圈变大(>0)需要更慢快门
        // evDiff: EV 越高(>0)需要更快快门
        // isoStops: ISO 越高(>0)需要更快快门
        let shutter = baseShutterSpeed * pow(2.0, apertureStops - evDiff + isoStops)

        // 取整到标准快门档位
        return nearestStandardShutter(shutter)
    }

    /// 取最近的 standard 快门速度
    static func nearestStandardShutter(_ shutter: Double) -> Double {
        guard shutter > 0 else { return baseShutterSpeed }

        // 找到最接近的标准快门速度
        let closest = standardShutterSpeeds.min { abs($0 - shutter) < abs($1 - shutter) }
        return closest ?? baseShutterSpeed
    }

    /// 取最近的 standard 光圈值
    static func nearestStandardAperture(_ aperture: Double) -> Double {
        guard aperture > 0 else { return baseAperture }

        let closest = standardApertures.min { abs($0 - aperture) < abs($1 - aperture) }
        return closest ?? baseAperture
    }

    /// 为单个测光点计算曝光参数（光圈锁定模式）
    /// - Parameters:
    ///   - pointZone: 测光点的 Zone 值
    ///   - pointEV: 测光点的 EV 值
    ///   - lockedAperture: 锁定的光圈值
    ///   - iso: 胶片 ISO 值
    /// - Returns: 该点的曝光参数（光圈、快门、ISO、EV、Zone）
    static func calculateExposureForSinglePoint(
        pointZone: Int,
        pointEV: Double,
        lockedAperture: Double,
        iso: Int
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double, zone: Int) {
        // 根据锁定的光圈和该点的 EV 计算快门
        let shutterSpeed = calculateShutterForLockedAperture(
            aperture: lockedAperture,
            pointEV: pointEV,
            iso: iso
        )

        return (
            aperture: lockedAperture,
            shutterSpeed: shutterSpeed,
            iso: iso,
            ev: pointEV,
            zone: pointZone
        )
    }

    /// 根据目标 EV 和锁定的光圈/快门计算联动曝光参数
    /// - Parameters:
    ///   - ev: 当前测光目标 EV
    ///   - iso: 胶片 ISO
    ///   - lockedAperture: 锁定光圈，存在时进入光圈优先
    ///   - lockedShutterSpeed: 锁定快门，存在时进入快门优先
    /// - Returns: 标准档位吸附后的光圈和快门
    static func calculateCoupledExposure(
        ev: Double,
        iso: Int,
        lockedAperture: Double?,
        lockedShutterSpeed: Double?
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        let evDiff = ev - referenceEV
        let isoStops = log2(Double(iso) / 100.0)

        if let lockedAperture {
            let apertureStops = 2 * log2(lockedAperture / baseAperture)
            let shutter = baseShutterSpeed * pow(2.0, apertureStops - evDiff + isoStops)

            return (
                aperture: nearestStandardAperture(lockedAperture),
                shutterSpeed: nearestStandardShutter(shutter),
                iso: iso,
                ev: ev
            )
        }

        if let lockedShutterSpeed {
            let shutter = nearestStandardShutter(lockedShutterSpeed)
            let apertureStops = log2(shutter / baseShutterSpeed) + evDiff - isoStops
            let aperture = baseAperture * pow(2.0, apertureStops / 2.0)

            return (
                aperture: nearestStandardAperture(aperture),
                shutterSpeed: shutter,
                iso: iso,
                ev: ev
            )
        }

        return (
            aperture: baseAperture,
            shutterSpeed: baseShutterSpeed,
            iso: iso,
            ev: ev
        )
    }

    /// 计算完整曝光参数（光圈锁定模式）
    /// - Parameters:
    ///   - zones: 测光点 Zone 数组
    ///   - lockedAperture: 锁定的光圈值
    ///   - iso: 胶片 ISO
    /// - Returns: 曝光参数元组（使用第一个测光点的 EV 计算快门）
    static func calculateExposureWithLockedAperture(
        zones: [Int],
        lockedAperture: Double,
        iso: Int
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        guard !zones.isEmpty else {
            return (
                aperture: lockedAperture,
                shutterSpeed: baseShutterSpeed,
                iso: iso,
                ev: referenceEV
            )
        }

        // 计算平均 Zone 对应的 EV
        let averageZone = Double(zones.reduce(0, +)) / Double(zones.count)
        let averageEV = zoneToEV(zone: Int(round(averageZone)))

        // 根据锁定的光圈和平均 EV 计算快门
        let shutterSpeed = calculateShutterForLockedAperture(
            aperture: lockedAperture,
            pointEV: averageEV,
            iso: iso
        )

        return (
            aperture: lockedAperture,
            shutterSpeed: shutterSpeed,
            iso: iso,
            ev: averageEV
        )
    }

    /// 计算完整曝光参数
    /// - Parameters:
    ///   - zones: 测光点Zone数组
    ///   - minZone: 胶片宽容度最小Zone
    ///   - maxZone: 胶片宽容度最大Zone
    ///   - iso: 胶片ISO值
    ///   - manualCompensation: 手动曝光补偿（可选），如果提供则使用此值代替自动计算
    /// - Returns: 曝光参数元组
    static func calculateExposure(
        zones: [Int],
        minZone: Int,
        maxZone: Int,
        iso: Int = 100,
        manualCompensation: Double? = nil
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double, adjustment: Double) {
        guard !zones.isEmpty else {
            return (
                aperture: baseAperture,
                shutterSpeed: baseShutterSpeed,
                iso: iso,
                ev: zoneToEV(zone: 5),
                adjustment: 0
            )
        }

        // 计算调整量（使用手动补偿或自动计算）
        let adjustment: Double
        if let compensation = manualCompensation {
            adjustment = compensation
        } else {
            adjustment = calculateOptimalAdjustment(
                zones: zones,
                minZone: minZone,
                maxZone: maxZone
            )
        }

        // 应用调整量计算曝光参数
        let aperture = calculateAperture(baseAperture: baseAperture, stops: adjustment)
        let shutterSpeed = calculateShutterSpeed(baseShutterSpeed: baseShutterSpeed, stops: adjustment)

        // 根据 ISO 调整曝光参数
        let isoAdjustment = log2(Double(iso) / 100.0)
        let adjustedShutterSpeed = shutterSpeed * pow(2.0, -isoAdjustment)

        // 计算调整后的平均 Zone
        let adjustedZones = zones.map { Double($0) + adjustment }
        let averageZone = adjustedZones.reduce(0, +) / Double(adjustedZones.count)
        let ev = zoneToEV(zone: Int(round(averageZone)))

        return (aperture, adjustedShutterSpeed, iso, ev, adjustment)
    }

    // MARK: - 格式化方法

    /// 格式化光圈值为字符串
    static func formatAperture(_ aperture: Double) -> String {
        let standardApertures: [Double] = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0]
        let closest = standardApertures.min { abs($0 - aperture) < abs($1 - aperture) } ?? aperture

        if closest == floor(closest) {
            return String(format: "f/%.0f", closest)
        } else {
            return String(format: "f/%.1f", closest)
        }
    }

    /// 格式化快门速度为字符串
    static func formatShutterSpeed(_ speed: Double) -> String {
        guard speed > 0 else { return "--" }

        let standardSpeeds: [Double] = [
            1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
            1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2,
            1.0, 2.0, 4.0, 8.0, 15.0, 30.0
        ]

        let closest = standardSpeeds.min { abs($0 - speed) < abs($1 - speed) } ?? speed

        if closest >= 1.0 {
            if closest == floor(closest) {
                return String(format: "%.0fs", closest)
            } else {
                return String(format: "%.1fs", closest)
            }
        } else {
            let denominator = Int(round(1.0 / closest))
            return "1/\(denominator)s"
        }
    }

    /// 格式化 ISO 值为字符串
    static func formatISO(_ iso: Int) -> String {
        return "ISO \(iso)"
    }

    /// 格式化 EV 值为字符串
    static func formatEV(_ ev: Double) -> String {
        return String(format: "EV %.1f", ev)
    }

    // MARK: - 快门控制计算

    /// 根据快门偏移计算曝光参数
    /// - Parameters:
    ///   - zones: 所有测光点的Zone值
    ///   - shutterOffset: 快门偏移量（Zone单位）
    ///   - lockedAperture: 锁定的光圈值（可选）
    ///   - iso: 胶片ISO值
    ///   - baseShutterSpeed: 基准快门速度
    /// - Returns: 计算后的曝光结果
    static func calculateExposureWithShutterOffset(
        zones: [Int],
        shutterOffset: Double,
        lockedAperture: Double? = nil,
        iso: Int,
        baseShutterSpeed: Double = 1/125.0
    ) -> (aperture: Double, shutterSpeed: Double, iso: Int, ev: Double) {
        // 计算平均Zone
        let avgZone = zones.isEmpty ? 5 : Double(zones.reduce(0, +)) / Double(zones.count)

        // 计算基础EV（Zone V = 基准）
        let baseEV = referenceEV + (avgZone - 5.0)

        // 应用快门偏移后的EV
        // 快门提高(+offset) = 进光减少 = EV降低
        let adjustedEV = baseEV - shutterOffset

        // 计算调整后的快门速度
        let adjustedShutterSpeed = baseShutterSpeed / pow(2, shutterOffset)

        // 计算光圈和最终快门
        let aperture: Double
        let finalShutterSpeed: Double

        if let lockedAperture = lockedAperture {
            // 光圈锁定模式：使用锁定光圈，计算快门
            aperture = lockedAperture

            // 根据EV差重新计算快门
            let evDiffFromBase = log2(pow(lockedAperture / baseAperture, 2))
            let targetShutter = baseShutterSpeed * pow(2, evDiffFromBase - (adjustedEV - referenceEV))

            // 限制快门速度在合理范围内
            finalShutterSpeed = min(max(targetShutter, 1/8000), 30)
        } else {
            // 自动模式：根据EV计算光圈
            let evDiff = adjustedEV - referenceEV

            // 考虑ISO影响的EV差
            let isoAdjustment = log2(Double(iso) / 100.0)
            let adjustedEVDiff = evDiff - isoAdjustment

            // 计算光圈（基于基准光圈f/8）
            let stops = adjustedEVDiff / 2.0
            aperture = calculateAperture(baseAperture: baseAperture, stops: stops)

            // 快门使用调整后的值
            finalShutterSpeed = adjustedShutterSpeed
        }

        return (aperture, finalShutterSpeed, iso, adjustedEV)
    }

    /// 获取最接近的标准快门档位
    static func nearestShutterSpeed(_ speed: Double) -> (fraction: String, decimal: Double) {
        guard speed > 0 else { return ("1/125", 1/125.0) }

        let shutterSpeedStops: [(fraction: String, decimal: Double)] = [
            ("1/8000", 1/8000), ("1/4000", 1/4000), ("1/2000", 1/2000), ("1/1000", 1/1000),
            ("1/500", 1/500), ("1/250", 1/250), ("1/125", 1/125), ("1/60", 1/60),
            ("1/30", 1/30), ("1/15", 1/15), ("1/8", 1/8), ("1/4", 1/4),
            ("1/2", 1/2), ("1s", 1.0), ("2s", 2.0), ("4s", 4.0), ("8s", 8.0)
        ]

        var closest = shutterSpeedStops[6] // 默认1/125
        var minDiff = abs(speed - closest.decimal)

        for stop in shutterSpeedStops {
            let diff = abs(speed - stop.decimal)
            if diff < minDiff {
                minDiff = diff
                closest = stop
            }
        }

        return closest
    }
}
