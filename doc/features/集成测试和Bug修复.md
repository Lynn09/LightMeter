# Feature: 集成测试和Bug修复

## 功能概述

进行全面的集成测试，修复发现的Bug，优化性能。确保所有功能正常工作，无明显Bug，性能流畅，符合设计规范。

## 当前状态

- [ ] 未完成

## 目标

确保应用达到发布标准：
- 所有功能正常工作，无明显Bug
- UI/UX 符合设计规范
- 性能流畅，无明显卡顿
- 可以在真机或模拟器上正常运行

## 相关文件

### 所有已实现的代码
- `LightMeter/App/LightMeterApp.swift`
- `LightMeter/Models/FilmPreset.swift`
- `LightMeter/Models/MeteringPoint.swift`
- `LightMeter/Models/ExposureCalculator.swift`
- `LightMeter/Views/MainMeteringView.swift`
- `LightMeter/Views/TopToolbar.swift`
- `LightMeter/Views/FilmSelectorView.swift`
- `LightMeter/Views/ZoneScaleView.swift`
- `LightMeter/Views/MeteringPointView.swift`
- `LightMeter/Views/PointEditMenuView.swift`
- `LightMeter/Views/ExposureInfoView.swift`
- `LightMeter/Views/CameraPreviewView.swift`
- `LightMeter/ViewModels/MeteringViewModel.swift`

### 设计文档
- `/Users/lyn/Code/light-meter/design.md`
- `/Users/lyn/Code/light-meter/design-tokens.md`
- `/Users/lyn/Code/light-meter/ui-design/*.png`

## 详细任务

### Task 7.1: 功能测试

**测试胶片切换功能**:
- [ ] 点击胶片选择按钮，弹窗正常弹出
- [ ] 选择不同胶片，界面正确更新
- [ ] 切换胶片后，ISO值更新
- [ ] 切换胶片后，11区梯度条的宽容度标记更新
- [ ] 切换胶片后，曝光参数重新计算

**测试添加/删除测光点**:
- [ ] 点击取景画面，添加测光点
- [ ] 测光点显示彩色方框标记
- [ ] 11区梯度条显示测光点标记
- [ ] 最多添加5个测光点，超过时提示
- [ ] 点击测光点弹出编辑菜单
- [ ] 删除测光点后，标记和11区梯度条同步更新
- [ ] 删除测光点后，曝光参数重新计算

**测试重新测光功能**:
- [ ] 点击测光点弹出编辑菜单
- [ ] 点击"重新测光"按钮
- [ ] 测光点的 Zone 和 EV 值更新
- [ ] 11区梯度条的测光点标记更新位置
- [ ] 曝光参数重新计算

**测试曝光计算准确性**:
- [ ] 手动计算曝光参数，验证计算结果
- [ ] 添加不同Zone的测光点，验证曝光调整方向正确
- [ ] 切换胶片，验证ISO更新正确

**测试编辑菜单的弹出和关闭**:
- [ ] 点击测光点，菜单正常弹出
- [ ] 点击遮罩层，菜单关闭
- [ ] 点击关闭按钮，菜单关闭
- [ ] 菜单弹出和关闭动画流畅

### Task 7.2: UI/UX 测试

**检查所有UI元素的布局和样式**:
- [ ] 顶部工具栏高度64pt，胶片按钮和EV显示左右分布
- [ ] 取景区域高度480pt，占满宽度
- [ ] 11区梯度条高度100pt，Zone标签和渐变条正确排列
- [ ] 曝光参数栏高度164pt（含底部安全区），三个参数等分
- [ ] 胶片选择弹窗从底部弹出，高度约502pt
- [ ] 测光点编辑菜单从底部弹出，包含取景预览和操作按钮

**检查颜色、字体、间距是否符合设计规范**:
- [ ] 背景颜色：主背景 #000000，卡片背景 #1C1C1E
- [ ] 文字颜色：主文字 #FFFFFF，次要文字 #8E8E93
- [ ] 强调色：蓝色 #007AFF，绿色 #34C759，橙色 #FF9500，红色 #FF3B30
- [ ] 字体大小：标签11pt，数值28pt，胶片名15pt，EV值20pt
- [ ] 间距：屏幕边距16pt，组件间距12pt，内边距16pt

