# Feature: 镜头焦段显示与取景适配

## 功能概述

在测光取景界面展示当前手机镜头的焦段信息，帮助用户把手机画面和胶片相机镜头视角建立对应关系，减少用手机测光时对构图范围的误判。

## 当前状态

[x] 已完成

## 目标

- 展示当前使用镜头的焦段或 35mm 等效焦段。
- 提供标准定焦选择：24mm、28mm、35mm、50mm、85mm、105mm。
- 选择标准定焦后，展示该焦段所对应的取景画面。
- 在实时取景和静态帧状态下保持显示一致。
- 焦段标签不遮挡测光点、EV 标识和静态帧控制按钮。

## 技术方向

- 在 `CameraManager` 中读取当前 `AVCaptureDevice` 的镜头/格式信息。
- 优先根据 `activeFormat.videoFieldOfView` 估算 35mm 等效焦段；无法精确获取时使用设备类型做降级估算。
- 将焦段状态发布给 SwiftUI 视图，在 `CameraPreviewView` 顶部显示。
- 基于当前手机镜头的等效焦段和用户选择的目标焦段，计算取景裁切倍率。
- 目标焦段长于当前手机镜头视角时，通过裁切预览模拟更窄视角。
- 目标焦段短于当前手机镜头可见视角时，提示“无法完整模拟”。

## 标准定焦范围

- 24mm
- 28mm
- 35mm
- 50mm
- 85mm
- 105mm

## 相关文件

- `LightMeter/Models/FocalLengthPreview.swift`
- `LightMeter/Managers/CameraManager.swift`
- `LightMeter/Views/CameraPreviewView.swift`
- `LightMeter/Views/MainMeteringView.swift`
- `doc/tasklist.md`

## 验收标准

- [x] 进入测光界面后能看到当前镜头焦段或明确的未知状态。
- [x] 可以选择 24mm、28mm、35mm、50mm、85mm、105mm 标准定焦。
- [x] 选择不同标准定焦后，取景画面按对应焦段变化。
- [x] 多摄设备切换或焦段变化时显示能更新。
- [x] 静态帧模式下焦段标签仍保持可见。
- [x] 焦段标签不影响点击测光、测光点显示和静态帧恢复入口。
