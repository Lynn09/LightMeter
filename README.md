# Film Light Meter App

A mobile light meter app designed for film photographers who want a practical, affordable alternative to dedicated handheld light meters.

The app uses the phone camera to estimate scene brightness and converts it into usable exposure recommendations, including aperture, shutter speed, and ISO combinations. It is designed around real film-shooting workflows such as spot metering, center-weighted metering, exposure compensation, and gray-card calibration.

## Why This Project

Handheld light meters are reliable, but they are often expensive and not always convenient to carry. For many film photographers, especially beginners, the phone camera is already available and capable of providing useful brightness information.

This project explores how a smartphone can be used as a practical reflective light meter by combining camera brightness sampling, exposure value calculation, calibration, and a photographer-friendly user interface.

## Features

* Camera-based reflective metering
* Spot metering for selected areas of the frame
* Center-weighted metering for general shooting
* Manual film ISO selection
* Aperture-priority exposure calculation
* Shutter-speed recommendation based on standard camera shutter steps
* Exposure compensation support
* Gray-card calibration for improved consistency
* Film-photography-oriented workflow and UI

## Core Concept

The app estimates exposure using the relationship between aperture, shutter speed, ISO, and exposure value.

At a high level, the workflow is:

```text
Camera brightness sampling
→ Scene brightness estimation
→ EV calculation
→ ISO / aperture / shutter-speed conversion
→ User-facing exposure recommendation
```

For example, after estimating the scene exposure value, the app can recommend combinations such as:

```text
ISO 400
f/8
1/125s
```

The goal is not to fully replace a professional incident light meter, but to provide a practical and accessible reflective metering tool for everyday film photography.

## Gray-Card Calibration

Because different phone cameras, sensors, lenses, and image-processing pipelines behave differently, the app supports gray-card calibration.

The calibration workflow helps the app understand how a standard middle-gray reference appears on the specific device. This makes the metering result more consistent across different lighting environments and phone models.

Calibration can help correct:

* Device-specific sensor response
* Lens and camera pipeline differences
* Brightness interpretation bias
* Exposure offset between the phone camera and film shooting workflow

## AI-Assisted Development

This project was developed with the help of OpenAI Codex as an AI pair-programming agent.

I used a “vibe coding” workflow to quickly turn product ideas into working features. Codex was used to assist with:

* Rapid prototyping of UI interactions
* Camera API integration
* Exposure calculation logic
* Refactoring and code organization
* Debugging implementation details
* Exploring alternative product flows

The AI-generated code was not used blindly. I reviewed, tested, modified, and integrated the implementation manually to ensure the app’s behavior matched the intended photography workflow.

This project was also an experiment in AI-assisted software development: using Codex not just to generate isolated snippets, but to continuously support product iteration from concept to functional application.

## Tech Highlights

* Mobile camera integration
* Real-time brightness sampling
* Exposure value calculation
* Manual ISO / aperture / shutter mapping
* Calibration-based correction
* Photographer-focused interaction design
* AI-assisted development workflow with Codex

## Limitations

This app works as a reflective light meter, meaning it measures the light reflected from the subject or scene. Like all reflective meters, it can be affected by subject reflectance.

For example:

* Snow or white walls may cause underexposure
* Dark clothing or black surfaces may cause overexposure
* Backlit scenes may require manual exposure compensation
* Incident metering still requires a dedicated light meter or diffuser-based setup

For best results, users should combine the app with gray-card calibration, exposure compensation, and practical film photography judgment.

## Roadmap

* Zone System support
* Multi-point metering
* Incident-metering simulation with diffuser accessory
* Film stock presets
* Calibration profiles per device and camera lens
* Exposure history and shooting notes
* Apple Watch / widget support

## License

This project is for educational and personal photography use.

## iOS 27 兼容性

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
