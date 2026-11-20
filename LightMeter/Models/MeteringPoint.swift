import Foundation
import SwiftUI

// MARK: - ExposureParams

/// 曝光参数结构体，存储单个测光点的曝光计算结果
/// 用于光圈锁定模式下，每个测光点显示自己独立的曝光参数
struct ExposureParams {
    let aperture: Double       // 光圈值（如 8.0 表示 f/8）
    let shutterSpeed: Double   // 快门速度（秒，如 0.008 表示 1/125s）
    let iso: Int               // ISO 值
    let ev: Double             // 该点的 EV 值
    let zone: Int              // 该点的 Zone 值

    // 格式化显示方法
    var formattedAperture: String {
        ExposureCalculator.formatAperture(aperture)
    }

    var formattedShutterSpeed: String {
        ExposureCalculator.formatShutterSpeed(shutterSpeed)
    }

    var formattedISO: String {
        "ISO \(iso)"
    }
}

// MARK: - MeteringPoint

/// 测光点数据模型，用于存储单个测光点的位置和测光结果
struct MeteringPoint: Identifiable, Equatable, Hashable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var color: String
    var zone: Int
    var ev: Double
    var isSelected: Bool
    var zonePosition: Double?
    var rawEV100: Double?
    var cameraID: String?

    // 新增：存储该点独立的曝光参数（光圈锁定模式下）
    var exposureParams: ExposureParams?

    init(
        id: UUID = UUID(),
        x: CGFloat,
        y: CGFloat,
        color: String,
        zone: Int = 5,
        ev: Double = 12.5,
        isSelected: Bool = false,
        exposureParams: ExposureParams? = nil
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.color = color
        self.zone = zone
        self.ev = ev
        self.isSelected = isSelected
        self.exposureParams = exposureParams
    }

    // MARK: - Swift Color

    /// 将颜色字符串转换为 SwiftUI Color
    var swiftColor: Color {
        Color(hex: color) ?? .blue
    }

    // MARK: - Equatable

    static func == (lhs: MeteringPoint, rhs: MeteringPoint) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Zone Label

    /// Zone 的罗马数字标签
    var zoneLabel: String {
        ZoneSystem.labels[zone] ?? "V"
    }

    /// 测光点曝光值标识
    var exposureValueLabel: String {
        String(format: "EV100 %.1f", ev)
    }


}

// MARK: - Zone System Constants

/// 11区系统常量定义
enum ZoneSystem {

    /// Zone 对应的罗马数字标签 (0 = 0, I, II, III, IV, V, VI, VII, VIII, IX, X = 10)
    static let labels: [Int: String] = [
        0: "0",
        1: "I",
        2: "II",
        3: "III",
        4: "IV",
        5: "V",
        6: "VI",
        7: "VII",
        8: "VIII",
        9: "IX",
        10: "X"
    ]

    /// 标准参考 EV 值（Zone V 对应的 EV）
    static let referenceEV: Double = 12.5

    /// 标准校准常数 K = 12.5 (测光表标准)
    static let calibrationConstant: Double = 12.5

    /// 最小 Zone 值
    static let minZone: Int = 0

    /// 最大 Zone 值
    static let maxZone: Int = 10

    /// 中间调 Zone（18% 灰）
    static let midZone: Int = 5

    /// 将 Zone 转换为亮度比
    /// Zone 0 = 纯黑 (0.01%)
    /// Zone V = 18% 灰
    /// Zone X = 纯白 (100%)
    static func brightnessRatio(for zone: Int) -> Double {
        // 每增加一个 Zone，亮度增加一倍 (log2)
        // Zone V = 0.18 (18% 灰卡)
        let normalizedZone = Double(zone - midZone)
        return 0.18 * pow(2.0, normalizedZone)
    }

    /// 将亮度比转换为 Zone
    static func zone(for brightnessRatio: Double) -> Int {
        // 从亮度比反推 Zone
        // brightnessRatio = 0.18 * 2^(zone - 5)
        // zone = log2(brightnessRatio / 0.18) + 5
        guard brightnessRatio > 0 else { return minZone }
        let zoneValue = log2(brightnessRatio / 0.18) + Double(midZone)
        return max(minZone, min(maxZone, Int(round(zoneValue))))
    }
}

// MARK: - Color Constants

extension MeteringPoint {

    /// 测光点可用的预定义颜色数组
    static let colors: [String] = [
        "#34C759", // 绿色
        "#FF9500", // 橙色
        "#FF3B30", // 红色
        "#5856D6", // 紫色
        "#007AFF"  // 蓝色
    ]

    /// 获取下一个可用的颜色（循环使用）
    static func nextColor(for index: Int) -> String {
        colors[index % colors.count]
    }
}

// MARK: - Preview

#Preview("Metering Points") {
    VStack(spacing: 16) {
        Text("测光点示例")
            .font(.title)
            .padding()

        HStack(spacing: 20) {
            ForEach(Array(MeteringPoint.colors.enumerated()), id: \.offset) { index, color in
                let point = MeteringPoint(
                    x: 100,
                    y: 100,
                    color: color,
                    zone: 5 + index,
                    ev: 12.5 + Double(index),
                    isSelected: index == 0
                )

                VStack {
                    Circle()
                        .fill(point.swiftColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(point.isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )

                    Text("Zone \(point.zoneLabel)")
                        .font(.caption)

                    Text(String(format: "EV %.1f", point.ev))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }

        Divider()
            .padding(.vertical)

        Text("Zone 亮度比参考")
            .font(.headline)

        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<11) { zone in
                let ratio = ZoneSystem.brightnessRatio(for: zone)
                let label = ZoneSystem.labels[zone] ?? ""
                HStack {
                    Text("Zone \(label)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 50, alignment: .leading)
                    Text(String(format: "%.2f%%", ratio * 100))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
    .preferredColorScheme(.dark)
}
