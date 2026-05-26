# Feature: 手动曝光补偿（Exposure Compensation）

## 功能概述

允许用户手动调整曝光补偿值，将特定测光点对准 Zone V（中性灰），实现更精细的曝光控制。

## 用户场景

### 场景1：对准特定区域到 Zone V
用户希望将画面中的特定区域（如人脸、天空）精确对准 Zone V 中性灰，而不是依赖系统计算的加权平均。

### 场景2：故意过曝/欠曝
用户想要创造性地让某区域偏离 Zone V，比如将阴影放在 Zone III 创造高对比度人像。

### 场景3：微调曝光
用户对系统自动计算的曝光不满意，需要手动微调获得更好的效果。

## 功能设计

### 1. 曝光补偿滑块

**位置**：曝光参数栏（ExposureInfoView）下方

**规格**：
- 范围：-3 EV 到 +3 EV
- 步进：1/3 EV（0.33）或 1/2 EV（0.5）
- 默认值：0（自动）

**交互**：
- 拖动滑块实时更新曝光参数
- 所有测光点在 Zone Scale 上实时移动
- 光圈和快门值根据补偿值重新计算
- 滑块偏离0时显示"手动"指示

### 2. 对准 Zone V 按钮

**位置**：测光点编辑菜单（PointEditMenuView）

**规格**：
- 按钮名称："对准 Zone V"
- 图标：target 或 crosshair
- 颜色：绿色（表示"对齐/确认"）

**逻辑**：
- 计算公式：`compensation = 5 - currentZone`
- 例如：测光点在 Zone VII，补偿 = 5 - 7 = -2 EV
- 限制范围：-3 EV 到 +3 EV

**交互流程**：
1. 用户点击测光点
2. 编辑菜单弹出
3. 点击"对准 Zone V"
4. 计算补偿值并应用
5. 测光点移动到 Zone V
6. 菜单关闭

### 3. 重置按钮

**位置**：曝光参数栏补偿滑块区域

**规格**：
- 按钮名称："自动" 或 "重置"
- 仅在手动模式下可用

**逻辑**：
- 清除 manualExposureCompensation
- 恢复 isUsingManualCompensation = false
- 恢复自动计算的曝光参数

## 数据模型

### MeteringViewModel 新增

```swift
// MARK: - 曝光补偿

/// 手动曝光补偿值（EV），范围 -3 到 +3
@Published var manualExposureCompensation: Double = 0

/// 是否使用手动曝光补偿
@Published var isUsingManualCompensation: Bool = false

/// 当前有效的曝光调整量
var effectiveAdjustment: Double {
    isUsingManualCompensation ? manualExposureCompensation : calculatedAdjustment
}

/// 自动计算的基准调整量
private var calculatedAdjustment: Double = 0

// MARK: - 方法

/// 设置手动曝光补偿
func setManualExposureCompensation(_ value: Double) {
    manualExposureCompensation = max(-3, min(3, value))
    isUsingManualCompensation = true
    updateExposureParameters()
}

/// 将测光点对准 Zone V
func alignPointToZoneV(pointId: UUID) {
    guard let point = meteringPoints.first(where: { $0.id == pointId }) else { return }

    let compensation = Double(5 - point.zone)
    manualExposureCompensation = max(-3, min(3, compensation))
    isUsingManualCompensation = true

    updateExposureParameters()
    closePointEditMenu()
}

/// 重置为自动曝光
func resetToAutoExposure() {
    isUsingManualCompensation = false
    manualExposureCompensation = 0
    updateExposureParameters()
}
```

## UI 设计

### 曝光参数栏布局

```
┌─────────────────────────────────────────┐
│  光圈          快门          ISO        │
│  f/8         1/125s        100          │
├─────────────────────────────────────────┤
│  曝光补偿: [自动]           [重置]      │
│  -3 ○━━━━━●━━━━━○ +3       +0.7 EV     │
└─────────────────────────────────────────┘
```

**滑块设计**：
- 轨道中间有"自动"标记（0位置）
- 滑块位置对应补偿值
- 右侧显示具体数值（+0.7 EV）
- 手动模式下显示"手动"标签

### 测光点编辑菜单

```
┌─────────────────────────────────┐
│  ○  重新测光    🔵 蓝色        │
├─────────────────────────────────┤
│  ○  对准 Zone V  🟢 绿色       │  ← 新增
├─────────────────────────────────┤
│  ○  删除        🔴 红色        │
├─────────────────────────────────┤
│     Zone VII | EV 14.0          │
└─────────────────────────────────┘
```

**按钮样式**：
- "对准 Zone V"使用绿色（表示成功/对齐）
- 图标使用 target 或 crosshair

### Zone Scale 视觉反馈

**实时移动**：
- 补偿调整时，测光点平滑过渡到新位置
- 动画时长：0.3秒
- 使用 ease-in-out 缓动

