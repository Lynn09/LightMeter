import Foundation
import SwiftUI
import Combine

// MARK: - Exposure Control Mode

enum ExposureControlMode: String {
    case automatic
    case aperturePriority
    case shutterPriority

    var displayName: String {
        switch self {
        case .automatic:
            return "自动联动"
        case .aperturePriority:
            return "光圈优先"
        case .shutterPriority:
            return "快门优先"
        }
    }
}

// MARK: - MeteringViewModel

/// 测光视图模型，管理应用状态和业务逻辑
@MainActor
class MeteringViewModel: ObservableObject {

    // MARK: - 胶片预设

    @Published var selectedFilm: FilmPreset = .provia100F

    // MARK: - 测光点

    @Published var meteringPoints: [MeteringPoint] = []
    @Published var selectedPointId: UUID?
    @Published var isPointEditMenuPresented: Bool = false

    /// 最大测光点数量
    let maxMeteringPoints = 5

    // MARK: - 曝光参数

    @Published var currentExposure: ExposureResult = ExposureResult.default

    // MARK: - 手动曝光调整

    /// 手动曝光补偿值（EV/Zone），范围 -5 到 +5
    @Published var manualExposureOffset: Double = 0

    /// 是否启用手动曝光模式
    @Published var isManualExposure: Bool = false

    /// 拖动宽容度框时的临时补偿值
    @Published var dragOffset: Double = 0

    // MARK: - 光圈锁定

    /// 锁定的光圈值
    @Published var lockedAperture: Double? = nil

    /// 是否显示光圈选择器
    @Published var isApertureSelectorPresented: Bool = false

    /// 锁定的快门速度
    @Published var lockedShutterSpeed: Double? = nil

    /// 是否显示快门选择器
    @Published var isShutterSelectorPresented: Bool = false

    /// 当前曝光控制模式
    @Published var exposureControlMode: ExposureControlMode = .automatic

    /// 是否已锁定光圈
    var isApertureLocked: Bool {
        lockedAperture != nil
    }

    /// 是否已锁定快门
    var isShutterLocked: Bool {
        lockedShutterSpeed != nil
    }

    // MARK: - 计算属性

    /// 是否可以选择测光点（未满5个）
    var canAddMeteringPoint: Bool {
        meteringPoints.count < maxMeteringPoints
    }

    /// 当前选中的测光点
    var selectedPoint: MeteringPoint? {
        guard let id = selectedPointId else { return nil }
        return meteringPoints.first { $0.id == id }
    }

    // MARK: - 初始化

    init() {
        // 初始化时计算一次曝光参数
        updateExposureParameters()
    }

    // MARK: - 手动曝光调整

    /// 获取当前有效的曝光调整量
    var effectiveExposureAdjustment: Double {
        isManualExposure ? manualExposureOffset : currentExposure.adjustment
    }

    /// 设置手动曝光补偿
    /// - Parameter offset: 补偿值，范围 -5 到 +5
    func setManualExposureOffset(_ offset: Double) {
        let clampedOffset = max(-5.0, min(5.0, offset))
        manualExposureOffset = clampedOffset
        isManualExposure = true
        updateExposureParameters()
    }

    /// 更新拖动偏移（用于拖动宽容度框时的实时预览）
    /// - Parameter offset: 拖动偏移量（Zone单位）
    func updateDragOffset(_ offset: Double) {
        dragOffset = offset
    }

    /// 结束拖动并应用最终偏移
    /// - Parameter finalOffset: 最终偏移量（Zone单位）
    func endDragWithOffset(_ finalOffset: Double) {
        let newOffset = manualExposureOffset + finalOffset
        setManualExposureOffset(newOffset)
        dragOffset = 0
    }

    /// 重置为自动曝光模式
    func resetToAutoExposure() {
        isManualExposure = false
        manualExposureOffset = 0
        dragOffset = 0
        updateExposureParameters()
    }

    // MARK: - 光圈锁定

