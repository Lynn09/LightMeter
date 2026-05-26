# Feature: Zone高亮框快门控制（Zone Highlighter Shutter Control）

## 功能概述

重构Zone Scale上的宽容度高亮框交互逻辑，将拖动操作从"移动宽容度范围"改为"调整快门速度"，使用户能够直观地调整曝光参数，将重要测光点调整到胶片宽容度范围内。

## 用户场景

### 场景1：天空过曝调整
**背景**：用户拍摄风景，天空测光点在Zone VIII，使用Velvia 50胶片（宽容度Zone IV-VIII）
**问题**：天空处于宽容度边缘，容易失去细节
**操作**：向右拖动高亮框，提高快门速度，使天空从Zone VIII降到Zone VI-VII，保留更多云层细节

### 场景2：暗部主体提亮
**背景**：用户拍摄人像，人物面部在Zone III，使用Provia 100F（宽容度Zone III-VIII）
**问题**：人物偏暗，想要提亮到Zone V
**操作**：向左拖动高亮框，降低快门速度，使面部从Zone III提升到Zone V

### 场景3：多点平衡
**背景**：画面有多个测光点，分布在Zone IV到Zone VIII
**操作**：拖动高亮框，观察所有测光点相对宽容度的位置，找到最佳平衡点

---

## 功能设计

### 1. 交互重新定义

| 操作 | 旧行为 | 新行为 |
|------|--------|--------|
| 拖动高亮框 | 移动宽容度范围（改变minZone/maxZone） | 调整快门速度 |
| 向右拖动 | 宽容度框右移 | 提高快门速度 |
| 向左拖动 | 宽容度框左移 | 降低快门速度 |
| 测光点显示 | 随宽容度框移动 | 随曝光变化移动 |
| 宽容度宽度 | 可变 | **固定**（由胶片决定） |

### 2. 快门速度调整逻辑

#### 基础规则
- 拖动范围：±5 EV（对应Zone ±5档）
- 快门调整：非线性递增（标准档位）
- 实时反馈：拖动时测光点实时移动

#### 快门档位表
```
Zone偏移: -5    -4    -3    -2    -1    0     +1    +2    +3    +4    +5
快门倍数: 1/16  1/8   1/4   1/2   基准  2x    4x    8x    16x   32x   64x

例如基准1/125s:
         1/2000 1/1000 1/500 1/250 1/125 1/60  1/30  1/15  1/8   1/4   1/2
```

#### 计算公式
```swift
// 拖动偏移量（Zone单位）
let zoneOffset = dragOffset  // 范围 -5 到 +5

// 计算EV差
let evDiff = -zoneOffset  // 提高快门(+Zone) = 降低EV

// 计算新快门速度
let newShutterSpeed = baseShutterSpeed * pow(2, -evDiff)
// 或: newShutterSpeed = baseShutterSpeed / pow(2, zoneOffset)
```

### 3. 测光点移动逻辑

#### 关键理解
- **测光点的绝对亮度不变**（场景实际亮度）
- **变化的是曝光参数**（快门速度）
- **相对位置变化**：测光点在Zone Scale上的显示位置

#### 移动公式
```swift
// 提高快门速度(+1 Zone) → 画面变暗 → 测光点向低Zone移动
let adjustedZone = originalZone + zoneOffset

// 例如：
// Zone 7 + (-2) [向右拖2档] = Zone 5
// 快门加快 → EV降低 → Zone值降低
```

#### 视觉反馈
- 拖动时：测光点实时平滑移动
- 超出Zone 0-X：红色警告（提示超出有效范围）
- 落入宽容度：高亮显示（绿色）

### 4. 宽容度高亮框行为

#### 固定宽度
```swift
// 宽容度宽度由胶片决定，永不改变
let dynamicRangeWidth = film.maxZone - film.minZone + 1  // 固定值

// Velvia 50: Zone IV-VIII = 5档
// Provia 100F: Zone III-VIII = 6档
// Ektachrome: Zone III-VII = 5档
```

#### 位置指示
- 高亮框位置**固定显示**在胶片对应的Zone范围
- 例如Velvia 50：高亮框始终覆盖Zone IV-VIII区域
- 作为参考系，帮助用户判断测光点是否在宽容度内

#### 拖动交互
- 拖动高亮框 = 调整快门
- 宽容度框本身**不随拖动移动**
- 测光点**随拖动移动**

### 5. 曝光参数栏联动

#### 快门显示
- 实时显示当前快门速度
- 格式：标准档位（1/125s → 1/250s → 1/500s...）
- 指示：↑提高 或 ↓降低

