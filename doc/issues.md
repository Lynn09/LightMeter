# LightMeter 问题记录

## 问题 #1：应用崩溃 - 缺少相机权限描述（NSCameraUsageDescription）

### 问题概述
应用在启动时崩溃，控制台报错：
```
This app has crashed because it attempted to access privacy-sensitive data without a usage description.
The app's Info.plist must contain an NSCameraUsageDescription key with a string value explaining to the user how the app uses this data.
```

### 根本原因
项目使用 XcodeGen 管理，需要在 `project.yml` 的 `info.properties` 中配置权限描述，直接修改 `Info.plist` 会被覆盖。

### 修复状态：✅ 已修复

### 修复方案

1. **修改 `project.yml`** 添加相机权限描述：
```yaml
info:
  path: LightMeter/Info.plist
  properties:
    NSCameraUsageDescription: "LightMeter 需要访问您的相机来进行实时测光。相机画面仅用于曝光分析和测光点标记，不会被保存或上传到任何地方。"
```

2. **重新生成 Xcode 项目**：
```bash
xcodegen generate
```

3. **验证 `Info.plist`**：
```bash
grep "NSCameraUsageDescription" LightMeter/Info.plist
```

**输出结果**：
```xml
<key>NSCameraUsageDescription</key>
<string>LightMeter 需要访问您的相机来进行实时测光。相机画面仅用于曝光分析和测光点标记，不会被保存或上传到任何地方。</string>
```

### 验证结果
- ✅ `NSCameraUsageDescription` 已添加到 `Info.plist`
- ✅ 项目构建成功（**BUILD SUCCEEDED**）
- ✅ 应用现在应该可以在真机上正常运行，首次启动时会显示相机权限请求对话框

---

## 问题 #2：应用未使用真实摄像头

### 问题概述
应用在真机上运行时显示的是模拟背景（渐变天空和山峰剪影），而不是调用真实摄像头。

### 修复状态：✅ 已完成

### 已实施的修复

1. **创建 CameraManager** (`LightMeter/Managers/CameraManager.swift`)
   - 管理 `AVCaptureSession`
   - 处理相机权限请求
   - 提供相机预览层 (`AVCaptureVideoPreviewLayer`)
   - 支持开始/停止相机会话

2. **重写 CameraPreviewView** (`LightMeter/Views/CameraPreviewView.swift`)
   - 使用 `UIViewRepresentable` 包装 `AVCaptureVideoPreviewLayer`
   - 连接 `CameraManager` 的会话
   - 完全移除模拟视图代码
   - 添加权限请求 UI

---

## 问题 #3：相机预览显示 16:9 比例且两侧有黑条

### 问题概述
应用在真机上运行时，相机预览显示为 16:9 比例，左右两侧出现黑条，没有填满整个预览区域。

### 根本原因
`VideoPreviewView` 类声明了 `configureVideoGravity()` 方法并在初始化时被调用，但方法体没有实现，导致 `AVCaptureVideoPreviewLayer` 使用默认的 `videoGravity` 而非 `.resizeAspectFill`。

### 修复状态：✅ 已修复

### 修复方案
在 `CameraPreviewView.swift` 第 158 行的 `VideoPreviewView` 类中添加 `configureVideoGravity()` 方法实现：

```swift
/// 配置视频重力为填满模式
func configureVideoGravity() {
    videoPreviewLayer.videoGravity = .resizeAspectFill
}
```

---

## 问题 #4：点击取景框没有进行测光

### 问题概述
用户点击相机预览区域时，没有任何反应，测光点没有被添加。

### 根本原因
`CameraPreviewView` 设置了 `.contentShape(Rectangle())` 来定义点击区域，但没有添加 `.onTapGesture` 修饰符来实际捕获点击事件。`onTap` 回调虽然已经定义并传递给视图，但因为没有添加手势识别器，点击事件永远不会被触发。

### 修复状态：✅ 已修复

### 修复方案
在 `CameraPreviewView.swift` 第 50 行 `contentShape` 修饰符后添加点击手势识别：

```swift
.contentShape(Rectangle())
.onTapGesture { location in
    onTap(location)
}
```

---

## 问题 #5：测光点不在取景框内展示，测光点聚集在 Zone 最左端

### 问题概述
调用原生相机取景时，点击测光后：
1. 取景框内**没有任何测光点标记**（彩色方框）显示
2. **Zone 梯度条上的测光点标记**全部聚集在**最左端**（Zone 0 附近）

### 根本原因
这是一个**坐标系统不一致**的问题：

1. **`CameraPreviewView` 传递的是绝对像素坐标**（如 x: 150, y: 200，表示距离视图左边缘 150 像素，上边缘 200 像素）

2. **`MeteringPoint` 直接存储这些绝对坐标值**，没有进行归一化处理

3. **`MeteringPointView` 却将这些值当作归一化坐标 (0~1) 来处理**：
   ```swift
   .position(
       x: point.x * containerSize.width,  // 如果 point.x = 150, width = 393, 结果就是 58950!
       y: point.y * containerSize.height
   )
   ```

4. **为什么 Zone 梯度条上的点聚集在左端**：
   - `ZoneScaleView` 使用 `point.zone` 值来计算位置
   - 如果 Zone 值被错误计算或限制在 0-10 范围内，且由于某些原因导致所有点都被映射到 Zone 0 附近，就会聚集在左端
   - 实际上，问题可能是 `evToZone` 函数返回了错误的值，或者 `point.zone` 被错误地设置

### 修复方案

**在 `CameraPreviewView` 中归一化坐标**，确保传递给 `onTap` 的坐标已经是 0~1 范围。

需要在 `CameraPreviewView` 的 `GeometryReader` 中获取视图尺寸，然后将点击坐标除以尺寸得到归一化坐标。

### 修复状态：🔧 待修复

### 修复步骤

1. **修改 `CameraPreviewView.swift`**：
   - 在 `GeometryReader` 中获取 `geometry.size`
   - 将点击坐标除以尺寸，转换为 0~1 范围的归一化坐标
   - 将归一化坐标传递给 `onTap` 回调

2. **修改 `MeteringPointView.swift`**（验证坐标使用）：
   - 确认 `MeteringPointView` 将归一化坐标乘以 `containerSize` 来计算显示位置

3. **测试验证**：
   - 点击相机预览区域的不同位置
   - 验证测光点标记（彩色方框）出现在正确的位置
   - 验证 Zone 梯度条上的测光点标记出现在正确的 Zone 位置

---

## 修复总结

| 问题 | 状态 | 修复文件 | 说明 |
|------|------|----------|------|
| 相机权限描述 | ✅ 修复 | `project.yml` | 已配置 NSCameraUsageDescription |
| 真实摄像头实现 | ✅ 完成 | `CameraManager.swift`, `CameraPreviewView.swift` | CameraManager 和 CameraPreviewView 已实现 |
| 相机 16:9 黑条问题 | ✅ 修复 | `CameraPreviewView.swift` | 添加了 `configureVideoGravity()` 实现 |
| 点击无法测光 | ✅ 修复 | `CameraPreviewView.swift` | 添加了 `.onTapGesture` 修饰符 |
| 测光点不在取景框内 | 🔧 待修复 | `CameraPreviewView.swift` | 需要将点击坐标归一化为 0~1 范围 |

---

*最后更新: 2026-04-27*
