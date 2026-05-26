# LightMeter 项目结构文档

## 项目概述

LightMeter 是一款基于安塞尔·亚当斯区域曝光法（Zone System）的 iOS 胶片测光表应用。应用帮助胶片摄影爱好者通过实时取景测光，将画面不同区域映射到11区系统中，确保曝光精准。

---

## 目录结构

```
light-meter/
├── LightMeter/                    # 主项目代码
│   ├── LightMeterApp.swift        # 应用入口
│   ├── Info.plist                 # 配置文件
│   ├── Models/                    # 数据模型层
│   ├── Views/                     # 视图层
│   ├── ViewModels/                # 视图模型层
│   ├── Managers/                  # 管理器
│   └── Utilities/                 # 工具类
├── features/                      # Feature 详细文档
├── design.md                      # 完整的产品设计文档
├── design-tokens.md               # 设计令牌
├── tasklist.md                    # 开发任务清单
├── issues.md                      # 问题记录
├── CLAUDE.md                      # Claude Code 项目指导
├── Package.swift                  # Swift Package Manager 配置
└── project.yml                    # XcodeGen 项目配置
```

---

## 核心代码结构

### 1. 应用入口 (LightMeter/)

#### LightMeterApp.swift
- **用途**: 应用入口和主窗口配置
- **功能**:
  - 定义 `@main` 应用入口
  - 配置 `WindowGroup` 和 `MainMeteringView`
  - 强制使用深色模式 `.preferredColorScheme(.dark)`

#### Info.plist
- **用途**: iOS 应用配置
- **配置项**:
  - `NSCameraUsageDescription`: 相机权限说明
  - `UISceneConfigurations`: 场景配置
  - `UILaunchStoryboardName`: 启动屏幕配置

---

### 2. 数据模型层 (Models/)

#### FilmPreset.swift
- **用途**: 胶片预设模型，定义反转片的宽容度特性
- **核心结构**:
  ```swift
  struct FilmPreset {
      let id: UUID
      let name: String          // 胶片名称
      let color: String         // 主题色（十六进制）
      let zoneRange: String     // 宽容度范围（如 Zone IV-VIII）
      let description: String   // 描述
      let minZone: Int          // 最小 Zone
      let maxZone: Int          // 最大 Zone
      let iso: Int              // ISO 值
  }
  ```
- **预设胶片**:
  - `velvia50`: Velvia 50，宽容度 Zone IV-VIII，高饱和度
  - `provia100F`: Provia 100F，宽容度 Zone III-VIII，中性色彩
  - `ektachrome`: Ektachrome，宽容度 Zone III-VII，暖色调

#### MeteringPoint.swift
- **用途**: 测光点数据模型，存储单个测光点的位置和测光结果
- **核心结构**:
  ```swift
  struct MeteringPoint {
      let id: UUID
      var x: CGFloat            // 位置 X
      var y: CGFloat            // 位置 Y
      var color: String         // 标记颜色
      var zone: Int             // 所在 Zone
      var ev: Double            // EV 值
      var isSelected: Bool      // 是否选中
  }
  ```
- **常量定义**:
  - `ZoneSystem`: 11区系统常量
    - `labels`: Zone 罗马数字标签（0-X）
    - `referenceEV`: 参考 EV 值（Zone V = 12.5）
    - `brightnessRatio`: Zone 到亮度比的转换

#### ExposureCalculator.swift
- **用途**: 曝光计算工具，负责 EV 到 Zone 的转换和曝光参数计算
- **核心常量**:
  ```swift
  static let calibrationConstant: Double = 12.5  // 测光表校准常数
  static let referenceEV: Double = log2(0.18 / 12.5)  // Zone V 参考 EV
  static let baseAperture: Double = 8.0  // 基准光圈 f/8
  static let baseShutterSpeed: Double = 1.0 / 125.0  // 基准快门 1/125s
  ```
- **核心方法**:
  - `brightnessToEV`: 亮度转 EV 值（EV = log2(L/K)）
  - `evToZone`: EV 转 Zone（Zone = (EV - referenceEV) + 5）
  - `calculateOptimalAdjustment`: 计算最优曝光调整量，最小化测光点到宽容度边界的距离
  - `calculateExposure`: 计算完整曝光参数（光圈、快门、ISO）
  - `formatAperture/formatShutterSpeed`: 格式化曝光参数显示

---

### 3. 视图模型层 (ViewModels/)

#### MeteringViewModel.swift
- **用途**: 测光视图模型，管理应用状态和业务逻辑
- **状态管理**:
  ```swift
  @Published var currentFilm: FilmPreset              // 当前胶片
  @Published var meteringPoints: [MeteringPoint]      // 测光点数组
  @Published var selectedPointId: UUID?              // 选中点 ID
  @Published var exposure: ExposureParameters       // 曝光参数
  ```
