#!/bin/bash

# LightMeter 构建+启动脚本

set -e  # 遇到错误立即退出

echo "🚀 LightMeter 构建+启动脚本"
echo "=============================="

# 配置
SCHEME="LightMeter"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
BUNDLE_ID="com.yourname.LightMeter"

# 步骤1: 构建
echo ""
echo "🔨 步骤1: 构建项目..."
xcodebuild -project LightMeter.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    build

# 获取构建产物路径
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LightMeter.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ 错误: 找不到 LightMeter.app"
    exit 1
fi

echo "✅ 构建成功: $APP_PATH"

# 步骤2: 启动模拟器
echo ""
echo "📱 步骤2: 启动模拟器..."

# 获取 iPhone 17 Pro 的 UDID
SIMULATOR_UDID=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -oE "[A-F0-9-]{36}" | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "❌ 错误: 找不到 iPhone 17 Pro 模拟器"
    exit 1
fi

echo "找到模拟器: $SIMULATOR_UDID"

# 启动模拟器
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || echo "模拟器已在运行"

# 打开 Simulator 应用
open -a Simulator

echo "✅ 模拟器已启动"

# 步骤3: 安装应用
echo ""
echo "📦 步骤3: 安装应用..."
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
echo "✅ 应用已安装"

# 步骤4: 启动应用
echo ""
echo "🚀 步骤4: 启动应用..."
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" || {
    echo "⚠️ 启动命令失败，但应用已安装"
    echo "请在模拟器中点击 LightMeter 图标手动启动"
}

echo ""
echo "✅ 完成！"
echo "=============================="
echo ""
echo "如果应用没有自动启动，请在 Simulator 中："
echo "1. 点击主屏幕上的 LightMeter 图标"
echo "2. 或按 Cmd+Shift+H 回到主屏幕找到应用"
echo ""
