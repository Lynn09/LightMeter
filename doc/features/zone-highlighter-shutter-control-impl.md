# Zone高亮框快门控制 - 开发实现文档

> 本文档详细描述Zone高亮框快门控制功能的代码实现方案

---

## 1. 模块架构

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Views)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ ZoneScaleView│  │ExposureInfo  │  │MainMetering  │       │
│  │ (拖动交互)   │  │  (快门显示)  │  │  (整合)      │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                 ViewModel Layer                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              MeteringViewModel                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │  │
│  │  │shutterSpeed │  │ dragOffset  │  │  baseShutter  │ │  │
│  │  │   Offset    │  │             │  │              │ │  │
│  │  └─────────────┘  └─────────────┘  └──────────────┘ │  │
│  │                                                      │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  updateShutterOffset()                       │  │  │
│  │  │  endShutterDragWithOffset()                  │  │  │
│  │  │  recalculateExposureWithShutterOffset()      │  │  │
│  │  │  resetShutterOffset()                        │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                 Calculator Layer                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         ExposureCalculator                            │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  calculateExposureWithShutterOffset()      │    │  │
│  │  │  - 输入: zones, shutterOffset, iso         │    │  │
│  │  │  - 输出: ExposureResult                    │    │  │
│  │  │  - 计算快门速度：baseShutter / 2^offset    │    │  │
│  │  │  - 计算测光点显示Zone：zone - offset       │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 数据流图

```
用户拖动高亮框
      │
      ▼
┌─────────────────────────────────────────────┐
│ ZoneScaleView                               │
│ - 检测DragGesture                           │
│ - 计算拖动偏移量（Zone单位）                │
│ - 调用onShutterOffsetChange                 │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ MeteringViewModel                           │
│ - updateShutterDragOffset()                 │
│   * 更新dragShutterOffset                   │
│   * 触发实时预览（测光点移动）              │
│   * 通知视图更新                            │
└──────────────────────┬──────────────────────┘
                       │
        拖动结束 ──────┤
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ MeteringViewModel                           │
│ - endShutterDragWithOffset()                │
│   * 计算最终偏移量                            │
│   * 限制范围 ±5 Zone                          │
│   * 更新shutterSpeedOffset                  │
│   * 重置dragShutterOffset                   │
│   * 标记isManualShutterAdjusted = true      │
│ - recalculateExposureWithShutterOffset()    │
│   * 计算新的快门速度                          │
│   * 重新计算曝光参数                          │
│   * 更新currentExposure                       │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│ Views 更新                                  │
│ - ExposureInfoView: 显示新快门速度          │
│ - ZoneScaleView: 测光点在新位置              │
│ - 其他相关视图更新                          │
└─────────────────────────────────────────────┘
```

---

## 2. 关键代码实现

### 2.1 ZoneScaleView 重写