    /// 锁定光圈值
    /// - Parameter aperture: 要锁定的光圈值
    func lockAperture(_ aperture: Double) {
        lockedAperture = aperture
        lockedShutterSpeed = nil
        exposureControlMode = .aperturePriority
        isManualExposure = false
        shutterSpeedOffset = 0
        dragShutterOffset = 0
        isManualShutterAdjusted = false

        // 为所有已存在的测光点重新计算独立的曝光参数
        refreshMeteringPointExposureParams()

        updateExposureParameters()
    }

    /// 解锁光圈
    func unlockAperture() {
        lockedAperture = nil
        if lockedShutterSpeed == nil {
            exposureControlMode = .automatic
        }

        // 清除所有测光点的独立曝光参数
        refreshMeteringPointExposureParams()

        updateExposureParameters()
    }

    /// 切换光圈选择器显示状态
    func toggleApertureSelector() {
        isApertureSelectorPresented.toggle()
    }

    /// 关闭光圈选择器
    func closeApertureSelector() {
        isApertureSelectorPresented = false
    }

    // MARK: - 快门锁定

    /// 锁定快门速度
    /// - Parameter shutterSpeed: 要锁定的快门速度
    func lockShutterSpeed(_ shutterSpeed: Double) {
        let snappedShutterSpeed = ExposureCalculator.nearestStandardShutter(shutterSpeed)
        lockedShutterSpeed = snappedShutterSpeed
        lockedAperture = nil
        exposureControlMode = .shutterPriority
        isManualExposure = false
        shutterSpeedOffset = log2(baseShutterSpeed / snappedShutterSpeed)
        dragShutterOffset = 0
        isManualShutterAdjusted = true

        refreshMeteringPointExposureParams()

        updateExposureParameters()
    }

    /// 解锁快门速度
    func unlockShutterSpeed() {
        lockedShutterSpeed = nil
        if lockedAperture == nil {
            exposureControlMode = .automatic
        }
        shutterSpeedOffset = 0
        dragShutterOffset = 0
        isManualShutterAdjusted = false

        refreshMeteringPointExposureParams()

        updateExposureParameters()
    }

    /// 切换快门选择器显示状态
    func toggleShutterSelector() {
        isShutterSelectorPresented.toggle()
    }

    /// 关闭快门选择器
    func closeShutterSelector() {
        isShutterSelectorPresented = false
    }

    // MARK: - 快门控制

    /// 当前快门速度偏移量（Zone单位）
    /// 正数 = 提高快门（画面变暗，测光点向低Zone移动）
    /// 负数 = 降低快门（画面变亮，测光点向高Zone移动）
    @Published var shutterSpeedOffset: Double = 0

    /// 拖动过程中的临时偏移
    @Published var dragShutterOffset: Double = 0

    /// 基准快门速度
    @Published var baseShutterSpeed: Double = 1/125.0

    /// 是否手动调整过快门
    @Published var isManualShutterAdjusted: Bool = false

    /// 当前实际快门速度（计算属性）
    var effectiveShutterSpeed: Double {
        baseShutterSpeed / pow(2, shutterSpeedOffset)
    }

    /// 获取测光点的显示Zone（应用快门偏移后）
    func displayZone(for point: MeteringPoint) -> Double {
        Double(point.zone) - shutterSpeedOffset
    }

    /// 将快门速度吸附到最近的标准档位
    private func nearestStandardShutterSpeed(_ speed: Double) -> Double {
        guard speed > 0 else { return 1.0/125.0 }

        let standardSpeeds: [Double] = [
            1.0/8000, 1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
            1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0
        ]

        var closest = standardSpeeds[6] // 默认1/125
        var minDiff = abs(speed - closest)

        for stop in standardSpeeds {
            let diff = abs(speed - stop)
            if diff < minDiff {
                minDiff = diff
                closest = stop
            }
        }

        return closest
    }

    /// 更新拖动偏移（用于拖动宽容度框时的实时预览）
    /// - Parameter offset: 拖动偏移量（Zone单位）
    func updateShutterDragOffset(_ offset: Double) {
        dragShutterOffset = offset
        // 拖动过程中实时更新曝光参数，使底部快门数值实时变化
        recalculateExposureWithShutterOffset()
    }

