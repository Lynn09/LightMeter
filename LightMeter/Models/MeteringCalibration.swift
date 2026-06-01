import Foundation

enum CalibrationLevel: String, Codable, CaseIterable {
    case professional
    case standard
    case quick

    var trustRank: Int {
        switch self {
        case .professional:
            return 3
        case .standard:
            return 2
        case .quick:
            return 1
        }
    }

    var displayName: String {
        switch self {
        case .professional:
            return String(localized: "calibration.level.professional")
        case .standard:
            return String(localized: "calibration.level.standard")
        case .quick:
            return String(localized: "calibration.level.quick")
        }
    }
}

struct NativeLensInfo: Codable, Equatable, Identifiable {
    let key: String
    let name: String
    let deviceType: String

    var id: String { key }
}

struct CameraExposureSnapshot: Codable, Equatable {
    let aperture: Double
    let exposureDuration: Double
    let iso: Double
}

struct CalibrationSample: Codable, Equatable {
    let measuredEV: Double
    let referenceEV: Double
    let brightness: Double

    init(measuredEV: Double, referenceEV: Double, brightness: Double? = nil) {
        self.measuredEV = measuredEV
        self.referenceEV = referenceEV
        self.brightness = brightness ?? ExposureCalculator.brightness(fromEV: measuredEV)
    }

    var offset: Double {
        referenceEV - measuredEV
    }
}

struct LensCalibration: Codable, Equatable, Identifiable {
    let id: String
    let nativeLensKey: String
    let level: CalibrationLevel
    let evOffset: Double
    let referenceBrightness: Double
    let sampleCount: Int
    let createdAt: Date
    let deviceModel: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case id
        case nativeLensKey
        case level
        case evOffset
        case referenceBrightness
        case sampleCount
        case createdAt
        case deviceModel
        case appVersion
    }

    init(
        id: String = UUID().uuidString,
        nativeLensKey: String,
        level: CalibrationLevel,
        evOffset: Double,
        referenceBrightness: Double = ExposureCalculator.middleGrayReflectance,
        sampleCount: Int,
        createdAt: Date,
        deviceModel: String,
        appVersion: String
    ) {
        self.id = id
        self.nativeLensKey = nativeLensKey
        self.level = level
        self.evOffset = evOffset
        self.referenceBrightness = referenceBrightness
        self.sampleCount = sampleCount
        self.createdAt = createdAt
        self.deviceModel = deviceModel
        self.appVersion = appVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        nativeLensKey = try container.decode(String.self, forKey: .nativeLensKey)
        level = try container.decode(CalibrationLevel.self, forKey: .level)
        evOffset = try container.decode(Double.self, forKey: .evOffset)
        referenceBrightness = try container.decodeIfPresent(Double.self, forKey: .referenceBrightness)
            ?? ExposureCalculator.middleGrayReflectance
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deviceModel = try container.decode(String.self, forKey: .deviceModel)
        appVersion = try container.decode(String.self, forKey: .appVersion)
    }

    var statusLabel: String {
        "\(level.displayName) \(MeteringCalibrationMath.formatOffset(evOffset))"
    }

    static func best(from calibrations: [LensCalibration]) -> LensCalibration? {
        calibrations
            .filter { $0.evOffset.isFinite && MeteringCalibrationMath.isValidBrightness($0.referenceBrightness) }
            .max { lhs, rhs in
            if lhs.level.trustRank == rhs.level.trustRank {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.level.trustRank < rhs.level.trustRank
        }
    }
}

enum MeteringCalibrationMath {
    static func ev100(aperture: Double, exposureDuration: Double, iso: Double) -> Double {
        guard aperture > 0, exposureDuration > 0, iso > 0 else {
            return ExposureCalculator.referenceEV
        }

        return log2((aperture * aperture) / exposureDuration) - log2(iso / 100.0)
    }

    static func offset(referenceEV: Double, measuredEV: Double) -> Double {
        referenceEV - measuredEV
    }

    static func averageOffset(from samples: [CalibrationSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.map(\.offset).reduce(0, +)
        return total / Double(samples.count)
    }

    static func averageBrightness(from samples: [CalibrationSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.map(\.brightness).reduce(0, +)
        return normalizedBrightness(total / Double(samples.count))
    }

    static func normalizedBrightness(_ brightness: Double) -> Double {
        guard brightness.isFinite else { return ExposureCalculator.middleGrayReflectance }
        return max(0.001, min(1.0, brightness))
    }

    static func isValidBrightness(_ brightness: Double) -> Bool {
        brightness.isFinite && brightness > 0 && brightness <= 1
    }

    static func sceneEV(
        pointBrightness: Double,
        cameraReferenceEV: Double,
        calibration: LensCalibration?
    ) -> Double {
        let pointBrightness = normalizedBrightness(pointBrightness)
        let referenceBrightness = normalizedBrightness(
            calibration?.referenceBrightness ?? ExposureCalculator.middleGrayReflectance
        )
        let correction = calibration?.evOffset ?? 0

        guard cameraReferenceEV.isFinite, correction.isFinite else {
            return ExposureCalculator.brightnessToEV(brightness: pointBrightness) + correction
        }

        return cameraReferenceEV + log2(pointBrightness / referenceBrightness) + correction
    }

    static func formatOffset(_ offset: Double) -> String {
        let sign = offset >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", offset)) EV"
    }
}

final class MeteringCalibrationStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "metering.nativeLensCalibrations.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func calibrations() -> [LensCalibration] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([LensCalibration].self, from: data)) ?? []
    }

    func activeCalibration(for nativeLensKey: String?) -> LensCalibration? {
        guard let nativeLensKey else { return nil }
        return LensCalibration.best(from: calibrations().filter { $0.nativeLensKey == nativeLensKey })
    }

    func save(_ calibration: LensCalibration) {
        var values = calibrations().filter {
            !($0.nativeLensKey == calibration.nativeLensKey && $0.level == calibration.level)
        }
        values.append(calibration)
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func reset(nativeLensKey: String) {
        let values = calibrations().filter { $0.nativeLensKey != nativeLensKey }
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func resetAll() {
        defaults.removeObject(forKey: storageKey)
    }
}