```swift
import SwiftUI

// MARK: - Zone Scale View (Shutter Control Version)

/// 11区梯度条视图 - 快门控制版本
/// 拖动宽容度框调整快门速度，而非移动宽容度范围
struct ZoneScaleView: View {

    // MARK: - Properties

    /// 宽容度最小 Zone（仅用于显示高亮框位置）
    let minZone: Int

    /// 宽容度最大 Zone（仅用于显示高亮框位置）
    let maxZone: Int

    /// 测光点数组
    let meteringPoints: [MeteringPoint]

    /// 当前快门偏移量（Zone单位）
    /// 正数 = 提高快门，负数 = 降低快门
    var shutterSpeedOffset: Double = 0

    /// 拖动过程中的临时偏移
    var dragOffset: Double = 0

    /// 快门偏移变化回调
    var onShutterOffsetChange: ((Double) -> Void)?

    /// 快门偏移结束回调
    var onShutterOffsetEnd: ((Double) -> Void)?

    /// 渐变条高度
    var gradientHeight: CGFloat = 32

    /// Zone 标签
    private let zoneLabels = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    /// 是否正在拖动
    @State private var isDragging: Bool = false

    /// 11个 Zone 的颜色（从黑到白）
    private let zoneColors: [Color] = [
        Color(hex: "#000000")!, // Zone 0: 纯黑
        Color(hex: "#1A1A1A")!, // Zone I
        Color(hex: "#333333")!, // Zone II
        Color(hex: "#4D4D4D")!, // Zone III
        Color(hex: "#666666")!, // Zone IV
        Color(hex: "#808080")!, // Zone V: 中灰
        Color(hex: "#999999")!, // Zone VI
        Color(hex: "#B3B3B3")!, // Zone VII
        Color(hex: "#CCCCCC")!, // Zone VIII
        Color(hex: "#E6E6E6")!, // Zone IX
        Color(hex: "#FFFFFF")!  // Zone X: 纯白
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Zone 标签行
            zoneLabelsRow

            // 渐变条容器（包含宽容度框和测光点）
            gradientBarContainer
        }
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Subviews

    /// Zone 标签行
    private var zoneLabelsRow: some View {
        GeometryReader { geometry in
            let zoneWidth = geometry.size.width / 11

            HStack(spacing: 0) {
                ForEach(0..<11, id: \.self) { index in
                    Text(zoneLabels[index])
                        .font(.system(size: 10, weight: index == 5 ? .semibold : .regular))
                        .foregroundColor(index == 5 ? .white : Color(hex: "#8E8E93"))
                        .frame(width: zoneWidth)
                }
            }
        }
        .frame(height: 16)
    }

    /// 渐变条容器
    private var gradientBarContainer: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let zoneWidth = totalWidth / 11

            ZStack {
                // 渐变背景
                gradientBackground

                // 宽容度标记（仅显示，不随拖动移动）
                dynamicRangeMarker(zoneWidth: zoneWidth)

                // 测光点标记（随快门偏移移动）
                meteringPointMarkers(zoneWidth: zoneWidth)

                // 拖动指示器（显示当前偏移）
                dragIndicator(zoneWidth: zoneWidth)
            }
        }
        .frame(height: gradientHeight)
    }

    /// 渐变背景
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: zoneColors),
            startPoint: .leading,
            endPoint: .trailing
        )
        .cornerRadius(4)
    }

    /// 宽容度标记（固定位置，仅作为参考）
    private func dynamicRangeMarker(zoneWidth: CGFloat) -> some View {
        let rangeWidth = CGFloat(maxZone - minZone + 1) * zoneWidth
        let baseXOffset = CGFloat(minZone) * zoneWidth

        return Rectangle()
            .fill(Color(hex: "#007AFF")!.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(Color(hex: "#007AFF")!, lineWidth: 1)
            )
            .frame(width: rangeWidth, height: gradientHeight - 4)
            .position(x: baseXOffset + rangeWidth / 2, y: gradientHeight / 2)
            .cornerRadius(4)
            // 拖动手势 - 用于调整快门
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        if !isDragging {
                            isDragging = true
                        }
                        onShutterOffsetChange?(zoneOffset)
                    }
                    .onEnded { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        isDragging = false
                        onShutterOffsetEnd?(zoneOffset)
                    }
            )
            .onTapGesture(count: 2) {
                // 双击重置
                onShutterOffsetEnd?(0)
            }
    }

    /// 测光点标记（随快门偏移移动）
    private func meteringPointMarkers(zoneWidth: CGFloat) -> some View {
        // 计算有效偏移（拖动中 + 已应用）
        let effectiveOffset = -(shutterSpeedOffset + dragOffset)
        // 负数表示快门提高（画面变暗），测光点向左移动（Zone值降低）

        let groupedPoints = Dictionary(grouping: meteringPoints) { $0.zone }

        return ForEach(Array(groupedPoints.keys.sorted()), id: \.self) { zone in
            if let points = groupedPoints[zone] {
                // 应用快门偏移后的显示位置
                let adjustedZone = Double(zone) + effectiveOffset
                let xPosition = CGFloat(adjustedZone) * zoneWidth + zoneWidth / 2

                HStack(spacing: -4) {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        meteringPointCircle(point: point, index: index, count: points.count)
                    }
                }
                .position(x: xPosition, y: gradientHeight / 2)
            }
        }
    }

    /// 测光点圆圈
    private func meteringPointCircle(point: MeteringPoint, index: Int, count: Int) -> some View {
        Circle()
            .fill(Color(hex: point.color) ?? .blue)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .opacity(isDragging ? 0.8 : 1.0)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .zIndex(Double(count - index))
    }

    /// 拖动指示器（显示当前偏移量）
    private func dragIndicator(zoneWidth: CGFloat) -> some View {
        let effectiveOffset = -(shutterSpeedOffset + dragOffset)
        let centerX = CGFloat(5 + effectiveOffset) * zoneWidth + zoneWidth / 2

        return Group {
            if isDragging || abs(shutterSpeedOffset) > 0.01 {
                VStack(spacing: 2) {
                    // 指示三角形
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isDragging ? .green : .white)
                        .rotationEffect(.degrees(180))

                    // 偏移数值
                    Text(offsetDisplayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDragging ? .green : .white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isDragging ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
                        )
                }
                .position(x: centerX, y: -20)
                .animation(.easeInOut(duration: 0.1), value: effectiveOffset)
            }
        }
    }

    /// 偏移显示文本
    private var offsetDisplayText: String {
        let totalOffset = shutterSpeedOffset + dragOffset
        let sign = totalOffset > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", totalOffset)) EV"
    }
}

// MARK: - Preview

#Preview("Zone Scale View - Shutter Control") {
    VStack(spacing: 20) {
        // Velvia 50，无偏移
        ZoneScaleView(
            minZone: 4,
            maxZone: 8,
            meteringPoints: [
                MeteringPoint(x: 100, y: 100, color: "#34C759", zone: 4, ev: 11.5),
                MeteringPoint(x: 200, y: 200, color: "#FF9500", zone: 7, ev: 14.5)
            ],
            shutterSpeedOffset: 0,
            onShutterOffsetChange: { offset in
                print("Drag offset: \(offset)")
            },
            onShutterOffsetEnd: { offset in
                print("End with offset: \(offset)")
            }
        )
        .frame(height: 80)
        .padding(.horizontal)

        // Velvia 50，+2 EV快门偏移（测光点向左移动）
        ZoneScaleView(
            minZone: 4,
            maxZone: 8,
            meteringPoints: [
                MeteringPoint(x: 100, y: 100, color: "#34C759", zone: 4, ev: 11.5),
                MeteringPoint(x: 200, y: 200, color: "#FF9500", zone: 7, ev: 14.5)
            ],
            shutterSpeedOffset: 2,  // +2 EV = 提高2档快门
            onShutterOffsetChange: nil,
            onShutterOffsetEnd: nil
        )
        .frame(height: 80)
        .padding(.horizontal)

        Text("+2 EV 快门偏移，测光点向左移动2档")
            .font(.caption)
            .foregroundColor(.secondary)

        Spacer()
    }
    .padding(.vertical)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
```