    /// 结束拖动并应用最终偏移，快门速度吸附到标准档位
    /// - Parameter finalOffset: 最终偏移量（Zone单位）
    func endShutterDragWithOffset(_ finalOffset: Double) {
        let totalOffset = shutterSpeedOffset + finalOffset
        // 限制范围 ±5 Zone
        let clampedOffset = max(-5.0, min(5.0, totalOffset))

        // 计算当前快门速度并吸附到标准档位
        let rawShutterSpeed = baseShutterSpeed / pow(2.0, clampedOffset)
        let snappedShutterSpeed = nearestStandardShutterSpeed(rawShutterSpeed)

        // 根据吸附后的快门速度反推实际的Zone偏移量
        // newShutter = baseShutter / 2^newOffset
        // 2^newOffset = baseShutter / newShutter
        // newOffset = log2(baseShutter / newShutter)
        let snappedOffset = log2(baseShutterSpeed / snappedShutterSpeed)

        // 应用吸附后的偏移量
        shutterSpeedOffset = snappedOffset
        if exposureControlMode == .shutterPriority {
            lockedShutterSpeed = snappedShutterSpeed
        }
        dragShutterOffset = 0
        isManualShutterAdjusted = true

        // 应用新的曝光参数
        recalculateExposureWithShutterOffset()
    }

    /// 重置快门偏移
    func resetShutterOffset() {
        shutterSpeedOffset = 0
        dragShutterOffset = 0
        isManualShutterAdjusted = false
        updateExposureParameters()
    }

    /// 根据快门偏移重新计算曝光参数，快门速度始终为标准档位
    private func recalculateExposureWithShutterOffset() {
        let zones = meteringPoints.map { $0.zone }

        // 如果没有测光点，使用默认参数
        guard !zones.isEmpty else {
            currentExposure = calculateDefaultExposureWithShutterOffset()
            return
        }

        // 计算平均Zone和基础EV
        let avgZone = Double(zones.reduce(0, +)) / Double(zones.count)
        let baseEV = ExposureCalculator.referenceEV + (avgZone - 5.0)

        // 计算有效的总偏移量（已应用的偏移 + 拖动中的临时偏移）
        let effectiveOffset = shutterSpeedOffset + dragShutterOffset

        // 应用快门偏移后的EV
        // 快门提高(+offset) = 进光减少 = EV降低
        let adjustedEV = baseEV - effectiveOffset

        // 计算光圈和快门
        let aperture: Double
        let finalShutterSpeed: Double

        if let lockedAperture = lockedAperture {
            // 光圈锁定模式
            aperture = lockedAperture

            // 根据锁定的光圈和EV差重新计算快门
            let evDiffFromBase = log2(pow(lockedAperture / ExposureCalculator.baseAperture, 2))
            let targetShutter = baseShutterSpeed * pow(2, evDiffFromBase - (adjustedEV - ExposureCalculator.referenceEV))

            // 吸附到标准档位
            finalShutterSpeed = nearestStandardShutterSpeed(targetShutter)
        } else {
            // 自动模式：使用吸附后的快门速度，根据EV计算光圈
            // 快门速度基于偏移量计算并吸附到标准档位
            // 使用有效的总偏移量（已应用 + 拖动中）
            let rawShutterSpeed = baseShutterSpeed / pow(2, effectiveOffset)
            finalShutterSpeed = nearestStandardShutterSpeed(rawShutterSpeed)

            // 根据快门和EV计算光圈
            // EV = log2(aperture^2 / shutter) + log2(ISO/100) + 10
            // 简化：aperture = sqrt(2^(EV - log2(ISO/100) - 10 + log2(shutter)))
            let isoAdjustment = log2(Double(selectedFilm.iso) / 100.0)
            let evDiff = adjustedEV - ExposureCalculator.referenceEV
            let adjustedEVDiff = evDiff - isoAdjustment
            let stops = adjustedEVDiff / 2.0
            let rawAperture = ExposureCalculator.calculateAperture(
                baseAperture: ExposureCalculator.baseAperture,
                stops: stops
            )
            aperture = ExposureCalculator.nearestStandardAperture(rawAperture)
        }

        currentExposure = ExposureResult(
            aperture: aperture,
            shutterSpeed: finalShutterSpeed,
            iso: selectedFilm.iso,
            ev: adjustedEV,
            adjustment: 0,
            compensation: 0
        )
    }

