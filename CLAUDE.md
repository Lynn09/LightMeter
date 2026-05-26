# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一款基于安塞尔·亚当斯区域曝光法（Zone System）的 iOS 胶片测光表应用。应用帮助胶片摄影爱好者通过实时取景测光，将画面不同区域映射到11区系统中，确保曝光精准。

### 核心功能
- 实时取景测光：点击画面测光，彩色方框标记
- 11区梯度条：可视化展示 Zone 0-X，显示宽容度标记和测光点分布
- 胶片预设：支持 Velvia 50、Provia 100F、Ektachrome 等反转片
- 曝光计算：自动计算推荐光圈、快门、ISO 组合

### 系统要求
- **iOS 版本**: iOS 26.0+ (支持 iOS 26 新特性)
- **设备**: iPhone（优化适配 iPhone 16 Pro）
- **方向**: 仅竖屏 (Portrait)
- **主题**: 强制深色模式

### 每次对话开始时的工作流程
1. **查看 doc/tasklist.md** - 了解当前任务执行情况和进度
2. **查看 doc/features/ 文件夹** - 阅读需要实现的特性文档
3. **根据当前优先级执行任务**

### 当用户提出新需求/新功能的工作流程
1. **明确需求/功能点** - 拆分具体的功能点，细化成任务，整理features文档到doc/features文件下
2. **拆分任务** - 根据需求/功能点拆分任务，任务要包含实现的方案，涉及的代码，接口文档，以及测试验收的标准，将任务更新到tasklist.md中，并且把任务的状态置为待完成。注意，在未经过步骤三用户确认之前，不要进行任何代码以及配置上的修改
3. **待用户确认后，再进行task的执行，task执行完成后更新tasklist.md中任务的状态**


### 当用户提出问题时的工作流程
1. **查看doc/issues.md文件** - 了解是否有未修复的issue导致这个问题
2. **分析用户问题产生的原因** - 如果是代码或者是功能上的缺陷，把它记录到doc/issues.md中，在用户确认修复方案之前不要进行任何的代码修改
3. **向用户展示问题分析的结论** - 跟用户确认修复的方案是否可行，如果可行，则按照修复方案进行修复，如果不可行，则重复步骤3，直至用户认可


## 项目结构

具体的项目结构，文件夹分类以及代码的功能说明参考doc/project-structure.md
```
light-meter/
├── LightMeter/                    # 主项目代码
│   ├── LightMeterApp.swift        # 应用入口
│   ├── Info.plist                 # 配置文件
│   ├── Models/                    # 数据模型层
│   ├── Views/                     # 视图层
│   ├── ViewModels/                # 视图模型层
│   └── Resources/                 # 资源文件
└── CLAUDE.md                        # 本文件
```

## 设计系统


### 颜色
- **Background**: `#000000` (主背景), `#1C1C1E` (卡片背景)
- **Text**: `#FFFFFF` (主文字), `#8E8E93` (次要文字)
- **Accent**: `#007AFF` (蓝色强调), `#34C759` (绿色), `#FF9500` (橙色), `#FF3B30` (红色)
- **Film Colors**: Velvia `#007AFF`, Provia `#5856D6`, Ektachrome `#FF9500`

### 字体
- **Font Family**: SF Pro Text (正文), SF Mono (数值), Inter (部分UI)
- **Sizes**: 11pt (标签), 12pt (小文字), 13pt (描述), 15pt (胶片名), 17pt (标题), 20pt (EV值), 28pt (曝光值)

### iPhone 16 Pro 适配
- **屏幕宽度**: 402pt
- **屏幕高度**: 874pt
- **安全区域**: 顶部 59pt (Dynamic Island), 底部 34pt
- **设计宽度基准**: 393pt (iPhone 15 Pro)，在 402pt 上略有扩展

## 常用命令

### 构建和运行
```bash
# 使用 Xcode 打开项目（当 .xcodeproj 存在时）
open LightMeter.xcodeproj

# 使用 xcodebuild 命令行构建
xcodebuild -project LightMeter.xcodeproj -scheme LightMeter -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# 运行测试
xcodebuild test -project LightMeter.xcodeproj -scheme LightMeter -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 使用 XcodeGen 生成项目
```bash
# 安装 XcodeGen
brew install xcodegen

# 生成 .xcodeproj
xcodegen generate

# 生成的项目会自动包含 Info.plist 中的所有配置
```

## 关键实现说明

### 1. Zone System 计算
- Zone 0 = 纯黑, Zone X = 纯白
- Zone V = 18% 灰 (中间调)
- EV 计算: EV = log2(L/K), K=12.5
- Zone 映射: Zone = (EV - EV_reference) + 5

### 2. iOS 16+ 特性使用
- SwiftUI 的 NavigationStack (替代 NavigationView)
- Swift Charts (如果需要图表)
- Swift Regex (如果处理文本)
- Clock 和 Duration (时间管理)

### 3. iPhone 16 Pro 适配要点
- 使用 GeometryReader 适配不同屏幕尺寸
- 安全区域使用 safeAreaInsets
- Dynamic Island 区域避免放置重要内容
- 圆角屏幕适配（如有需要）

## 重要文件

- [design.md](doc/design.md): 完整的产品设计文档，包含所有功能规格
- [design-tokens.md](doc/design-tokens.md): 设计令牌，包含颜色、字体等设计系统定义
- [tasklist.md](doc/tasklist.md): 详细的任务清单和进度跟踪
- [features/](doc/features/): 每个 Feature 的详细开发计划
- [issues.md](doc/issues.md): 产品开发过程中遇到的问题，以及问题修复的进度、原因、以及详细修复方案
- [project-structure.md](doc/project-structure.md): 项目结构详情以及代码文件的功能详情

## 测试

当前项目没有设置单元测试或 UI 测试。建议添加：
- Zone System 计算逻辑的单元测试
- FilmPreset 数据模型的测试
- 曝光计算算法的测试
- 视图模型的状态管理测试

## 注意事项

- 项目强制使用深色模式，不支持浅色模式
- 仅支持竖屏方向
- 相机权限需要在真机上测试，模拟器无法使用相机
- iPhone 16 Pro 的屏幕尺寸比之前的机型略大，需要进行适配测试