### 2. MeteringViewModel 更新

```swift
// MARK: - MeteringViewModel + Shutter Control Extension

extension MeteringViewModel {

    // MARK: - 快门偏移控制

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

    // MARK: - 快门偏移更新

    /// 更新拖动偏移（用于拖动宽容度框时的实时预览）
    /// - Parameter offset: 拖动偏移量（Zone单位）
    func updateShutterDragOffset(_ offset: Double) {
        dragShutterOffset = offset
        // 触发实时预览
        objectWillChange.send()
    }

    /// 结束拖动并应用最终偏移
    /// - Parameter finalOffset: 最终偏移量（Zone单位）
    func endShutterDragWithOffset(_ finalOffset: Double) {
        let newOffset = shutterSpeedOffset + finalOffset
        // 限制范围 ±5 Zone
        shutterSpeedOffset = max(-5.0, min(5.0, newOffset))
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

    /// 设置基准快门速度
    func setBaseShutterSpeed(_ speed: Double) {
        baseShutterSpeed = speed
    }

    // MARK: - 曝光重新计算

    /// 根据快门偏移重新计算曝光参数
    private func recalculateExposureWithShutterOffset() {
        let zones = meteringPoints.map { $0.zone }

        // 如果没有测光点，使用默认参数
        guard !zones.isEmpty else {
            currentExposure = calculateDefaultExposureWithShutterOffset()
            return
        }

        // 计算新的曝光参数
        let result = ExposureCalculator.calculateExposureWithShutterOffset(
            zones: zones,
            shutterOffset: shutterSpeedOffset,
            lockedAperture: lockedAperture,
            iso: selectedFilm.iso,
            baseShutterSpeed: baseShutterSpeed
        )

        currentExposure = result
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
}
```

