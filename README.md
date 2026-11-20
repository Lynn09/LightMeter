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

- Xcode 27+（iOS 27 SDK；本次使用 Xcode 27.1 / iOS 27.1 SDK 验证）
- iOS 27 Simulator 或运行 iOS 27 的 iPhone，用于系统兼容性验证
- 使用 Xcode 自带的 Swift 工具链，保留现有 Swift 5 语言模式

### iOS 27 兼容性

应用使用所选 Xcode 自带的最新 iOS SDK 构建，最低部署版本仍为 iOS 16.0。
支持新系统不需要把最低部署版本提高到 iOS 27。Swift Package 的最低版本仍为 iOS 17。

应用通过 `LightMeterApp` 的 SwiftUI `App` / `WindowGroup` 管理场景；
Info.plist 不再引用项目中不存在的 UIKit `SceneDelegate`，并使用系统启动屏配置。
`project.yml` 同步维护这些设置，重新生成工程时会保留。

运行模拟器 Debug 和真机 Release 的无签名兼容性构建：

```bash
bash scripts/check-ios27-compatibility.sh
```

构建检查不能替代设备测试。发布前需在 iOS 27 真机检查相机授权（允许及拒绝）、
实时预览与点击测光、前后台切换、胶片选择及曝光调节。

2026-10-26 验证结果：Xcode 27.1 / iOS 27.1 SDK 下，模拟器 Debug（arm64 / x86_64）
和真机 Release（arm64）无签名构建均通过。本机尚未安装 iOS 27 模拟器运行时，
未完成 iOS 27 启动及真机相机测试。现有 `CameraManager` 仍有并发隔离警告，
保留 Swift 5 模式；这些警告需要在未来切换 Swift 6 语言模式前处理。

系统升级核对参考：[Apple iOS 27 发布说明](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)。

### 构建项目

```bash
# 使用 Xcode 打开项目
open LightMeter.xcodeproj

# 或使用 xcodebuild
xcodebuild -project LightMeter.xcodeproj -scheme LightMeter -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### 运行测试

```bash
# 当前 Xcode 工程未配置 XCTest target；先执行兼容性构建检查。
bash scripts/check-ios27-compatibility.sh
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
