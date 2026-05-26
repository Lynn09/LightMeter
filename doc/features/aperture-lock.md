# 光圈锁定功能实现文档

## 功能概述

光圈锁定功能允许胶片摄影用户根据景深需求锁定一个标准光圈值（如 f/8 或 f/11），然后让快门速度根据测光结果自动调整。

## 使用场景

- **风光摄影**：需要 f/8-f/11 获得最佳画质和全景清晰
- **人像摄影**：锁定 f/2.8 或 f/4 获得浅景深效果
- **街拍纪实**：锁定 f/5.6-f/8 快速抓拍无需调整光圈

## 技术实现

### 1. 数据模型层 (ExposureCalculator.swift)

#### 标准档位定义
```swift
// 标准光圈值数组
static let standardApertures: [Double] = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0]

// 标准快门速度数组（从快到慢）
static let standardShutterSpeeds: [Double] = [
    1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
    1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2,
    1.0, 2.0, 4.0, 8.0, 15.0, 30.0
]
```

#### 核心计算方法
```swift
/// 根据锁定光圈和测光点 EV 计算快门速度
static func calculateShutterForLockedAperture(
    aperture: Double,
    pointEV: Double,
    iso: Int
) -> Double {
    // 基准: f/8, 1/125s, ISO 100, EV 12.5
    // 计算光圈差异（档数）
    let apertureStops = 2 * log2(aperture / baseAperture)

    // EV 差异
    let evDiff = pointEV - referenceEV

    // ISO 调整
    let isoStops = log2(Double(iso) / 100.0)

    // 快门计算
    let shutter = baseShutterSpeed * pow(2.0, apertureStops - evDiff + isoStops)

    // 取整到标准快门档位
    return nearestStandardShutter(shutter)
}
```

### 2. 视图模型层 (MeteringViewModel.swift)

#### 状态属性
```swift
// 锁定的光圈值
@Published var lockedAperture: Double? = nil

// 是否显示光圈选择器
@Published var isApertureSelectorPresented: Bool = false

// 是否已锁定光圈（计算属性）
var isApertureLocked: Bool {
    lockedAperture != nil
}
```

#### 核心方法
```swift
/// 锁定光圈值
func lockAperture(_ aperture: Double) {
    lockedAperture = aperture
    isManualExposure = false  // 关闭手动曝光模式
    updateExposureParameters()
}

/// 解锁光圈
func unlockAperture() {
    lockedAperture = nil
    updateExposureParameters()
}
```

#### 曝光参数更新逻辑
```swift
private func updateExposureParameters() {
    // 检查是否处于光圈锁定模式
    if let lockedApertureValue = lockedAperture {
        // 光圈锁定模式
        let result = ExposureCalculator.calculateExposureWithLockedAperture(
            zones: zones,
            lockedAperture: lockedApertureValue,
            iso: selectedFilm.iso
        )
        currentExposure = ExposureResult(...)
    } else {
        // 正常自动模式
        let result = ExposureCalculator.calculateExposure(...)
        currentExposure = ExposureResult(...)
    }
}
```

### 3. UI 层

#### ApertureSelectorView.swift
- 底部弹窗样式，类似 FilmSelectorView
- 显示 10 个标准光圈值（f/1.4 到 f/32）
- 每个光圈显示描述（如"最佳画质·风光"）
- 提供"解锁光圈"按钮

#### ExposureInfoView.swift
- 光圈区域可点击打开选择器
- 锁定状态显示蓝色锁图标
- 锁定状态下光圈值显示为蓝色

#### PointEditMenuView.swift
- 测光信息显示包含快门速度
- 锁定模式下快门标签显示绿色带星号
- 显示计算后的快门值

## 使用流程

```
1. 用户点击曝光参数栏的光圈区域
   ↓
2. 弹出 ApertureSelectorView
   ↓
3. 用户选择一个光圈值（如 f/8）
   ↓
4. 调用 viewModel.lockAperture(8.0)
   ↓
5. UI 更新：光圈显示 f/8 + 锁图标，快门更新为计算值
   ↓
6. 每个测光点的快门根据各自 EV 重新计算
   ↓
7. 点击测光点查看详情，显示该点对应的快门速度
```

## 边界情况处理

| 场景 | 处理方式 |
|------|----------|
| 无测光点时锁定光圈 | 快门显示 "--"，锁定状态保存 |
| 测光点 EV 超出范围 | 快门计算并取最近标准值，可能在 30s 或 1/4000s 边界 |
| 切换胶片时 | 保持光圈锁定状态，快门根据新 ISO 重新计算 |
| 解锁光圈 | 恢复自动计算模式（基于平均 Zone） |
| 手动曝光模式与光圈锁定冲突 | 锁定光圈时自动关闭手动曝光模式 |

## 测试要点

1. **功能测试**
   - 点击光圈区域弹出/关闭选择器
   - 选择不同光圈值后锁图标正确显示
   - 快门速度根据锁定光圈正确计算
   - 每个测光点显示对应的快门速度

2. **边界测试**
   - 无测光点时锁定光圈的行为
   - 切换胶片后保持锁定状态
   - 解锁后恢复自动计算

3. **UI 测试**
   - 锁定状态蓝色主题正确显示
   - 锁图标位置和样式正确
   - 选择器弹窗动画流畅