### 3. ExposureCalculator 扩展

```swift
// MARK: - ExposureCalculator + Shutter Control Extension

extension ExposureCalculator {

    /// 快门档位定义
    static let shutterSpeedStops: [(fraction: String, decimal: Double)] = [
        ("1/8000", 1/8000), ("1/4000", 1/4000), ("1/2000", 1/2000), ("1/1000", 1/1000),
        ("1/500", 1/500), ("1/250", 1/250), ("1/125", 1/125), ("1/60", 1/60),
        ("1/30", 1/30), ("1/15", 1/15), ("1/8", 1/8), ("1/4", 1/4),
        ("1/2", 1/2), ("1s", 1.0), ("2s", 2.0), ("4s", 4.0), ("8s", 8.0)
    ]

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
    ) -> ExposureResult {
        // 计算平均Zone
        let avgZone = calculateAverageZone(zones)

        // 计算基础EV（Zone V = 基准）
        let baseEV = referenceEV + (Double(avgZone) - 5.0)

        // 应用快门偏移后的EV
        // 快门提高(+offset) = 进光减少 = EV降低
        let adjustedEV = baseEV - shutterOffset

        // 计算调整后的快门速度
        let adjustedShutterSpeed = baseShutterSpeed / pow(2, shutterOffset)

        // 计算光圈
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
            aperture = calculateAperture(stops: stops)

            // 快门使用调整后的值
            finalShutterSpeed = adjustedShutterSpeed
        }

        return ExposureResult(
            aperture: aperture,
            shutterSpeed: finalShutterSpeed,
            iso: iso,
            ev: adjustedEV,
            adjustment: 0,
            compensation: 0
        )
    }

    /// 获取最接近的标准快门档位
    static func nearestShutterSpeed(_ speed: Double) -> (fraction: String, decimal: Double) {
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

    /// 格式化快门速度显示
    static func formatShutterSpeedWithOffset(_ speed: Double, offset: Double) -> String {
        let nearest = nearestShutterSpeed(speed)

        if abs(offset) < 0.1 {
            return nearest.fraction
        } else {
            let sign = offset > 0 ? "↑" : "↓"
            return "\(nearest.fraction) \(sign)"
        }
    }
}
```

### 4. MainMeteringView 集成

```swift
// MARK: - MainMeteringView Integration

extension MainMeteringView {

    /// 创建带快门控制的ZoneScaleView
    private func shutterControlZoneScaleView() -> some View {
        ZoneScaleView(
            minZone: viewModel.selectedFilm.minZone,
            maxZone: viewModel.selectedFilm.maxZone,
            meteringPoints: viewModel.meteringPoints,
            shutterSpeedOffset: viewModel.shutterSpeedOffset,
            dragOffset: viewModel.dragShutterOffset,
            onShutterOffsetChange: { offset in
                viewModel.updateShutterDragOffset(offset)
            },
            onShutterOffsetEnd: { offset in
                viewModel.endShutterDragWithOffset(offset)
            }
        )
    }

    /// 创建带快门偏移显示的ExposureInfoView
    private func shutterControlExposureInfoView() -> some View {
        VStack(spacing: 8) {
            // 原有曝光参数显示
            ExposureInfoView(viewModel: viewModel)

            // 快门偏移指示器
            if viewModel.isManualShutterAdjusted || abs(viewModel.shutterSpeedOffset) > 0.01 {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.shutterSpeedOffset > 0 ? "arrow.up.circle" : "arrow.down.circle")
                        .foregroundColor(viewModel.shutterSpeedOffset > 0 ? .orange : .green)

                    Text("快门偏移: \(String(format: "%.1f", abs(viewModel.shutterSpeedOffset))) EV")
                        .font(.caption)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        viewModel.resetShutterOffset()
                    }) {
                        Text("重置")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
}
```