- **核心方法**:
  - `changeFilm`: 切换胶片预设，更新曝光参数
  - `addMeteringPoint`: 添加测光点，自动分配颜色，计算 Zone/EV
  - `selectPoint/deletePoint`: 选择和删除测光点
  - `recalculateExposure`: 重新计算曝光参数

---

### 4. 管理器 (Managers/)

#### CameraManager.swift
- **用途**: 相机管理器，管理 AVCaptureSession 和处理相机权限
- **核心功能**:
  - 相机权限请求 (`requestPermission`)
  - AVCaptureSession 配置和管理
  - 视频输入设备配置（曝光、对焦、白平衡）
  - 预览层生成 (`makePreviewLayer`)
- **场景区域**:
  - `sky`: 天空区域（画面上部 0-35%）
  - `mountain`: 山峰区域（画面中上部 35%-70%）
  - `foreground`: 前景区域（画面下部 70%-100%）

---

### 5. 视图层 (Views/)

#### MainMeteringView.swift
- **用途**: 主测光界面视图，整合所有组件的完整测光界面
- **布局结构**:
  ```
  ZStack {
      // 背景
      VStack {
          TopToolbar           // 顶部工具栏
          CameraPreviewView    // 相机预览区域
          ZoneScaleView        // 11区梯度条
          ExposureInfoView     // 曝光参数栏
      }
      // 弹窗层
      FilmSelectorView         // 胶片选择弹窗
      PointEditMenuView        // 测光点编辑菜单
  }
  ```

#### CameraPreviewView.swift
- **用途**: 相机预览视图，使用 AVCaptureVideoPreviewLayer 显示实时相机画面
- **功能**:
  - `CameraPreviewLayer`: 包装 AVCaptureVideoPreviewLayer 的 UIViewRepresentable
  - `VideoPreviewView`: 包装 AVCaptureVideoPreviewLayer 的 UIView 子类
  - 测光点覆盖层显示
  - 相机权限请求视图

#### ZoneScaleView.swift
- **用途**: 11区梯度条视图，显示从纯黑到纯白的11个 Zone
- **显示内容**:
  - Zone 标签行（0, I, II, III, IV, V, VI, VII, VIII, IX, X）
  - 渐变背景（从黑到白的线性渐变）
  - 宽容度标记（蓝色半透明覆盖层）
  - 测光点标记（彩色圆点）

#### ExposureInfoView.swift
- **用途**: 曝光参数栏视图，显示光圈、快门、ISO 三个参数
- **布局**: 三等分布局
  - 左侧：光圈（如 f/8）
  - 中间：快门（如 1/125s）
  - 右侧：ISO（如 100）

#### TopToolbar.swift
- **用途**: 顶部工具栏视图，显示胶片选择按钮和当前 EV 值
- **布局**:
  - 左侧：胶片选择按钮（显示当前胶片名称和颜色图标）
  - 右侧：EV 值显示（如 EV: 12.5）

#### FilmSelectorView.swift
- **用途**: 胶片选择弹窗视图，底部弹窗样式显示可用胶片预设列表
- **功能**:
  - 显示所有胶片预设（Velvia 50、Provia 100F、Ektachrome）
  - 胶片信息展示（名称、宽容度、描述）
  - 选中状态标记

#### MeteringPointView.swift
- **用途**: 测光点标记视图，显示彩色方框标记和选中时的发光效果
- **样式**:
  - 主方框：50x50pt，圆角6pt，3pt边框
  - 发光效果（选中时）：70x70pt，模糊效果
  - 颜色：根据测光点颜色动态变化

#### PointEditMenuView.swift
- **用途**: 测光点编辑菜单视图，底部弹窗样式提供重新测光、删除和测光信息功能
- **功能按钮**:
  - 重新测光：重新获取该点亮度
  - 删除：删除测光点
  - 测光信息：显示 Zone 和 EV 值

---

### 6. 工具类 (Utilities/)

#### DeviceConfiguration.swift
- **用途**: iPhone 16 Pro 设备配置和 iOS 26+ 特性检测
- **配置内容**:
  - `iPhone16ProConfig`: 屏幕尺寸、安全区域、灵动岛尺寸
  - `iOS26Features`: iOS 26+ 新特性可用性检测
  - `DeviceType`: 设备类型检测（是否是 iPhone 16 Pro、是否带灵动岛）
- **扩展**:
  - `iPhone16ProSafeArea()`: 应用 iPhone 16 Pro 安全区域边距
  - `if`: 条件修饰符

---

## 配置文件

### Package.swift
- **用途**: Swift Package Manager 配置
- **配置项**:
  - 平台要求：iOS 17+
  - 目标：LightMeter 库
  - 启用严格并发检查

### project.yml
- **用途**: XcodeGen 项目配置
- **功能**: 生成 Xcode 项目文件

### Info.plist
- **用途**: iOS 应用配置
- **关键配置**:
  - `NSCameraUsageDescription`: 相机权限说明
  - `UISceneConfigurations`: 场景配置