**检查动画效果是否流畅**:
- [ ] 胶片选择弹窗弹出动画：从底部滑入，0.3s，ease-out
- [ ] 测光点编辑菜单弹出动画：淡入，0.2s
- [ ] 测光点出现动画：缩放从0到1，0.2s
- [ ] 选中状态发光效果：平滑过渡
- [ ] 宽容度标记更新：平滑过渡
- [ ] 测光点标记位置更新：平滑过渡

**检查不同屏幕尺寸的适配**:
- [ ] iPhone 15 Pro (393pt宽度) - 主要设计目标
- [ ] iPhone 14 Pro Max (430pt宽度)
- [ ] iPhone SE 3rd (375pt宽度)
- [ ] 所有UI元素正确缩放和排列
- [ ] 文字不会截断或重叠
- [ ] 触控目标足够大（至少44pt）

### Task 7.3: 性能优化

**优化11区梯度条的渲染性能**:
- [ ] 渐变背景使用 `LinearGradient`，避免频繁重绘
- [ ] 宽容度标记使用 `Rectangle`，缓存位置计算
- [ ] 测光点标记使用 `Circle`，避免复杂形状
- [ ] 使用 `drawingGroup()` 如果必要
- [ ] 避免在 `body` 中创建复杂计算

**优化测光点动画性能**:
- [ ] 使用 `withAnimation` 包裹状态变化
- [ ] 使用 `.animation(.easeInOut(duration: 0.2), value: point.isSelected)`
- [ ] 避免频繁的状态更新
- [ ] 使用 `Equatable` 减少不必要的重绘

**减少不必要的视图重绘**:
- [ ] 使用 `@StateObject` 和 `@ObservedObject` 正确管理状态
- [ ] 使用 `Equatable` 和 `Identifiable` 协议
- [ ] 使用 `.id()` 仅在必要时
- [ ] 避免在循环中创建新对象

**优化内存使用**:
- [ ] 及时释放不再使用的对象
- [ ] 使用 `weak` 和 `unowned` 引用避免循环引用
- [ ] 避免大量图片或资源的缓存
- [ ] 使用 Instruments 检查内存泄漏

### Task 7.4: Bug修复

**修复发现的UI显示问题**:
- [ ] 文字截断问题：增加容器宽度或减小字体
- [ ] 元素重叠问题：调整布局或间距
- [ ] 颜色不准确问题：修正颜色值
- [ ] 对齐问题：使用正确的对齐方式
- [ ] 安全区域问题：正确使用 `.safeAreaInset` 或 `ignoresSafeArea`

**修复计算逻辑错误**:
- [ ] EV计算错误：检查公式 `EV = log2(L/K)`
- [ ] Zone映射错误：检查公式 `Zone = (EV - EV_reference) + 5`
- [ ] 曝光补偿计算错误：检查 `diff = targetZone - currentZone`
- [ ] 光圈计算错误：检查 `aperture = baseAperture * pow(2.0, stops / 2.0)`
- [ ] 快门计算错误：检查快门速度公式

**修复状态管理问题**:
- [ ] 状态不同步：确保所有相关视图使用同一个数据源
- [ ] 状态更新延迟：使用 `@Published` 和 `ObservableObject`
- [ ] 状态丢失：检查视图生命周期和状态保存
- [ ] 循环依赖：检查 View 和 ViewModel 之间的依赖关系

**修复内存泄漏**:
- [ ] 闭包中的循环引用：使用 `[weak self]` 或 `[unowned self]`
- [ ] Timer 或通知未释放：及时 invalidate 和 removeObserver
- [ ] 图片或数据缓存过大：使用合适的缓存策略
- [ ] 使用 Instruments 的 Leaks 工具检测内存泄漏

## 验收标准

- [ ] 所有功能正常工作，无明显Bug
- [ ] UI/UX 符合设计规范
- [ ] 性能流畅，无明显卡顿
- [ ] 通过基本的单元测试（如果有）
- [ ] 可以在真机或模拟器上正常运行

## 依赖

- Task #1 完成
- Task #2 完成
- Task #3 完成
- Task #4 完成
- Task #5 完成
- Task #6 完成

## 阻塞

- 项目发布

## 预估工作量

- 开发时间：4 小时
- 测试时间：2 小时

## 备注

- 这是一个综合性的测试和修复阶段，可能需要反复迭代
- 建议先在模拟器上测试，然后在真机上测试
- 性能优化可以使用 Instruments 工具进行分析和验证
- Bug 修复要记录问题和解决方案，方便后续维护