---

## 3. 接口文档

### 3.1 公共API

```swift
// MARK: - MeteringViewModel Public API

extension MeteringViewModel {

    // MARK: 属性

    /// 当前快门速度偏移量（Zone单位）
    /// 正数 = 提高快门，负数 = 降低快门
    var shutterSpeedOffset: Double { get }

    /// 当前实际快门速度（计算值）
    var effectiveShutterSpeed: Double { get }

    /// 是否手动调整过快门
    var isManualShutterAdjusted: Bool { get }

    // MARK: 方法

    /// 更新拖动偏移（实时预览）
    /// - Parameter offset: 拖动偏移量（Zone单位）
    func updateShutterDragOffset(_ offset: Double)

    /// 结束拖动并应用最终偏移
    /// - Parameter finalOffset: 最终偏移量（Zone单位）
    func endShutterDragWithOffset(_ finalOffset: Double)

    /// 重置快门偏移
    func resetShutterOffset()

    /// 获取测光点的显示Zone（应用快门偏移后）
    /// - Parameter point: 测光点
    /// - Returns: 显示Zone值
    func displayZone(for point: MeteringPoint) -> Double
}
```

### 3.2 回调接口

```swift
// MARK: - ZoneScaleView Callbacks

struct ZoneScaleView: View {
    // ...

    /// 快门偏移变化回调（拖动中）
    /// - Parameter offset: 当前偏移量（Zone单位）
    var onShutterOffsetChange: ((Double) -> Void)?

    /// 快门偏移结束回调（拖动结束）
    /// - Parameter offset: 最终偏移量（Zone单位）
    var onShutterOffsetEnd: ((Double) -> Void)?
}
```

---

## 4. 性能优化

### 4.1 计算优化

```swift
// MARK: - Performance Optimizations

extension MeteringViewModel {

    /// 使用Combine进行节流，防止过于频繁的计算
    private var shutterOffsetSubject = PassthroughSubject<Double, Never>()
    private var cancellables = Set<AnyCancellable>()

    private func setupShutterOffsetThrottle() {
        shutterOffsetSubject
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] offset in
                self?.performExpensiveRecalculation(with: offset)
            }
            .store(in: &cancellables)
    }

    /// 高性能曝光重新计算
    private func performExpensiveRecalculation(with offset: Double) {
        // 使用后台队列进行复杂计算
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 计算新的曝光参数
            let result = self.calculateExposureAsync(offset: offset)

            // 回到主线程更新UI
            DispatchQueue.main.async {
                self.currentExposure = result
            }
        }
    }

    private func calculateExposureAsync(offset: Double) -> ExposureResult {
        // 异步计算逻辑...
        return ExposureResult.default
    }
}
```

### 4.2 渲染优化

```swift
// MARK: - Rendering Optimizations

extension ZoneScaleView {

    /// 使用drawingGroup优化复杂渲染
    private var optimizedGradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: zoneColors),
            startPoint: .leading,
            endPoint: .trailing
        )
        .cornerRadius(4)
        .drawingGroup() // 使用Metal渲染
    }

    /// 条件渲染：只在需要时更新测光点
    private func optimizedMeteringPointMarkers(zoneWidth: CGFloat) -> some View {
        let effectiveOffset = -(shutterSpeedOffset + dragOffset)

        return ForEach(meteringPoints) { point in
            // 计算位置
            let adjustedZone = Double(point.zone) + effectiveOffset
            let xPosition = CGFloat(adjustedZone) * zoneWidth + zoneWidth / 2

            // 只在位置变化时重新渲染
            MeteringPointCircle(point: point)
                .position(x: xPosition, y: gradientHeight / 2)
                .animation(.easeInOut(duration: 0.1), value: effectiveOffset)
        }
    }
}

/// 独立视图组件，优化渲染性能
struct MeteringPointCircle: View {
    let point: MeteringPoint

    var body: some View {
        Circle()
            .fill(Color(hex: point.color) ?? .blue)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}
```