#### 光圈锁定处理
- 光圈未锁定：快门调整，光圈自动补偿
- 光圈已锁定：仅调整快门，光圈不变
- ISO：始终由胶片决定，不可调整

#### 重置功能
- 双击高亮框：重置为自动曝光
- 按钮：显示当前偏移量，点击可重置

---

## 数据模型

### 新增/修改状态

```swift
// MARK: - MeteringViewModel

/// 快门速度偏移量（Zone单位）
/// 正数 = 提高快门（画面变暗）
/// 负数 = 降低快门（画面变亮）
@Published var shutterSpeedOffset: Double = 0

/// 基准快门速度（自动计算或默认）
@Published var baseShutterSpeed: Double = 1/125.0

/// 当前实际快门速度（计算属性）
var currentShutterSpeed: Double {
    baseShutterSpeed / pow(2, shutterSpeedOffset)
}

/// 拖动过程中的临时偏移量
@Published var dragOffset: Double = 0

/// 是否处于手动快门调整模式
@Published var isManualShutterMode: Bool = false
```

### 曝光计算更新

```swift
/// 根据快门偏移重新计算所有测光点的显示位置
func updateMeteringPointsWithShutterOffset(_ offset: Double) {
    // 1. 计算快门速度变化
    let shutterMultiplier = pow(2, -offset)
    let newShutterSpeed = baseShutterSpeed * shutterMultiplier

    // 2. 计算EV变化（快门每档 = 1 EV）
    let evDiff = -offset  // 提高快门 = 降低EV

    // 3. 更新所有测光点的Zone显示值
    for index in meteringPoints.indices {
        // 实际Zone值不变（场景亮度不变）
        // 变化的是曝光补偿后的"有效Zone"
        let originalZone = meteringPoints[index].zone
        let adjustedZone = Double(originalZone) + evDiff

        // 存储调整后的显示Zone
        meteringPoints[index].adjustedZone = Int(round(adjustedZone))
    }

    // 4. 重新计算曝光参数
    recalculateExposureParameters()
}

/// 重新计算曝光参数（考虑快门偏移）
func recalculateExposureParameters() {
    let evOffset = -shutterSpeedOffset  // 快门偏移对应的EV偏移

    if let lockedAperture = lockedAperture {
        // 光圈锁定模式：光圈固定，调整快门
        // 曝光时间随快门偏移线性变化
        let adjustedShutter = baseShutterSpeed / pow(2, shutterSpeedOffset)
        currentExposure.shutterSpeed = adjustedShutter
    } else {
        // 自动模式：根据测光点平均Zone调整
        // 快门偏移作为额外补偿
        let result = ExposureCalculator.calculateExposureWithShutterOffset(
            zones: meteringPoints.map { $0.zone },
            shutterOffset: shutterSpeedOffset,
            iso: selectedFilm.iso
        )
        currentExposure = result
    }
}
```

---

## UI设计

### 1. Zone Scale视觉更新

#### 宽容度高亮框
```
Zone:    0   I   II  III IV  V   VI  VII VIII IX  X
        ├───────┤←──高亮框固定宽度──→├───────┤
                └─────────────────────┘
                 Velvia 50: IV-VIII

Metering:    ●       ●           ●
            (III)   (V)         (VII)

拖动效果:
右拖(+1):       ●       ●           ●
              (III)→(IV) (V)→(VI) (VII)→(VIII)
              所有测光点向左移动（Zone值降低）
```

#### 视觉元素
- **高亮框**：蓝色半透明边框，表示胶片宽容度范围
- **测光点**：彩色圆点，拖动时平滑移动
- **有效指示**：测光点在高亮框内时显示绿色边框
- **警告指示**：测光点超出0-X范围时显示红色

### 2. 曝光参数栏更新

#### 快门显示增强
```
┌─────────────────────────────────────────┐
│  光圈          快门           ISO        │
│  f/8       1/125s ↓        100          │
│             +0 EV                       │
│  [====●========]  ← 拖动指示器          │
└─────────────────────────────────────────┘
```

#### 指示器
- 基准线：0位置（自动计算值）
- 拖动点：当前偏移位置
- 数值显示：实际快门速度
- EV指示：相对于自动的偏移量

### 3. 交互反馈

#### 拖动中
- 所有测光点平滑跟随移动
- 快门数值实时更新
- 进入宽容度的测光点脉冲闪烁

#### 拖动结束
- 应用最终快门速度
- 曝光参数锁定（直到下次调整）
- 记录为手动模式

#### 重置
- 双击高亮框：快速重置
- 按钮：精确重置到0
- 视觉反馈：动画回到初始位置

---

## 开发实现

### 组件修改清单

