# 胶片测光表应用设计文档

## 项目概述

基于安塞尔·亚当斯区域曝光法（Zone System）的 iOS 测光表应用，专为胶片摄影爱好者设计。通过实时取景测光，帮助用户将画面不同区域映射到11区系统中，确保曝光精准。

---

## 核心功能

### 1. 实时取景测光
- 使用手机摄像头实时取景
- 点击画面任意区域进行测光
- 彩色方框标记已测区域
- 点击标记点弹出菜单：删除、重新测光
- 测光后自动计算EV值

### 2. 11区梯度条
- 固定显示 0-X 共11个区域
- 可视化渐变展示从黑到白的亮度分布
- 已测点用对应颜色标记在对应 Zone 上
- 选中胶片后显示宽容度范围标记
- 高亮显示当前测光点在11区中的位置

### 3. 胶片预设
支持以下反转片预设：

| 胶片 | 宽容度 | 特点 |
|------|--------|------|
| Velvia 50 | Zone IV-VIII (5档) | 色彩饱和度高，高光极易过曝 |
| Provia 100F | Zone III-VIII (6档) | 通用反转片，肤色还原好 |
| Ektachrome | Zone III-VII (5档) | 颗粒细腻，适合风光 |

预设包含：
- 宽容度范围标记
- 推荐 Zone 放置建议
- 特定胶片的曝光策略提示

### 4. 曝光显示
- 顶部显示当前 EV 值
- 底部显示推荐光圈/快门组合
- 显示光圈 f 值、快门秒数
- 基于测光结果自动计算

---

## 界面布局

### 单屏布局结构

```
┌─────────────────────────────────────┐
│ [胶片选择▼]         EV: 12           │  ← 顶部工具栏
├─────────────────────────────────────┤
│                                     │
│        [实时取景画面]               │  ← 主取景区域
│         ┌─┐  ┌─┐                    │
│         └─┘  └─┘  ← 彩色方框测光点  │
│                                     │
├─────────────────────────────────────┤
│  Z0  I  II  III IV  V  VI  VII VIII │  ← 11区梯度条
│  ▓▓▓▓▓▓▓░░░░░○───○░░░░░░░░░░░░░░░ │
│  ↑宽容度标记  ↑已测点高亮            │
├─────────────────────────────────────┤
│  推荐: f/8  1/125s                  │  ← 曝光参数
└─────────────────────────────────────┘
```

### 组件详细说明

#### 1. 顶部工具栏 (64pt)
- 左侧：胶片选择下拉按钮，显示当前选中胶片名称
- 右侧：EV值显示，大字体突出

#### 2. 实时取景区域
- 占据屏幕主要空间
- 支持点击测光
- 已测区域显示彩色方框标记（不同颜色区分不同点）
- 点击标记点弹出操作菜单（删除/重新测光）

#### 3. 11区梯度条 (80pt)
- 固定在屏幕底部上方
- 水平显示 Zone 0 到 Zone X
- 渐变背景从纯黑到纯白
- 宽容度范围用半透明遮罩标记
- 已测点用对应颜色的小圆点/标记显示在对应 Zone 位置

#### 4. 曝光参数栏 (48pt)
- 固定在屏幕底部
- 显示推荐的 光圈f值 和 快门速度
- 清晰易读的大字体

---

## 交互流程

### 主流程

1. **打开应用**
   - 默认加载上次使用的胶片预设（或Velvia 50）
   - 启动摄像头实时取景
   - 11区条显示当前胶片的宽容度标记

2. **选择胶片**（如需要切换）
   - 点击顶部胶片选择按钮
   - 弹出胶片列表（Velvia 50 / Provia 100F / Ektachrome）
   - 选择后11区条更新宽容度标记

3. **测光操作**
   - 对准拍摄场景
   - 点击画面中的关键区域（如高光、阴影、中间调）
   - 该点显示彩色方框标记，颜色对应下方11区条中的标记
   - 底部显示该点的测光数据

4. **查看分布**
   - 在11区条上查看已测点的分布情况
   - 观察各点是否落在胶片的宽容度范围内
   - 参考胶片预设的推荐Zone放置建议

5. **调整曝光**
   - 根据11区分布调整相机曝光参数
   - 确保关键区域（如阴影细节、高光细节）落在胶片的有效宽容度内

