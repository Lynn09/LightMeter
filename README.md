# LightMeter - 胶片测光表

基于安塞尔·亚当斯区域曝光法（Zone System）的 iOS 胶片测光表应用，专为胶片摄影爱好者设计。

## 功能特性

- **实时取景测光**：使用手机摄像头实时取景，点击画面测光
- **11区梯度条**：可视化展示 Zone 0-X，显示宽容度标记和测光点分布
- **胶片预设**：支持 Velvia 50、Provia 100F、Ektachrome 等反转片
- **曝光计算**：自动计算推荐光圈、快门、ISO 组合

## 项目结构

```
light-meter/
├── LightMeter/              # 主项目代码
│   ├── App/                 # 应用入口
│   │   └── LightMeterApp.swift
│   ├── Models/              # 数据模型
│   │   ├── FilmPreset.swift
│   │   ├── MeteringPoint.swift
│   │   └── ExposureCalculator.swift
│   ├── Views/               # 视图组件
│   │   ├── MainMeteringView.swift
│   │   ├── ZoneScaleView.swift
│   │   ├── MeteringPointView.swift
│   │   ├── FilmSelectorView.swift
│   │   └── PointEditMenuView.swift
│   ├── ViewModels/          # 视图模型
│   │   └── MeteringViewModel.swift
│   └── Resources/           # 资源文件
│       └── Assets.xcassets
├── features/                # Feature 详细文档
├── design.md                # 产品设计文档
├── design-tokens.md         # 设计令牌
├── tasklist.md              # 开发任务清单
└── README.md                # 本文件
```

## 开发状态

查看 [tasklist.md](tasklist.md) 了解当前开发进度。

查看 [features/](features/) 目录了解每个 Feature 的详细开发计划。

## 设计要求

- **平台**: iOS 16.0+
- **语言**: Swift 5.9
- **框架**: SwiftUI
- **设备**: iPhone (Portrait only)
- **主题**: Dark Mode only

## 设计规范

详见 [design.md](design.md) 和 [design-tokens.md](design-tokens.md)。

## 开发指南

### 环境要求

- Xcode 15.0+
- iOS 16.0+ Simulator
- Swift 5.9+

### 构建项目

```bash
# 使用 Xcode 打开项目
open LightMeter.xcodeproj

# 或使用 xcodebuild
xcodebuild -project LightMeter.xcodeproj -scheme LightMeter -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### 运行测试

```bash
xcodebuild test -project LightMeter.xcodeproj -scheme LightMeter -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 贡献指南

1. 查看 [tasklist.md](tasklist.md) 选择一个未完成的任务
2. 查看对应的 Feature 文档了解详细开发计划
3. 创建分支进行开发
4. 完成后更新任务状态

## License

MIT License

## 致谢

- 设计灵感来自安塞尔·亚当斯的区域曝光法
- 胶片预设数据参考各胶片厂商官方资料