---

## 5. 错误处理

### 5.1 边界检查

```swift
// MARK: - Error Handling

extension MeteringViewModel {

    /// 快门偏移限制
    private static let maxShutterOffset: Double = 5.0
    private static let minShutterOffset: Double = -5.0

    /// 安全的快门偏移更新（带边界检查）
    func safeUpdateShutterOffset(_ offset: Double) {
        // 限制范围
        let clampedOffset = max(Self.minShutterOffset, min(Self.maxShutterOffset, offset))

        if clampedOffset != offset {
            // 触发边界警告
            NotificationCenter.default.post(
                name: .shutterOffsetLimitReached,
                object: nil,
                userInfo: ["requested": offset, "applied": clampedOffset]
            )
        }

        shutterSpeedOffset = clampedOffset
    }

    /// 验证快门速度是否在相机支持范围内
    func validateShutterSpeed() -> Bool {
        let minShutter: Double = 1/8000  // 最快快门
        let maxShutter: Double = 30.0    // 最慢快门（B门不计）

        let currentSpeed = effectiveShutterSpeed

        if currentSpeed < minShutter {
            // 快门速度超出相机上限
            NotificationCenter.default.post(
                name: .shutterSpeedOutOfRange,
                object: nil,
                userInfo: ["reason": "too_fast", "value": currentSpeed]
            )
            return false
        }

        if currentSpeed > maxShutter {
            // 快门速度超出相机下限
            NotificationCenter.default.post(
                name: .shutterSpeedOutOfRange,
                object: nil,
                userInfo: ["reason": "too_slow", "value": currentSpeed]
            )
            return false
        }

        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let shutterOffsetLimitReached = Notification.Name("shutterOffsetLimitReached")
    static let shutterSpeedOutOfRange = Notification.Name("shutterSpeedOutOfRange")
}
```

---

## 6. 测试覆盖

### 6.1 单元测试完整代码