| 文件 | 修改内容 | 优先级 |
|------|----------|--------|
| ZoneScaleView.swift | 重写拖动逻辑：调整快门而非移动框 | P0 |
| MeteringViewModel.swift | 添加shutterSpeedOffset状态 | P0 |
| ExposureCalculator.swift | 添加快门偏移计算函数 | P0 |
| ExposureInfoView.swift | 增强快门显示，添加偏移指示 | P1 |
| MeteringPoint.swift | 添加adjustedZone显示属性 | P1 |

### 关键代码实现

#### 1. ZoneScaleView 拖动重写

```swift
struct ZoneScaleView: View {
    // ... 现有属性

    /// 快门速度偏移回调（Zone单位）
    var onShutterOffsetChange: ((Double) -> Void)?
    var onShutterOffsetEnd: ((Double) -> Void)?

    /// 宽容度框仅用于显示，不随拖动移动
    private func dynamicRangeMarker(zoneWidth: CGFloat) -> some View {
        let rangeWidth = CGFloat(maxZone - minZone + 1) * zoneWidth
        let baseXOffset = CGFloat(minZone) * zoneWidth

        return Rectangle()
            .fill(Color(hex: "#007AFF")!.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color(hex: "#007AFF")!, lineWidth: 2)
            )
            .frame(width: rangeWidth, height: gradientHeight - 4)
            .position(x: baseXOffset + rangeWidth / 2, y: gradientHeight / 2)
            // 拖动手势用于调整快门
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        onShutterOffsetChange?(zoneOffset)
                    }
                    .onEnded { value in
                        let zoneOffset = value.translation.width / zoneWidth
                        onShutterOffsetEnd?(zoneOffset)
                    }
            )
    }

    /// 测光点位置随快门偏移变化
    private func meteringPointMarkers(zoneWidth: CGFloat) -> some View {
        // 应用快门偏移后的显示位置
        let effectiveOffset = -shutterSpeedOffset  // 快门+ = Zone显示降低

        ForEach(meteringPoints) { point in
            let adjustedZone = Double(point.zone) + effectiveOffset
            let xPosition = CGFloat(adjustedZone) * zoneWidth + zoneWidth / 2

            // ... 显示逻辑
        }
    }
}
```

#### 2. ExposureCalculator 新增函数

```swift
extension ExposureCalculator {
    /// 根据快门偏移计算曝光参数
    static func calculateExposureWithShutterOffset(
        zones: [Int],
        shutterOffset: Double,
        iso: Int,
        lockedAperture: Double? = nil
    ) -> ExposureResult {
        // 基础Zone计算
        let avgZone = calculateAverageZone(zones)

        // 应用快门偏移计算EV
        // 快门提高(+offset) = 进光减少 = 需要更多光 = 测光点Zone降低
        let evDiff = (Double(avgZone) - 5.0) - shutterOffset

        // 计算光圈快门组合
        let baseEV = referenceEV + evDiff

        if let aperture = lockedAperture {
            // 光圈锁定：计算快门
            let shutterSpeed = calculateShutterSpeedForAperture(
                aperture: aperture,
                ev: baseEV,
                iso: iso
            )
            return ExposureResult(
                aperture: aperture,
                shutterSpeed: shutterSpeed,
                iso: iso,
                ev: baseEV
            )
        } else {
            // 自动模式：常规计算
            let aperture = calculateAperture(baseEV: baseEV)
            let shutterSpeed = calculateShutterSpeed(
                baseShutterSpeed: baseShutterSpeed / pow(2, shutterOffset),
                ev: baseEV
            )
            return ExposureResult(
                aperture: aperture,
                shutterSpeed: shutterSpeed,
                iso: iso,
                ev: baseEV
            )
        }
    }
}
```

#### 3. MeteringViewModel 状态管理

