import Foundation
import SwiftUI

// MARK: - FilmPreset

/// 胶片预设模型，用于定义不同反转片的宽容度特性
struct FilmPreset: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let color: String
    let zoneRange: String
    let description: String
    let minZone: Int
    let maxZone: Int
    let iso: Int
    let packagingImageName: String

    init(
        id: UUID = UUID(),
        name: String,
        color: String,
        zoneRange: String,
        description: String,
        minZone: Int,
        maxZone: Int,
        iso: Int,
        packagingImageName: String
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.zoneRange = zoneRange
        self.description = description
        self.minZone = minZone
        self.maxZone = maxZone
        self.iso = iso
        self.packagingImageName = packagingImageName
    }

    // MARK: - Swift Color

    /// 将颜色字符串转换为 SwiftUI Color
    var swiftColor: Color {
        Color(hex: color) ?? .blue
    }

    var localizedDescription: String {
        NSLocalizedString(description, comment: "")
    }

    // MARK: - Equatable

    static func == (lhs: FilmPreset, rhs: FilmPreset) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 预设胶片定义

extension FilmPreset {

    /// 所有可用的胶片预设
    static let allPresets: [FilmPreset] = [
        .velvia50,
        .velvia100,
        .provia100F,
        .ektachrome,
        .portra160,
        .portra400,
        .gold200,
        .ultramax400
    ]

    /// Velvia 50 反转片
    /// 高饱和度、色彩鲜艳，宽容度较窄
    static let velvia50 = FilmPreset(
        name: "Velvia 50",
        color: "#007AFF",
        zoneRange: "Zone IV-VIII",
        description: "film.velvia50.description",
        minZone: 4,
        maxZone: 8,
        iso: 50,
        packagingImageName: "film_pack_velvia_50"
    )

    /// Velvia 100 反转片
    /// 高饱和度、反差较高，宽容度较窄
    static let velvia100 = FilmPreset(
        name: "Velvia 100",
        color: "#0A84FF",
        zoneRange: "Zone IV-VIII",
        description: "film.velvia100.description",
        minZone: 4,
        maxZone: 8,
        iso: 100,
        packagingImageName: "film_pack_velvia_100"
    )

    /// Provia 100F 反转片
    /// 中性色彩、平衡性好，宽容度中等
    static let provia100F = FilmPreset(
        name: "Provia 100F",
        color: "#5856D6",
        zoneRange: "Zone III-VIII",
        description: "film.provia100f.description",
        minZone: 3,
        maxZone: 8,
        iso: 100,
        packagingImageName: "film_pack_provia_100f"
    )

    /// Ektachrome 反转片
    /// 暖色调、适合人像，宽容度较窄
    static let ektachrome = FilmPreset(
        name: "Ektachrome",
        color: "#FF9500",
        zoneRange: "Zone III-VII",
        description: "film.ektachrome.description",
        minZone: 3,
        maxZone: 7,
        iso: 100,
        packagingImageName: "film_pack_ektachrome"
    )

    /// Portra 160 彩色负片
    /// 肤色表现稳定，高光宽容度较好
    static let portra160 = FilmPreset(
        name: "Portra 160",
        color: "#D6A15D",
        zoneRange: "Zone II-IX",
        description: "film.portra160.description",
        minZone: 2,
        maxZone: 9,
        iso: 160,
        packagingImageName: "film_pack_portra_160"
    )

    /// Portra 400 彩色负片
    /// 通用人像负片，高光宽容度较好
    static let portra400 = FilmPreset(
        name: "Portra 400",
        color: "#C98942",
        zoneRange: "Zone II-IX",
        description: "film.portra400.description",
        minZone: 2,
        maxZone: 9,
        iso: 400,
        packagingImageName: "film_pack_portra_400"
    )

    /// Gold 200 彩色负片
    /// 日常彩色负片，宽容度中等偏宽
    static let gold200 = FilmPreset(
        name: "Gold 200",
        color: "#F5C542",
        zoneRange: "Zone II-VIII",
        description: "film.gold200.description",
        minZone: 2,
        maxZone: 8,
        iso: 200,
        packagingImageName: "film_pack_gold_200"
    )

    /// Ultramax 400 彩色负片
    /// 日常高感彩色负片，宽容度中等偏宽
    static let ultramax400 = FilmPreset(
        name: "Ultramax 400",
        color: "#E85D2A",
        zoneRange: "Zone II-VIII",
        description: "film.ultramax400.description",
        minZone: 2,
        maxZone: 8,
        iso: 400,
        packagingImageName: "film_pack_ultramax_400"
    )
}

// MARK: - Color Extension

extension Color {
    /// 从十六进制字符串创建颜色
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("Film Presets") {
    VStack(spacing: 16) {
        Text("胶片预设")
            .font(.title)
            .padding()

        ForEach(FilmPreset.allPresets) { preset in
            HStack {
                Circle()
                    .fill(preset.swiftColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading) {
                    Text(preset.name)
                        .font(.headline)
                    Text(preset.zoneRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("ISO \(preset.iso)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
