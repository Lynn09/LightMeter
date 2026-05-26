# 胶片测光表应用 Design Tokens

## 概述

基于安塞尔·亚当斯区域曝光法的 iOS 测光表应用设计令牌，采用深色模式设计系统。

---

## 颜色系统 (Colors)

### 主色调

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-primary` | `#007AFF` | 强调色、选中状态、按钮 |
| `--color-primary-20` | `#007AFF20` | 选中状态背景(20%透明度) |

### 背景色

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-bg-primary` | `#000000` | 主背景色 |
| `--color-bg-secondary` | `#1C1C1E` | 次级背景、弹窗、卡片 |
| `--color-bg-tertiary` | `#2C2C2E` | 按钮背景、输入框 |

### 文字色

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-text-primary` | `#FFFFFF` | 主要文字、标题 |
| `--color-text-secondary` | `#8E8E93` | 次要文字、标签、说明 |
| `--color-text-tertiary` | `#6C6C70` | 禁用文字 |

### 测光点颜色

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-metering-1` | `#34C759` | 第1个测光点(阴影/绿色) |
| `--color-metering-2` | `#FF9500` | 第2个测光点(中间调/橙色) |
| `--color-metering-3` | `#FF3B30` | 第3个测光点(高光/红色) |
| `--color-metering-4` | `#5856D6` | 第4个测光点(紫色) |

### 功能色

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-success` | `#34C759` | 成功状态 |
| `--color-warning` | `#FF9500` | 警告状态 |
| `--color-danger` | `#FF3B30` | 危险/删除操作 |
| `--color-info` | `#007AFF` | 信息提示 |

### 中性色

| Token | 值 | 用途 |
|-------|-----|------|
| `--color-border` | `#3A3A3C` | 分隔线、边框 |
| `--color-overlay` | `#00000080` | 遮罩层(50%透明度) |

### Zone系统渐变

```css
--gradient-zone-scale: linear-gradient(90deg,
  #000000 0%,    /* Zone 0 - 纯黑 */
  #1A1A1A 10%,   /* Zone I */
  #333333 20%,   /* Zone II */
  #4D4D4D 30%,   /* Zone III */
  #666666 40%,   /* Zone IV */
  #808080 50%,   /* Zone V - 中性灰 */
  #999999 60%,   /* Zone VI */
  #B3B3B3 70%,   /* Zone VII */
  #CCCCCC 80%,   /* Zone VIII */
  #E6E6E6 90%,   /* Zone IX */
  #FFFFFF 100%   /* Zone X - 纯白 */
);
```

---

## 字体系统 (Typography)

### 字体家族

| Token | 值 | 用途 |
|-------|-----|------|
| `--font-primary` | `Inter, -apple-system, sans-serif` | 主要文字 |
| `--font-mono` | `SF Mono, Monaco, monospace` | 数值显示 |

### 字体大小

| Token | 值 | 用途 |
|-------|-----|------|
| `--font-size-xs` | `10px` | Zone标签 |
| `--font-size-sm` | `11px` | 小标签、ISO/光圈/快门标签 |
| `--font-size-base` | `13px` | 描述文字、胶片特性 |
| `--font-size-md` | `15px` | 胶片名称按钮 |
| `--font-size-lg` | `17px` | 胶片选项名称 |
| `--font-size-xl` | `20px` | 弹窗标题、EV数值 |
| `--font-size-2xl` | `28px` | 曝光参数数值 |

### 字重

| Token | 值 | 用途 |
|-------|-----|------|
| `--font-weight-normal` | `400` | 正文 |
| `--font-weight-medium` | `500` | 按钮文字 |
| `--font-weight-semibold` | `600` | 标题、数值、选中Zone |

---

## 间距系统 (Spacing)

### 基础间距

| Token | 值 | 用途 |
|-------|-----|------|
| `--space-1` | `4px` | 极小间距 |
| `--space-2` | `8px` | 小间距、Zone标签间距 |
| `--space-3` | `12px` | 按钮内边距、元素间距 |
| `--space-4` | `16px` | 标准内边距、屏幕边距 |
| `--space-5` | `20px` | 弹窗内边距 |
| `--space-6` | `24px` | 曝光参数栏间距 |
| `--space-8` | `32px` | 大间距 |

### 组件内边距

| Token | 值 | 用途 |
|-------|-----|------|
| `--padding-screen` | `16px` | 屏幕水平边距 |
| `--padding-button-sm` | `8px 12px` | 小按钮内边距 |
| `--padding-card` | `16px` | 卡片内边距 |
| `--padding-modal` | `20px 16px 40px` | 弹窗内边距 |

---

## 圆角系统 (Border Radius)

| Token | 值 | 用途 |
|-------|-----|------|
| `--radius-sm` | `4px` | 小元素、测光点方框 |
| `--radius-md` | `8px` | 按钮、卡片 |
| `--radius-lg` | `12px` | 胶片选项、编辑按钮 |
| `--radius-xl` | `16px` | 关闭按钮 |
| `--radius-2xl` | `20px` | 弹窗 |
| `--radius-full` | `9999px` | 圆形元素、测光点标记 |