```swift
@MainActor
class MeteringViewModel: ObservableObject {
    // ... 现有代码

    // MARK: - 快门偏移控制

    /// 当前快门速度偏移量（Zone单位）
    /// 正数 = 提高快门（画面变暗，测光点向低Zone移动）
    @Published var shutterSpeedOffset: Double = 0

    /// 拖动过程中的临时偏移
    @Published var dragShutterOffset: Double = 0

    /// 基准快门速度
    private var baseShutterSpeed: Double = 1/125.0

    /// 是否手动调整过快门
    @Published var isManualShutterAdjusted: Bool = false

    /// 当前实际快门速度
    var effectiveShutterSpeed: Double {
        baseShutterSpeed / pow(2, shutterSpeedOffset)
    }

    /// 获取测光点的显示Zone（应用快门偏移后）
    func displayZone(for point: MeteringPoint) -> Double {
        Double(point.zone) - shutterSpeedOffset
    }

    /// 更新拖动偏移
    func updateShutterDragOffset(_ offset: Double) {
        dragShutterOffset = offset
        // 实时预览：临时调整测光点显示位置
        updateMeteringPointsPreview(offset: offset)
    }

    /// 结束拖动并应用
    func endShutterDragWithOffset(_ finalOffset: Double) {
        let newOffset = shutterSpeedOffset + finalOffset
        // 限制范围 ±5 Zone
        shutterSpeedOffset = max(-5, min(5, newOffset))
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

    /// 实时预览测光点位置
    private func updateMeteringPointsPreview(offset: Double) {
        // 触发视图更新，测光点随拖动移动
        let tempOffset = shutterSpeedOffset + offset
        // 通知视图刷新
        objectWillChange.send()
    }
}
```

### 接口定义

```swift
// MARK: - ShutterControlDelegate
protocol ShutterControlDelegate: AnyObject {
    /// 快门偏移开始调整
    func shutterControlDidBeginAdjustment()

    /// 快门偏移变化（拖动中）
    func shutterControl(_ control: ShutterControl, didChangeOffset offset: Double)

    /// 快门偏移调整结束
    func shutterControl(_ control: ShutterControl, didEndWithOffset offset: Double)

    /// 请求重置快门偏移
    func shutterControlDidRequestReset(_ control: ShutterControl)
}

// MARK: - ShutterControlDataSource
protocol ShutterControlDataSource: AnyObject {
    /// 获取当前快门偏移量
    func currentShutterOffset(for control: ShutterControl) -> Double

    /// 获取基准快门速度
    func baseShutterSpeed(for control: ShutterControl) -> Double

    /// 获取当前快门速度
    func currentShutterSpeed(for control: ShutterControl) -> Double
}
```

---

## 边界情况处理

### 1. 测光点超出Zone 0-X范围

**情况**：快门调整导致测光点显示在Zone 0以下或Zone X以上

**处理**：
- 视觉上继续显示（可能截断）
- 颜色变为红色警告
- 显示"超出范围"提示
- 双击重置恢复

### 2. 所有测光点都在宽容度外

**情况**：快门调整后，所有测光点都落在宽容度范围外

**处理**：
- 快门偏移量允许继续调整
- 显示黄色警告："建议调整至宽容度内"
- 计算最近的有效快门值（供参考）

### 3. 无测光点时的拖动

**情况**：没有测光点时尝试拖动高亮框

**处理**：
- 手势不响应或显示提示
- 提示"请先添加测光点"
- 快门偏移不可用

### 4. 光圈锁定与快门冲突

**情况**：光圈已锁定，快门调整可能超出可用范围

**处理**：
- 检查快门是否超出相机限制（如超过1/8000s）
- 超出时显示提示
- 自动限制最大偏移量

### 5. 胶片切换

**情况**：切换胶片时，宽容度范围变化

**处理**：
- 保持当前快门偏移量
- 更新宽容度高亮框宽度
- 测光点位置重新计算（新宽容度参考）
- 曝光参数根据新ISO重新计算

---

## 测试方案

### 单元测试

```swift
class ShutterControlTests: XCTestCase {
    var viewModel: MeteringViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MeteringViewModel()
    }

    /// 测试快门偏移计算
    func testShutterOffsetCalculation() {
        // Given
        viewModel.baseShutterSpeed = 1/125.0

        // When: 提高1档快门
        viewModel.shutterSpeedOffset = 1

        // Then
        XCTAssertEqual(viewModel.effectiveShutterSpeed, 1/250.0, accuracy: 0.001)
    }

    /// 测试测光点Zone随快门偏移移动
    func testMeteringPointZoneWithShutterOffset() {
        // Given
        viewModel.addMeteringPoint(x: 100, y: 100, brightness: 0.5) // Zone 5
        let point = viewModel.meteringPoints.first!

        // When: 提高快门1档（offset=1）
        viewModel.shutterSpeedOffset = 1
        let displayZone = viewModel.displayZone(for: point)

        // Then: 测光点显示Zone降低1
        XCTAssertEqual(displayZone, 4.0, accuracy: 0.1)
    }

    /// 测试快门偏移限制
    func testShutterOffsetLimits() {
        // 测试最大值限制
        viewModel.endShutterDragWithOffset(10)
        XCTAssertEqual(viewModel.shutterSpeedOffset, 5)

        // 测试最小值限制
        viewModel.endShutterDragWithOffset(-10)
        XCTAssertEqual(viewModel.shutterSpeedOffset, -5)
    }

    /// 测试双击重置
    func testDoubleTapReset() {
        // Given
        viewModel.shutterSpeedOffset = 3
        viewModel.isManualShutterAdjusted = true

        // When
        viewModel.resetShutterOffset()

        // Then
        XCTAssertEqual(viewModel.shutterSpeedOffset, 0)
        XCTAssertFalse(viewModel.isManualShutterAdjusted)
    }
}
```

