# Feature: 静态帧主体测光

## 功能概述

允许用户截取当前取景画面为静态帧，并在静态帧上进行点击测光或一键主体测光，减少用户长时间手持相机等待测光的负担。

## 目标

- 用户可以冻结当前相机画面。
- 冻结后预览显示静态帧，相机会话暂停。
- 冻结帧预览保持竖屏取景比例，避免直接显示原始横向视频缓冲区。
- 冻结帧上仍可点击添加测光点。
- 冻结后提供“主体测光”入口，自动识别画面中更可能是主体的位置并添加测光点。
- 恢复实时取景后继续使用相机实时帧。

## 主体测光策略

- 对静态帧进行 9x9 网格采样。
- 计算每个采样点与画面平均亮度的反差。
- 结合中心权重选择最可能的主体测光点。
- 返回主体位置、亮度和置信度。

该策略是轻量级主体估算，不依赖机器学习模型；适合当前项目离线、低复杂度的测光流程。

## 相关文件

- `LightMeter/Models/SubjectMeteringAnalyzer.swift`
- `LightMeter/Models/StaticFramePreviewGeometry.swift`
- `LightMeter/Managers/CameraManager.swift`
- `LightMeter/Views/CameraPreviewView.swift`
- `LightMeter/Views/MainMeteringView.swift`
- `test_static_subject_metering.swift`

## 验收标准

- 点击冻结按钮后画面变为静态帧。
- 静态帧保持和实时取景一致的竖屏比例。
- 静态帧模式下点击画面仍能添加测光点。
- 静态帧模式下点击“主体测光”会自动添加一个主体测光点。
- 点击恢复按钮后重新启动实时取景。
- 主体测光算法测试通过。
- 静态帧方向测试通过。
- iOS 构建通过。

## 已解决问题

- 静帧状态下截取/恢复按钮曾可能消失，导致用户无法恢复实时取景；已在 Task #12 修复。
