import Foundation
import SwiftUI
import Combine

enum ViewfinderMode { case spot, metering, rangefinder }

@MainActor
class MeteringViewModel: ObservableObject {
    private var inactivePoints: [MeteringPoint] = []
    private var inactiveSelection: UUID?
    private(set) var activeMethod: ViewfinderMode = .spot
    @Published var mode: ViewfinderMode = .spot {
        didSet {
            guard mode != .rangefinder, activeMethod != mode else { return }
            activeMethod = mode
            let previousPoints = meteringPoints
            meteringPoints = inactivePoints
            inactivePoints = previousPoints
            let previousSelection = selectedPointId
            selectedPointId = inactiveSelection
            inactiveSelection = previousSelection
            updateExposureParameters()
        }
    }
    @Published var selectedFilm: FilmPreset = .provia100F
    @Published var meteringPoints: [MeteringPoint] = []
    @Published var selectedPointId: UUID?
    @Published var currentExposure = ExposureResult.default
    @Published var manualExposureOffset = 0.0
    @Published var isManualExposure = false
    @Published var dragOffset = 0.0
    @Published var lockedAperture: Double?
    @Published var shutterSpeedOffset = 0.0
    @Published var dragShutterOffset = 0.0
    @Published var baseShutterSpeed = ExposureCalculator.baseShutterSpeed
    @Published var isManualShutterAdjusted = false
    let maxMeteringPoints = 5

    var canAddMeteringPoint: Bool { mode == .spot || (mode == .metering && meteringPoints.count < maxMeteringPoints) }
    var selectedPoint: MeteringPoint? { meteringPoints.first { $0.id == selectedPointId } }
    var isApertureLocked: Bool { lockedAperture != nil }
    var effectiveExposureAdjustment: Double { currentExposure.adjustment }
    var effectiveShutterSpeed: Double { baseShutterSpeed / pow(2, shutterSpeedOffset + dragShutterOffset) }
    func displayZone(for point: MeteringPoint) -> Double { point.zonePosition ?? Double(point.zone) }

    func setManualExposureOffset(_ offset: Double) {
        guard offset.isFinite else { return }
        manualExposureOffset = min(5, max(-5, offset))
        isManualExposure = true
        updateExposureParameters()
    }
    func updateDragOffset(_ offset: Double) { dragOffset = offset }
    func endDragWithOffset(_ offset: Double) { setManualExposureOffset(manualExposureOffset + offset); dragOffset = 0 }
    func resetToAutoExposure() {
        isManualExposure = false; manualExposureOffset = 0; dragOffset = 0
        updateExposureParameters()
    }
    func lockAperture(_ aperture: Double) {
        guard aperture > 0, aperture.isFinite else { return }
        lockedAperture = aperture
        updateExposureParameters()
    }
    func unlockAperture() { lockedAperture = nil; updateExposureParameters() }
    func updateShutterDragOffset(_ offset: Double) {
        guard offset.isFinite else { return }
        dragShutterOffset = min(5, max(-5, offset + shutterSpeedOffset)) - shutterSpeedOffset
        updateExposureParameters()
    }
    func endShutterDragWithOffset(_ offset: Double) {
        guard offset.isFinite else { return }
        let total = min(5, max(-5, shutterSpeedOffset + offset))
        let snapped = ExposureCalculator.nearestStandardShutter(baseShutterSpeed / pow(2, total))
        shutterSpeedOffset = min(5, max(-5, log2(baseShutterSpeed / snapped)))
        dragShutterOffset = 0
        isManualShutterAdjusted = true
        updateExposureParameters()
    }
    func resetShutterOffset() {
        shutterSpeedOffset = 0; dragShutterOffset = 0; isManualShutterAdjusted = false
        updateExposureParameters()
    }
    func selectFilm(_ film: FilmPreset) {
        selectedFilm = film
        shutterSpeedOffset = 0; dragShutterOffset = 0; isManualShutterAdjusted = false
        resetToAutoExposure()
    }
    func addMeteringPoint(x: Double, y: Double, ev100: Double, rawEV100: Double? = nil, cameraID: String? = nil) {
        guard canAddMeteringPoint, ev100.isFinite else { return }
        if mode == .spot { meteringPoints.removeAll() }
        var point = MeteringPoint(x: x, y: y, color: MeteringPoint.nextColor(for: meteringPoints.count), ev: ev100)
        point.rawEV100 = rawEV100 ?? ev100
        point.cameraID = cameraID
        meteringPoints.append(point)
        updateExposureParameters()
    }
    func remeterPoint(id: UUID, reading: CameraMeteringReading) {
        guard let index = meteringPoints.firstIndex(where: { $0.id == id }), reading.ev100.isFinite else { return }
        meteringPoints[index].ev = reading.ev100
        meteringPoints[index].rawEV100 = reading.rawEV100
        meteringPoints[index].cameraID = reading.cameraID
        updateExposureParameters()
    }
    func applyCalibration(cameraID: String, offset: Double) {
        func apply(to points: inout [MeteringPoint]) {
            for index in points.indices where points[index].cameraID == cameraID {
                if let raw = points[index].rawEV100 { points[index].ev = raw + offset }
            }
        }
        apply(to: &meteringPoints)
        apply(to: &inactivePoints)
        updateExposureParameters()
    }
    func deleteMeteringPoint(id: UUID) {
        meteringPoints.removeAll { $0.id == id }
        if selectedPointId == id { selectedPointId = nil }
        updateExposureParameters()
    }
    func selectPoint(id: UUID) { selectedPointId = selectedPointId == id ? nil : id }