6. **删除/重新测光**
   - 点击画面上的测光标记点
   - 弹出菜单选择"删除"或"重新测光"
   - 重新测光时保持该点位置，更新测光数据

### 异常情况处理

| 场景 | 处理方案 |
|------|----------|
| 光线过暗无法测光 | 显示提示"光线不足，请增加照明或提高ISO" |
| 测光点超出宽容度 | 在11区条上用红色警示标记，提示"超出胶片宽容度" |
| 用户未授权摄像头 | 显示提示"请允许访问摄像头以使用测光功能" |
| 多次点击相近位置 | 自动合并为同一测光点，或提示"该位置已测光" |

---

## 数据模型

### 胶片预设数据结构

```typescript
interface FilmPreset {
  id: string;           // 唯一标识
  name: string;         // 显示名称
  type: 'slide' | 'negative' | 'bw';  // 胶片类型
  iso: number;          // 基准ISO
  latitude: {           // 宽容度
    min: number;        // 最低Zone（如3）
    max: number;        // 最高Zone（如8）
  };
  placement: {          // Zone放置建议
    shadows: number;    // 建议阴影放置Zone
    highlights: number; // 建议高光控制Zone
    midtones: number; // 中间调目标Zone
  };
  tips: string;        // 使用提示
}
```

### 测光点数据结构

```typescript
interface MeteringPoint {
  id: string;           // 唯一标识
  color: string;        // 标记颜色（十六进制）
  position: {           // 在画面中的位置（百分比）
    x: number;          // 0-1
    y: number;          // 0-1
  };
  ev: number;           // 测光EV值
  zone: number;         // 映射到的Zone（0-10）
  recommendation: {    // 曝光建议
    aperture: string;   // 推荐光圈
    shutter: string;    // 推荐快门
    compensation: number; // 曝光补偿（档）
  };
  timestamp: number;    // 记录时间戳
}
```

### 应用状态

```typescript
interface AppState {
  currentFilm: FilmPreset;     // 当前选中胶片
  meteringPoints: MeteringPoint[]; // 已测区域列表
  isCameraActive: boolean;     // 摄像头是否激活
  selectedPointId: string | null; // 当前选中的测光点
  settings: {                  // 用户设置
    defaultFilm: string;       // 默认胶片
    showGrid: boolean;         // 是否显示网格
    colorScheme: 'light' | 'dark' | 'auto';
  };
}
```

---

## 视觉设计规范

### 色彩方案（简洁现代风格）

| 元素 | 颜色 | 用途 |
|------|------|------|
| 主背景 | #FFFFFF | 界面主背景 |
| 卡片背景 | #F5F5F7 | 面板、卡片 |
| 主文字 | #1D1D1F | 标题、主要文字 |
| 次要文字 | #86868B | 说明、标签 |
| 强调色 | #007AFF | 按钮、选中状态 |
| 测光点颜色1 | #FF3B30 | 第1个测光点 |
| 测光点颜色2 | #34C759 | 第2个测光点 |
| 测光点颜色3 | #5856D6 | 第3个测光点 |
| 测光点颜色4 | #FF9500 | 第4个测光点 |
| 警告色 | #FF3B30 | 超出宽容度提示 |

### 字体规范

| 用途 | 字体 | 大小 | 字重 |
|------|------|------|------|
| 页面标题 | SF Pro Display | 20pt | Semibold |
| 区域标签 | SF Pro Text | 12pt | Regular |
| 数值显示 | SF Mono | 28pt | Medium |
| 小标签 | SF Pro Text | 11pt | Regular |
| 按钮文字 | SF Pro Text | 17pt | Medium |

### 图标规范

- 使用 SF Symbols 图标系统
- 图标大小：24x24pt（标准）、20x20pt（小）
- 线条粗细：2pt

### 间距规范

- 屏幕边距：16pt
- 组件间距：12pt
- 内边距：16pt
- 圆角：12pt（卡片）、8pt（按钮）

### 动画规范

- 过渡动画：0.3s ease-out
- 弹簧动画：damping 0.7, velocity 0.5
- 测光点出现：缩放从0到1，0.2s

---

## 技术实现要点

### 关键技术选型

| 功能 | 技术方案 |
|------|----------|
| 摄像头访问 | AVFoundation (iOS原生) |
| 测光计算 | CoreImage + 自定义算法 |
| 数据存储 | UserDefaults (轻量) / CoreData (复杂) |
| 界面框架 | SwiftUI (推荐) 或 UIKit |
| 颜色管理 | Display P3 色彩空间 |