    /// 计算默认曝光（无测光点时）
    private func calculateDefaultExposureWithShutterOffset() -> ExposureResult {
        let adjustedShutter = baseShutterSpeed / pow(2, shutterSpeedOffset)

        return ExposureResult(
            aperture: ExposureCalculator.baseAperture,
            shutterSpeed: adjustedShutter,
            iso: selectedFilm.iso,
            ev: ExposureCalculator.referenceEV,
            adjustment: 0,
            compensation: 0
        )
    }

    // MARK: - 胶片预设

    /// 选择胶片预设
    func selectFilm(_ film: FilmPreset) {
        selectedFilm = film
        // 切换胶片时重置为自动曝光
        resetToAutoExposure()
        refreshMeteringPointExposureParams()
    }

    // MARK: - 测光点管理

    /// 添加测光点
    func addMeteringPoint(x: Double, y: Double, brightness: Double = 0.5) {
        guard canAddMeteringPoint else { return }

        let color = MeteringPoint.nextColor(for: meteringPoints.count)
        let ev = ExposureCalculator.brightnessToEV(brightness: brightness)
        let zone = ExposureCalculator.evToZone(ev: ev)

        // 始终为该点计算独立的曝光参数
        let exposureParams = calculateExposureParamsForPoint(
            zone: zone,
            ev: ev
        )

        let point = MeteringPoint(
            x: x,
            y: y,
            color: color,
            zone: zone,
            ev: ev,
            exposureParams: exposureParams
        )

        meteringPoints.append(point)
        selectedPointId = point.id
        updateExposureParameters()
    }

    /// 为单个测光点计算曝光参数
    /// - Parameters:
    ///   - zone: 测光点的 Zone 值
    ///   - ev: 测光点的 EV 值
    /// - Returns: 该点的曝光参数
    private func calculateExposureParamsForPoint(zone: Int, ev: Double) -> ExposureParams {
        // 如果已锁定光圈，使用锁定光圈计算快门
        if let lockedApertureValue = lockedAperture {
            let result = ExposureCalculator.calculateCoupledExposure(
                ev: ev,
                iso: selectedFilm.iso,
                lockedAperture: lockedApertureValue,
                lockedShutterSpeed: nil
            )
            return ExposureParams(
                aperture: result.aperture,
                shutterSpeed: result.shutterSpeed,
                iso: result.iso,
                ev: result.ev,
                zone: zone
            )
        } else if let lockedShutterSpeedValue = lockedShutterSpeed {
            let result = ExposureCalculator.calculateCoupledExposure(
                ev: ev,
                iso: selectedFilm.iso,
                lockedAperture: nil,
                lockedShutterSpeed: lockedShutterSpeedValue
            )
            return ExposureParams(
                aperture: result.aperture,
                shutterSpeed: result.shutterSpeed,
                iso: result.iso,
                ev: result.ev,
                zone: zone
            )
        } else {
            // 未锁定光圈时，根据该点的 EV 计算推荐曝光参数
            // 使用基准：f/8, 1/125s, ISO 100, EV 12.5
            let evDiff = ev - ExposureCalculator.referenceEV
            let aperture = ExposureCalculator.calculateAperture(
                baseAperture: ExposureCalculator.baseAperture,
                stops: evDiff
            )
            let shutterSpeed = ExposureCalculator.calculateShutterSpeed(
                baseShutterSpeed: ExposureCalculator.baseShutterSpeed,
                stops: evDiff
            )
            let isoAdjustment = log2(Double(selectedFilm.iso) / 100.0)
            let adjustedShutterSpeed = shutterSpeed * pow(2.0, -isoAdjustment)

            return ExposureParams(
                aperture: aperture,
                shutterSpeed: adjustedShutterSpeed,
                iso: selectedFilm.iso,
                ev: ev,
                zone: zone
            )
        }
    }