---

## 文档目录

### features/
功能详细文档目录，包含每个功能的开发计划：

- `项目结构和基础配置.md`: 项目初始化和基础配置
- `数据模型层.md`: 数据模型设计
- `顶部工具栏和胶片选择器.md`: 顶部工具栏和胶片选择功能
- `测光点视图和编辑菜单.md`: 测光点视图和编辑功能
- `11区梯度条组件.md`: Zone 梯度条组件
- `曝光参数栏和计算逻辑.md`: 曝光参数和计算
- `集成测试和Bug修复.md`: 集成测试

### 设计文档

- `design.md`: 完整的产品设计文档
- `design-tokens.md`: 设计令牌（颜色、字体等）
- `tasklist.md`: 开发任务清单
- `issues.md`: 问题记录和修复进度
- `CLAUDE.md`: Claude Code 项目指导

---

## 架构模式

本项目采用 **MVVM (Model-View-ViewModel)** 架构模式：

```
┌─────────────────────────────────────────────────────────┐
│                      View Layer                         │
│  (MainMeteringView, CameraPreviewView, ZoneScaleView) │
└─────────────────────────┬───────────────────────────────┘
                          │ @StateObject
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    ViewModel Layer                      │
│               (MeteringViewModel)                       │
│  - 管理应用状态 (@Published)                              │
│  - 处理业务逻辑                                          │
│  - 协调 Model 和 View                                    │
└─────────────────────────┬───────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
│  Model Layer    │ │  Managers   │ │   Utilities     │
│ (FilmPreset,   │ │(CameraManager│ │(DeviceConfig)   │
│  MeteringPoint, │ │              │ │                 │
│  ExposureCalc)  │ │              │ │                 │
└─────────────────┘ └─────────────┘ └─────────────────┘
```

### 数据流

1. **用户交互** → View 捕获事件
2. **View** 调用 ViewModel 方法
3. **ViewModel** 更新状态并调用 Model/Manager
4. **Model** 执行业务逻辑
5. **ViewModel** 发布状态更新 (@Published)
6. **View** 自动响应状态变化刷新 UI

---

## 技术栈

- **语言**: Swift 6.0
- **UI 框架**: SwiftUI
- **最低版本**: iOS 17.0
- **相机框架**: AVFoundation (AVCaptureSession)
- **架构模式**: MVVM
- **并发**: Swift Concurrency (async/await)
- **包管理**: Swift Package Manager

---

## 核心算法

### 1. EV 计算
```
EV = log2(brightness / K)
其中 K = 12.5 (测光表校准常数)
```

### 2. Zone 映射
```
Zone = Int((EV - referenceEV) + 5)
其中 referenceEV = log2(0.18 / 12.5)
```

### 3. 曝光调整计算
- 目标：最小化测光点到宽容度边界的距离
- 约束：使平均 Zone 接近 Zone V
- 算法：网格搜索，评分函数考虑：
  1. 宽容度外点数（越少越好）
  2. 总距离（越小越好）
  3. 偏离理论最优值（越小越好）

---

## 文件依赖关系

```
LightMeterApp.swift
└── MainMeteringView.swift
    ├── TopToolbar.swift
    ├── CameraPreviewView.swift
    │   └── CameraManager.swift
    ├── ZoneScaleView.swift
    ├── ExposureInfoView.swift
    ├── FilmSelectorView.swift
    └── PointEditMenuView.swift
        └── MeteringPointView.swift

MeteringViewModel.swift
├── FilmPreset.swift
├── MeteringPoint.swift
└── ExposureCalculator.swift
```

---

## 开发规范

### 命名规范
- **文件**: PascalCase (如 `MeteringPointView.swift`)
- **结构体/类**: PascalCase (如 `FilmPreset`)
- **方法/变量**: camelCase (如 `calculateExposure`)
- **常量**: 大写 snake_case (如 `MAX_METERING_POINTS`)

### 代码组织
- 每个文件使用 `// MARK: -` 分隔不同部分
- 相关功能分组，按以下顺序：
  1. Properties
  2. Constants
  3. Initialization
  4. Public Methods
  5. Private Methods
  6. Previews

### SwiftUI 规范
- 使用 `@StateObject` 管理 ViewModel
- 使用 `@Published` 发布状态更新
- 使用 `@ViewBuilder` 拆分复杂视图
- 预览数据使用 `#Preview` 宏

---

## 构建和运行

### 使用 Xcode
```bash
# 打开项目（如果使用 XcodeGen 生成）
open LightMeter.xcodeproj

# 或使用 Swift Package Manager
swift build
```

### 使用 XcodeGen
```bash
# 安装 XcodeGen
brew install xcodegen

# 生成项目
xcodegen generate
```

### 运行测试
```bash
swift test
```

---

*最后更新: 2026-04-24*