```swift
import XCTest
@testable import LightMeter

// MARK: - Shutter Control Tests

final class ShutterControlTests: XCTestCase {

    var viewModel: MeteringViewModel!
    var calculator: ExposureCalculator.Type!

    override func setUp() {
        super.setUp()
        viewModel = MeteringViewModel()
        calculator = ExposureCalculator.self
    }

    override func tearDown() {
        viewModel = nil
        calculator = nil
        super.tearDown()
    }

    // MARK: - 基础快门偏移测试

    /// 测试快门偏移默认值
    func testDefaultShutterOffset() {
        XCTAssertEqual(viewModel.shutterSpeedOffset, 0)
        XCTAssertFalse(viewModel.isManualShutterAdjusted)
    }

    /// 测试快门速度计算（提高快门）
    func testShutterSpeedIncrease() {
        // Given
        viewModel.baseShutterSpeed = 1/125.0

        // When: 提高1档快门
        viewModel.shutterSpeedOffset = 1

        // Then: 快门应为 1/250
        let expectedSpeed: Double = 1/250.0
        XCTAssertEqual(viewModel.effectiveShutterSpeed, expectedSpeed, accuracy: 0.0001)
    }

    /// 测试快门速度计算（降低快门）
    func testShutterSpeedDecrease() {
        // Given
        viewModel.baseShutterSpeed = 1/125.0

        // When: 降低2档快门
        viewModel.shutterSpeedOffset = -2

        // Then: 快门应为 1/30
        let expectedSpeed: Double = 1/30.0
        XCTAssertEqual(viewModel.effectiveShutterSpeed, expectedSpeed, accuracy: 0.0001)
    }

    // MARK: - 测光点显示Zone测试

    /// 测试测光点随快门偏移移动（提高快门）
    func testMeteringPointMovesWithShutterIncrease() {
        // Given: 添加Zone 7的测光点
        let brightness = ExposureCalculator.evToBrightness(ev: 14.5) // Zone 7
        viewModel.addMeteringPoint(x: 100, y: 100, brightness: brightness)

        let point = viewModel.meteringPoints.first!
        XCTAssertEqual(point.zone, 7)

        // When: 提高快门2档
        viewModel.shutterSpeedOffset = 2
        let displayZone = viewModel.displayZone(for: point)

        // Then: 显示Zone应为 7 - 2 = 5
        XCTAssertEqual(displayZone, 5.0, accuracy: 0.1)
    }

    /// 测试测光点随快门偏移移动（降低快门）
    func testMeteringPointMovesWithShutterDecrease() {
        // Given: 添加Zone 4的测光点
        let brightness = ExposureCalculator.evToBrightness(ev: 11.5) // Zone 4
        viewModel.addMeteringPoint(x: 100, y: 100, brightness: brightness)

        let point = viewModel.meteringPoints.first!

        // When: 降低快门3档
        viewModel.shutterSpeedOffset = -3
        let displayZone = viewModel.displayZone(for: point)

        // Then: 显示Zone应为 4 - (-3) = 7
        XCTAssertEqual(displayZone, 7.0, accuracy: 0.1)
    }

    // MARK: - 拖动交互测试

    /// 测试拖动偏移更新
    func testDragOffsetUpdate() {
        // Given
        viewModel.shutterSpeedOffset = 0

        // When: 拖动+1.5 Zone
        viewModel.updateShutterDragOffset(1.5)

        // Then
        XCTAssertEqual(viewModel.dragShutterOffset, 1.5)
        XCTAssertEqual(viewModel.shutterSpeedOffset, 0) // 未应用

        // When: 结束拖动
        viewModel.endShutterDragWithOffset(1.5)

        // Then
        XCTAssertEqual(viewModel.shutterSpeedOffset, 1.5)
        XCTAssertEqual(viewModel.dragShutterOffset, 0)
        XCTAssertTrue(viewModel.isManualShutterAdjusted)
    }

    /// 测试拖动偏移限制
    func testDragOffsetLimits() {
        // Given
        viewModel.shutterSpeedOffset = 4

        // When: 尝试超过最大限制
        viewModel.endShutterDragWithOffset(3) // 4 + 3 = 7 > 5

        // Then: 应被限制在5
        XCTAssertEqual(viewModel.shutterSpeedOffset, 5)

        // When: 尝试超过最小限制
        viewModel.endShutterDragWithOffset(-10) // 5 - 10 = -5 < -5

        // Then: 应被限制在-5
        XCTAssertEqual(viewModel.shutterSpeedOffset, -5)
    }

    /// 测试重置功能
    func testResetShutterOffset() {
        // Given
        viewModel.shutterSpeedOffset = 3
        viewModel.dragShutterOffset = 1
        viewModel.isManualShutterAdjusted = true

        // When
        viewModel.resetShutterOffset()

        // Then
        XCTAssertEqual(viewModel.shutterSpeedOffset, 0)
        XCTAssertEqual(viewModel.dragShutterOffset, 0)
        XCTAssertFalse(viewModel.isManualShutterAdjusted)
    }

    // MARK: - 曝光计算测试

    /// 测试曝光计算（自动模式）
    func testExposureCalculationAutoMode() {
        // Given
        let zones = [5, 6, 7] // 平均Zone 6
        let shutterOffset: Double = 2 // 提高2档快门
        let iso = 100

        // When
        let result = ExposureCalculator.calculateExposureWithShutterOffset(
            zones: zones,
            shutterOffset: shutterOffset,
            lockedAperture: nil,
            iso: iso,
            baseShutterSpeed: 1/125.0
        )

        // Then
        // 快门应为 1/125 / 2^2 = 1/500
        XCTAssertEqual(result.shutterSpeed, 1/500.0, accuracy: 0.0001)

        // EV应为基准EV + (6-5) - 2 = 12.5 + 1 - 2 = 11.5
        let expectedEV = ExposureCalculator.referenceEV + 1.0 - shutterOffset
        XCTAssertEqual(result.ev, expectedEV, accuracy: 0.1)
    }

    /// 测试曝光计算（光圈锁定模式）
    func testExposureCalculationWithLockedAperture() {
        // Given
        let zones = [5, 6] // 平均Zone 5.5
        let shutterOffset: Double = 1
        let lockedAperture: Double = 8.0
        let iso = 100

        // When
        let result = ExposureCalculator.calculateExposureWithShutterOffset(
            zones: zones,
            shutterOffset: shutterOffset,
            lockedAperture: lockedAperture,
            iso: iso,
            baseShutterSpeed: 1/125.0
        )

        // Then
        // 光圈应保持锁定值
        XCTAssertEqual(result.aperture, lockedAperture)

        // 快门应被计算（基于锁定光圈）
        // 不应是简单的baseShutter / 2^offset
        XCTAssertNotEqual(result.shutterSpeed, 1/250.0)
    }

    /// 测试快门档位格式化
    func testShutterSpeedFormatting() {
        // 测试标准档位
        XCTAssertEqual(ExposureCalculator.formatShutterSpeed(1/125), "1/125s")
        XCTAssertEqual(ExposureCalculator.formatShutterSpeed(1/500), "1/500s")
        XCTAssertEqual(ExposureCalculator.formatShutterSpeed(1), "1s")
        XCTAssertEqual(ExposureCalculator.formatShutterSpeed(2), "2s")

        // 测试非标准值（应四舍五入到最接近的档位）
        XCTAssertEqual(ExposureCalculator.formatShutterSpeed(1/300), "1/250s")
    }
}
```