    /// 根据当前联动模式刷新所有测光点的独立曝光参数
    private func refreshMeteringPointExposureParams() {
        for index in meteringPoints.indices {
            if lockedAperture == nil && lockedShutterSpeed == nil {
                meteringPoints[index].exposureParams = nil
            } else {
                let point = meteringPoints[index]
                meteringPoints[index].exposureParams = calculateExposureParamsForPoint(
                    zone: point.zone,
                    ev: point.ev
                )
            }
        }
    }

    /// 删除测光点
    func deleteMeteringPoint(id: UUID) {
        meteringPoints.removeAll { $0.id == id }
        if selectedPointId == id {
            selectedPointId = nil
            isPointEditMenuPresented = false
        }
        updateExposureParameters()
    }

    /// 重新测光（更新 EV 和 Zone）
    func remeterPoint(id: UUID, brightness: Double) {
        guard let index = meteringPoints.firstIndex(where: { $0.id == id }) else { return }

        let ev = ExposureCalculator.brightnessToEV(brightness: brightness)
        let zone = ExposureCalculator.evToZone(ev: ev)

        meteringPoints[index].ev = ev
        meteringPoints[index].zone = zone

        // 始终更新测光点的独立曝光参数
        let exposureParams = calculateExposureParamsForPoint(
            zone: zone,
            ev: ev
        )
        meteringPoints[index].exposureParams = exposureParams

        updateExposureParameters()
    }

    /// 选择测光点（显示编辑菜单）
    func selectPoint(id: UUID) {
        selectedPointId = id
        isPointEditMenuPresented = true
    }

    /// 选择测光点用于底部抽屉，不打开旧弹窗
    func selectPointForDrawer(id: UUID) {
        selectedPointId = id
        isPointEditMenuPresented = false
    }

    /// 关闭编辑菜单
    func closePointEditMenu() {
        isPointEditMenuPresented = false
        // 不取消选择，保持选中状态以便查看
    }

    // MARK: - 曝光参数计算

    /// 更新曝光参数
    private func updateExposureParameters() {
        let zones = meteringPoints.map { $0.zone }

        // 如果没有测光点，使用默认参数
        guard !zones.isEmpty else {
            currentExposure = ExposureResult.default
            return
        }

        if lockedAperture != nil || lockedShutterSpeed != nil {
            let averageZone = Double(zones.reduce(0, +)) / Double(zones.count)
            let averageEV = ExposureCalculator.referenceEV + (averageZone - 5.0)
            let result = ExposureCalculator.calculateCoupledExposure(
                ev: averageEV,
                iso: selectedFilm.iso,
                lockedAperture: lockedAperture,
                lockedShutterSpeed: lockedShutterSpeed
            )

            currentExposure = ExposureResult(
                aperture: result.aperture,
                shutterSpeed: result.shutterSpeed,
                iso: result.iso,
                ev: result.ev,
                adjustment: 0,
                compensation: 0
            )
        } else {
            // 正常模式：计算曝光参数，传入手动补偿值（如果是手动模式）
            let manualCompensation = isManualExposure ? manualExposureOffset : nil

            let result = ExposureCalculator.calculateExposure(
                zones: zones,
                minZone: selectedFilm.minZone,
                maxZone: selectedFilm.maxZone,
                iso: selectedFilm.iso,
                manualCompensation: manualCompensation
            )

            currentExposure = ExposureResult(
                aperture: result.aperture,
                shutterSpeed: result.shutterSpeed,
                iso: result.iso,
                ev: result.ev,
                adjustment: result.adjustment,
                compensation: isManualExposure ? manualExposureOffset : 0
            )
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
        ev: 12.5,
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