### 核心算法逻辑

**【核心测光逻辑 - 不可篡改】**

### 核心设计原则

#### 原则1：亮度驱动测光，而非位置驱动

```
❌ 错误逻辑：根据画面位置"猜测"亮度
   - 画面上部 = 天空 = 亮（Zone VIII）
   - 画面中部 = 山峰 = 中灰（Zone V）
   - 画面下部 = 前景 = 暗（Zone III）

   这是完全错误的！

✅ 正确逻辑：基于实际亮度值计算
   1. 从相机获取实际像素亮度（Y通道或RGB转换）
   2. 或使用模拟的亮度值（0.0-1.0范围）
   3. 亮度值 → EV → Zone → 曝光参数

   关键公式：
   - 亮度值必须归一化到 [0.0, 1.0] 范围
   - 0.18 = Zone V (18%灰卡)
   - 0.72 = Zone VII (72%反射率)
   - 1.0 = 纯白 (100%反射率)
```

#### 原则2：每个测光点独立计算

```
❌ 错误逻辑：所有测光点共享相同的曝光参数
   - 基于所有测光点的平均Zone计算快门
   - 每个点的曝光参数 = 全局平均值

✅ 正确逻辑：每个测光点有自己的曝光参数

   示例（光圈锁定 f/8）：
   - 测光点A：亮度0.70 → Zone VII → EV 14.5 → 快门1/500s
   - 测光点B：亮度0.18 → Zone V → EV 12.5 → 快门1/125s
   - 测光点C：亮度0.09 → Zone IV → EV 10.5 → 快门1/30s

   关键点：
   - 每个测光点存储自己的曝光参数（ExposureParams）
   - 选中测光点时显示该点的独立参数
   - 光圈锁定时为每个点重新计算参数
```

### 关键公式（不可篡改）

#### 公式1：亮度转EV

```swift
// 公式：EV = log2(brightness / 0.18) + referenceEV
// 其中：
// - brightness: 归一化亮度值 [0.0, 1.0]
// - 0.18: Zone V（18%灰卡）的反射率
// - referenceEV: 12.5（标准参考EV值）

func brightnessToEV(brightness: Double) -> Double {
    guard brightness > 0 else { return 12.5 }
    return log2(brightness / 0.18) + 12.5
}

// 验证：
// - brightness = 0.18 (Zone V) → EV = log2(1) + 12.5 = 0 + 12.5 = 12.5 ✓
// - brightness = 0.72 (Zone VII) → EV = log2(4) + 12.5 = 2 + 12.5 = 14.5 ✓
```

#### 公式2：EV转Zone

```swift
// 公式：Zone = round((EV - referenceEV) + 5)
// 结果限制在 [0, 10] 范围内

func evToZone(ev: Double) -> Int {
    let rawZone = Int(round((ev - 12.5) + 5.0))
    return max(0, min(10, rawZone))
}

// 验证：
// - EV = 12.5 → Zone = (12.5 - 12.5) + 5 = 5 (Zone V) ✓
// - EV = 14.5 → Zone = (14.5 - 12.5) + 5 = 7 (Zone VII) ✓
// - EV = 10.5 → Zone = (10.5 - 12.5) + 5 = 3 (Zone III) ✓
```

#### 公式3：光圈锁定时的快门计算

```swift
// 基准: f/8, 1/125s, ISO 100, EV 12.5
// 公式: 快门 = baseShutter × 2^(apertureStops - evDiff + isoStops)

func calculateShutterForLockedAperture(
    aperture: Double,      // 锁定的光圈值（如 8.0 表示 f/8）
    pointEV: Double,        // 测光点的 EV 值
    iso: Int               // ISO 值
) -> Double {
    let baseShutterSpeed = 1.0 / 125.0

    // 计算光圈差异（档数）
    // 当光圈从 f/8 变为 f/11 (大一档)，需要2倍曝光时间
    let apertureStops = 2 * log2(aperture / 8.0)

    // EV 差异
    let evDiff = pointEV - 12.5

    // ISO 调整（ISO 增加一档，快门可以快一档）
    let isoStops = log2(Double(iso) / 100.0)

    // 快门计算：
    // baseShutter * 2^(apertureStops - evDiff + isoStops)
    // - apertureStops: 光圈变大(>0)需要更慢快门
    // - evDiff: EV 越高(>0)需要更快快门
    // - isoStops: ISO 越高(>0)需要更快快门
    let shutter = baseShutterSpeed * pow(2.0, apertureStops - evDiff + isoStops)

    // 取整到标准快门档位
    return nearestStandardShutter(shutter)
}

// 示例计算（锁定 f/8，测光点 EV 14.5，ISO 100）：
// apertureStops = 2 * log2(8/8) = 0
// evDiff = 14.5 - 12.5 = 2
// isoStops = log2(100/100) = 0
// shutter = (1/125) * 2^(0 - 2 + 0) = (1/125) * 2^(-2) = (1/125) * 0.25 = 1/500s
```