**状态指示**：
- 手动模式下，在 Zone Scale 旁显示"手动"标签
- 超出 Zone 0-X 范围的点变为红色警告

## 交互流程

### 场景：对准天空到 Zone V

```
[步骤1] 用户在天空区域点击
        ↓ 添加测光点（蓝色），显示在 Zone VII

[步骤2] 用户点击蓝色测光点
        ↓ 弹出编辑菜单

[步骤3] 用户点击"对准 Zone V"
        ↓ 系统计算：补偿 = 5 - 7 = -2 EV
        ↓ 应用 -2 EV 补偿
        ↓ 蓝色测光点移动到 Zone V
        ↓ 曝光参数更新（光圈/快门调整）
        ↓ 菜单关闭

[步骤4] 用户看到更新后的曝光参数
        - 光圈可能从 f/8 变为 f/11
        - 快门可能从 1/125s 变为 1/60s
        - 补偿滑块显示 -2.0 EV
```

### 场景：手动微调

```
[步骤1] 用户拖动补偿滑块
        ↓ 从 0 调整到 +0.7 EV
        ↓ 曝光参数实时更新
        ↓ 测光点实时移动

[步骤2] 用户满意后松手
        ↓ 保持 +0.7 EV 补偿
        ↓ 显示"手动"模式指示

[步骤3] 用户点击"重置"
        ↓ 补偿归零
        ↓ 恢复自动计算
```

## 边界情况

### 1. 补偿超出范围

**情况**：对准操作需要 ±4 EV，超出限制
**处理**：
- 限制在边界值（-3 或 +3）
- 显示 Toast 提示："已达到最大曝光补偿"
- 测光点尽可能靠近 Zone V

### 2. 多点对准冲突

**情况**：用户先后对准两个不同测光点到 Zone V
**处理**：
- 第二次操作覆盖第一次
- 只有最后选中的测光点在 Zone V
- 其他点根据原始 Zone 偏移

### 3. 删除参考点

**情况**：删除当前用于对准 Zone V 的测光点
**处理**：
- 保持当前补偿值（不自动重置）
- 用户可以手动点击"重置"
- 或者继续调整其他参数

## 性能优化

1. **实时计算**
   - 滑块拖动时，曝光计算在后台线程进行
   - 使用 Combine 的 throttle 防止过于频繁的更新（100ms 节流）

2. **动画性能**
   - 使用 SwiftUI 的 animation 修饰符
   - 避免不必要的视图重绘
   - 使用 .drawingGroup() 优化复杂视图

3. **内存管理**
   - 及时清理 Combine 订阅
   - 避免循环引用
   - 使用弱引用处理 delegate 模式

## 测试要点

### 功能测试
- [ ] 补偿滑块范围限制在 -3 到 +3 EV
- [ ] 对准 Zone V 后测光点正确移动到 Zone V
- [ ] 重置按钮恢复正常自动模式
- [ ] 多次对准不同点，只有最后选中的点在 Zone V

### 边界测试
- [ ] 补偿超出范围时的限制行为
- [ ] 删除测光点后保持补偿值
- [ ] 无测光点时滑块禁用或无效

### UI 测试
- [ ] 滑块拖动流畅无卡顿
- [ ] 动画过渡自然
- [ ] 所有状态提示清晰可见
- [ ] 不同屏幕尺寸适配正常

## 与其他功能的关系

| 功能 | 关系 | 说明 |
|------|------|------|
| 测光点系统 | 依赖 | 需要测光点的 Zone 值作为对准基准 |
| Zone Scale 显示 | 依赖 | 需要 Zone Scale 实时显示测光点位置 |
| 曝光计算 | 依赖 | 使用现有的 ExposureCalculator 进行参数计算 |
| 胶片预设 | 影响 | 补偿调整需要考虑当前胶片 ISO 值 |
| EV 显示 | 扩展 | 可能需要显示补偿后的 EV 值 |

## 实现优先级

### 高优先级（必须实现）
1. ✅ 曝光补偿滑块基础功能
2. ✅ 对准 Zone V 按钮
3. ✅ 重置为自动模式按钮
4. ✅ 实时更新曝光参数

### 中优先级（增强体验）
5. 平滑动画过渡效果
6. 边界情况处理提示（Toast）
7. 超出范围警告显示

### 低优先级（未来扩展）
8. 对准其他 Zone（III, VII 等）
9. 自定义对准目标
10. 补偿值预设（+1 EV, -2 EV 等快捷按钮）

## 附录：参考资源

- [Ansel Adams Zone System](https://en.wikipedia.org/wiki/Zone_System) - 区域曝光法理论基础
- [Light Metering Techniques](https://www.bhphotovideo.com/explora/photography/tips-and-solutions/understanding-exposure-part-2-metering-modes) - 测光技术
- [iOS Camera APIs](https://developer.apple.com/documentation/avfoundation/capture_setup/avcam_building_a_camera_app) - iOS 相机开发参考