    private func updateExposureParameters() {
        guard !meteringPoints.isEmpty else {
            currentExposure = ExposureResult(aperture: lockedAperture ?? 8, shutterSpeed: .nan,
                                             iso: selectedFilm.iso, ev: .nan, adjustment: 0, compensation: 0)
            return
        }
        let evs = meteringPoints.map(\.ev)
        let meanEV = evs.reduce(0, +) / Double(evs.count)
        // Zone placement is relative to this scene; absolute EV is never clipped to Zone 0...X.
        let zones = evs.map { 5 + $0 - meanEV }
        let autoPlacement = lockedAperture == nil ? ExposureCalculator.optimalPlacement(
            zones: zones, minZone: selectedFilm.minZone, maxZone: selectedFilm.maxZone) : 0
        let placement = isManualExposure ? manualExposureOffset : autoPlacement
        let compensation = placement - shutterSpeedOffset - dragShutterOffset
        let base = ExposureCalculator.recommend(ev100: meanEV, iso: selectedFilm.iso,
                                               lockedAperture: lockedAperture, compensation: placement)
        baseShutterSpeed = base.shutterSpeed
        let result = ExposureCalculator.recommend(ev100: meanEV, iso: selectedFilm.iso,
                                                 lockedAperture: lockedAperture, compensation: compensation)
        currentExposure = ExposureResult(aperture: result.aperture, shutterSpeed: result.shutterSpeed,
                                         iso: selectedFilm.iso, ev: meanEV, adjustment: compensation,
                                         compensation: isManualExposure ? manualExposureOffset : 0)
        let settingsEV100 = meanEV - compensation
        for index in meteringPoints.indices {
            let ev = meteringPoints[index].ev
            let zone = ExposureCalculator.evToZone(ev: ev, referenceEV: settingsEV100)
            meteringPoints[index].zone = zone
            meteringPoints[index].zonePosition = 5 + ev - settingsEV100
            let individual = ExposureCalculator.recommend(ev100: ev, iso: selectedFilm.iso,
                                                         lockedAperture: lockedAperture, compensation: compensation)
            meteringPoints[index].exposureParams = ExposureParams(aperture: individual.aperture,
                shutterSpeed: individual.shutterSpeed, iso: selectedFilm.iso, ev: ev, zone: zone)
        }
    }
}

// MARK: - ExposureResult

/// 曝光计算结果
struct ExposureResult: Equatable {
    let aperture: Double
    let shutterSpeed: Double
    let iso: Int
    let ev: Double
    let adjustment: Double
    let compensation: Double  // 手动补偿值（用于显示）

    /// 默认曝光结果
    static let `default` = ExposureResult(
        aperture: ExposureCalculator.baseAperture,
        shutterSpeed: ExposureCalculator.baseShutterSpeed,
        iso: 100,
        ev: .nan,
        adjustment: 0,
        compensation: 0
    )

    // MARK: - 格式化输出

    var formattedAperture: String {
        ExposureCalculator.formatAperture(aperture)
    }

    var formattedShutterSpeed: String {
        ExposureCalculator.formatShutterSpeed(shutterSpeed)
    }

    var formattedISO: String {
        ExposureCalculator.formatISO(iso)
    }

    var formattedEV: String {
        ExposureCalculator.formatEV(ev)
    }

    var formattedAdjustment: String {
        if adjustment > 0 {
            return String(format: "+%.1f", adjustment)
        } else {
            return String(format: "%.1f", adjustment)
        }
    }
}