### 数据模型设计

#### ExposureParams 结构体

```swift
/// 曝光参数结构体，存储单个测光点的曝光计算结果
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
```

#### 修改后的 MeteringPoint 结构

```swift
struct MeteringPoint: Identifiable, Equatable, Hashable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var color: String
    var zone: Int
    var ev: Double
    var isSelected: Bool

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
}
```

### 关键实现要点

1. **添加测光点时计算曝光参数**：
   - 在 `MeteringViewModel.addMeteringPoint()` 中，如果已锁定光圈，立即为新点计算 `exposureParams`

2. **锁定/解锁光圈时更新所有点**：
   - 在 `lockAperture()` 中，为所有已存在的测光点计算 `exposureParams`
   - 在 `unlockAperture()` 中，清除所有测光点的 `exposureParams`

3. **显示选中测光点的独立曝光参数**：
   - 在 `ExposureInfoView` 中，如果有选中的测光点且该点有 `exposureParams`，显示该点的参数
   - 否则显示全局曝光参数

4. **在点编辑菜单中显示曝光参数**：
   - 在 `PointEditMenuView` 中，如果选中的点有 `exposureParams`，显示该点的光圈、快门、ISO


**公式推导说明：**
- Zone V = 18%反射率 = EV 12.5（标准参考点）
- 每增加1个Zone，亮度增加一倍（+1 EV）
- 亮度比例 = 0.18 × 2^(Zone - 5)
- 反过来：Zone = log2(亮度 / 0.18) + 5

**曝光建议计算：**
```
1. 确定目标Zone（通常是Zone V）
2. 计算需要调整的档数：ΔEV = TargetZone - CurrentZone
3. 提供曝光补偿建议（+/- ΔEV档）
4. 计算等效的光圈/快门组合
```

### 性能优化要点

- 摄像头预览使用低分辨率（降低CPU/GPU负载）
- 测光计算在后台线程执行，避免阻塞UI
- 限制同时显示的测光点数量（建议最多4-5个）
- 使用CALayer进行简单动画，避免复杂布局计算

---

## 文件结构建议

```
LightMeter/
├── App/
│   ├── LightMeterApp.swift      # 应用入口
│   └── AppState.swift           # 全局状态管理
├── Models/
│   ├── FilmPreset.swift         # 胶片预设模型
│   ├── MeteringPoint.swift      # 测光点模型
│   └── ExposureCalculator.swift # 曝光计算
├── Views/
│   ├── CameraView.swift         # 摄像头取景视图
│   ├── ZoneScaleView.swift      # 11区梯度条
│   ├── MeteringPointView.swift  # 测光点标记
│   ├── FilmSelectorView.swift   # 胶片选择器
│   └── ExposureInfoView.swift   # 曝光信息显示
├── ViewModels/
│   ├── CameraViewModel.swift    # 摄像头逻辑
│   ├── MeteringViewModel.swift  # 测光逻辑
│   └── SettingsViewModel.swift  # 设置逻辑
├── Resources/
│   ├── FilmPresets.json         # 胶片预设数据
│   └── Assets.xcassets          # 图片资源
└── Utils/
    ├── ColorExtensions.swift      # 颜色扩展
    ├── MathExtensions.swift       # 数学计算扩展
    └── Constants.swift            # 常量定义
```

---

## 下一步

设计文档已完成。接下来可以：

1. 使用 Pencil 的 MCP 工具进行 UI 原型设计
2. 创建 SwiftUI 项目框架
3. 实现核心功能模块

---

*文档版本: 1.0*
*创建日期: 2025-01-22*
*设计目标: iOS 胶片摄影测光表应用*