---

## 7. 部署检查清单

### 7.1 代码检查

- [ ] ZoneScaleView 实现完成并通过编译
- [ ] MeteringViewModel 快门控制扩展实现完成
- [ ] ExposureCalculator 快门控制扩展实现完成
- [ ] MainMeteringView 集成完成
- [ ] 所有单元测试通过
- [ ] 代码符合Swift风格指南

### 7.2 功能检查

- [ ] 拖动宽容度框调整快门速度（而非移动框）
- [ ] 向右拖动 = 提高快门速度
- [ ] 向左拖动 = 降低快门速度
- [ ] 测光点随快门调整移动
- [ ] 宽容度框宽度固定
- [ ] 双击重置功能正常
- [ ] 快门偏移限制在±5 Zone

### 7.3 性能检查

- [ ] 拖动时界面保持60fps
- [ ] 测光点移动动画流畅
- [ ] 曝光计算无卡顿
- [ ] 内存使用稳定

### 7.4 兼容性检查

- [ ] iOS 26.0+ 正常运行
- [ ] iPhone 16 Pro 适配正常
- [ ] 与光圈锁定功能兼容
- [ ] 与胶片切换功能兼容

---

## 8. 附录

### 8.1 相关文档链接

- [功能设计文档](./zone-highlighter-shutter-control.md)
- [验收测试方案](./zone-highlighter-shutter-control-test.md)
- [原始需求文档](../tasklist.md)

### 8.2 代码提交记录

```
commit: TBD
Author: Developer
Date: TBD

feat: Zone高亮框快门控制

- 重写ZoneScaleView拖动逻辑
- 拖动高亮框调整快门速度
- 测光点随快门偏移移动
- 宽容度框宽度固定
- 双击重置功能

Closes: #TBD
```

### 8.3 参考资料

1. [Zone System](https://en.wikipedia.org/wiki/Zone_System) - 区域曝光法理论基础
2. [Shutter Speed](https://en.wikipedia.org/wiki/Shutter_speed) - 快门速度技术细节
3. [EV Calculation](https://en.wikipedia.org/wiki/Exposure_value) - 曝光值计算

---

*文档版本: 1.0*
*最后更新: 2025-04-28*
*作者: Claude*