---

## 尺寸系统 (Sizing)

### 元素高度

| Token | 值 | 用途 |
|-------|-----|------|
| `--height-toolbar` | `64px` | 顶部工具栏 |
| `--height-camera` | `480px` | 取景区域 |
| `--height-zone-scale` | `100px` | 11区梯度条 |
| `--height-exposure-bar` | `164px` | 曝光参数栏(含安全区) |
| `--height-button-sm` | `36px` | 小按钮 |
| `--height-button-md` | `44px` | 标准按钮 |
| `--height-list-item` | `80px` | 胶片选项高度 |

### 元素宽度

| Token | 值 | 用途 |
|-------|-----|------|
| `--width-screen` | `393px` | iPhone标准宽度 |
| `--width-metering-point` | `40px` | 测光点标记大小 |
| `--width-zone-marker` | `16px` | Zone条上的标记点 |

---

## 阴影与效果 (Effects)

### 阴影

| Token | 值 | 用途 |
|-------|-----|------|
| `--shadow-modal` | `0 -4px 20px rgba(0,0,0,0.3)` | 弹窗阴影 |
| `--shadow-metering-point` | `0 0 10px rgba(255,255,255,0.3)` | 测光点发光效果 |

### 描边

| Token | 值 | 用途 |
|-------|-----|------|
| `--stroke-metering-point` | `3px` | 测光点方框线宽 |
| `--stroke-selected` | `4px` | 选中测光点线宽 |
| `--stroke-latitude` | `2px` | 宽容度标记线宽 |

---

## 动画与过渡 (Animation)

| Token | 值 | 用途 |
|-------|-----|------|
| `--duration-fast` | `200ms` | 快速过渡、测光点出现 |
| `--duration-normal` | `300ms` | 标准过渡 |
| `--easing-default` | `ease-out` | 默认缓动 |
| `--easing-spring` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | 弹性动画 |

---

## 布局结构 (Layout)

### 主屏幕结构

```
┌─────────────────────────────┐  ← 顶部工具栏 (64pt)
│ [胶片选择]          EV: XX  │
├─────────────────────────────┤  ← 取景区域 (480pt)
│                             │
│      [摄像头预览]           │
│      ┌─┐ ┌─┐ ┌─┐           │  ← 测光点标记
│      └─┘ └─┘ └─┘           │
├─────────────────────────────┤  ← 11区梯度条 (100pt)
│  0 I II III IV V VI...     │
│  ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░    │
├─────────────────────────────┤  ← 曝光参数栏 (164pt)
│   f/X  1/XXXs  ISO XXX      │
└─────────────────────────────┘
```

### 屏幕总高度

- iPhone 14 Pro: 852pt
- 顶部安全区: 44pt
- 底部安全区: 34pt

---

## 胶片预设 Token

### Velvia 50

```json
{
  "id": "velvia-50",
  "name": "Velvia 50",
  "color": "#007AFF",
  "latitude": { "min": 4, "max": 8 },
  "description": "Zone IV-VIII · 高饱和度 · 易过曝"
}
```

### Provia 100F

```json
{
  "id": "provia-100f",
  "name": "Provia 100F",
  "color": "#5856D6",
  "latitude": { "min": 3, "max": 8 },
  "description": "Zone III-VIII · 通用型 · 肤色好"
}
```

### Ektachrome

```json
{
  "id": "ektachrome",
  "name": "Ektachrome",
  "color": "#FF9500",
  "latitude": { "min": 3, "max": 7 },
  "description": "Zone III-VII · 细腻颗粒 · 风光"
}
```

---

## CSS 变量汇总

```css
:root {
  /* Colors */
  --color-primary: #007AFF;
  --color-bg-primary: #000000;
  --color-bg-secondary: #1C1C1E;
  --color-bg-tertiary: #2C2C2E;
  --color-text-primary: #FFFFFF;
  --color-text-secondary: #8E8E93;
  --color-metering-1: #34C759;
  --color-metering-2: #FF9500;
  --color-metering-3: #FF3B30;
  --color-danger: #FF3B30;
  --color-border: #3A3A3C;

  /* Typography */
  --font-primary: Inter, -apple-system, sans-serif;
  --font-mono: SF Mono, Monaco, monospace;
  --font-size-xs: 10px;
  --font-size-sm: 11px;
  --font-size-base: 13px;
  --font-size-md: 15px;
  --font-size-lg: 17px;
  --font-size-xl: 20px;
  --font-size-2xl: 28px;
  --font-weight-semibold: 600;

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;

  /* Border Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-2xl: 20px;

  /* Sizing */
  --height-toolbar: 64px;
  --height-camera: 480px;
  --height-zone-scale: 100px;
  --width-screen: 393px;

  /* Animation */
  --duration-fast: 200ms;
  --duration-normal: 300ms;
  --easing-default: ease-out;
}
```

---

## 版本

- **Version**: 1.0
- **Created**: 2025-01-22
- **Platform**: iOS
- **Design Tool**: Pencil