### UI测试

```swift
class ZoneScaleShutterControlUITests: XCTestCase {
    /// 测试拖动高亮框调整快门
    func testDragZoneHighlighterToAdjustShutter() {
        let app = XCUIApplication()
        app.launch()

        // 添加测光点
        app.tap()

        // 获取宽容度高亮框
        let highlighter = app.otherElements["dynamicRangeMarker"]

        // 向右拖动
        highlighter.swipeRight()

        // 验证快门速度变化
        let shutterLabel = app.staticTexts["shutterSpeedLabel"]
        XCTAssertTrue(shutterLabel.label.contains("1/250")) // 或更快的快门

        // 验证测光点位置变化
        let pointMarker = app.otherElements["meteringPointMarker"]
        // 位置应在原位置左侧（更低Zone）
    }

    /// 测试双击重置
    func testDoubleTapToReset() {
        let app = XCUIApplication()
        app.launch()

        // 先调整快门
        let highlighter = app.otherElements["dynamicRangeMarker"]
        highlighter.swipeRight()

        // 双击重置
        highlighter.doubleTap()

        // 验证回到初始值
        let offsetLabel = app.staticTexts["shutterOffsetLabel"]
        XCTAssertEqual(offsetLabel.label, "+0 EV")
    }
}
```

### 手动测试用例

| 用例ID | 步骤 | 预期结果 |
|--------|------|----------|
| SC-001 | 1. 添加测光点在Zone 7<br>2. 向右拖动高亮框2档 | 1. 快门速度提高2档<br>2. 测光点移动到Zone 5<br>3. 曝光参数更新 |
| SC-002 | 1. 锁定光圈f/8<br>2. 向右拖动高亮框1档 | 1. 快门从1/125变为1/250<br>2. 光圈保持f/8不变 |
| SC-003 | 1. 添加多个测光点<br>2. 拖动高亮框 | 所有测光点同步移动，保持相对位置 |
| SC-004 | 1. 拖动高亮框3档<br>2. 双击高亮框 | 快门偏移重置为0，测光点回到原位 |
| SC-005 | 1. 切换到不同胶片<br>2. 观察宽容度高亮框 | 高亮框宽度随胶片宽容度变化 |

---

## 验收标准

### 功能验收

- [x] 拖动宽容度高亮框调整快门速度，而非移动宽容度
- [x] 向右拖动 = 提高快门速度（测光点向低Zone移动）
- [x] 向左拖动 = 降低快门速度（测光点向高Zone移动）
- [x] 宽容度高亮框宽度固定（由胶片决定）
- [x] 测光点随快门调整实时移动
- [x] 曝光参数栏快门值实时更新
- [x] 支持双击重置快门偏移

### 性能验收

- [x] 拖动时界面保持60fps
- [x] 测光点移动动画流畅（0.1s ease-in-out）
- [x] 快门偏移限制在±5 Zone范围内
- [x] 无内存泄漏

### 兼容性验收

- [x] iOS 26.0+ 正常运行
- [x] iPhone 16 Pro 适配正常
- [x] 与光圈锁定功能兼容
- [x] 与胶片切换功能兼容

---

## 附录

### 参考资料

1. **快门速度与曝光**：[Shutter Speed and Exposure](https://en.wikipedia.org/wiki/Shutter_speed)
2. **Zone System曝光计算**：[Zone System Exposure](https://en.wikipedia.org/wiki/Zone_System)
3. **反转片宽容度**：
   - Velvia 50: ~5 stops (Zone IV-VIII)
   - Provia 100F: ~6 stops (Zone III-VIII)
   - Ektachrome: ~5 stops (Zone III-VII)

### 术语表

| 术语 | 英文 | 定义 |
|------|------|------|
| 宽容度 | Dynamic Range | 胶片能记录的有效Zone范围 |
| 快门偏移 | Shutter Offset | 相对于基准快门的变化量（Zone单位） |
| 基准快门 | Base Shutter | 自动计算或默认的快门速度 |
| 显示Zone | Display Zone | 应用快门偏移后测光点的显示位置 |
| 实际Zone | Actual Zone | 测光点所在场景的真实Zone值 |

---

*文档版本: 1.0*
*最后更新: 2025-04-28*
