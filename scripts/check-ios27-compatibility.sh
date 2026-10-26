#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
if [[ "${sdk_version%%.*}" -lt 27 ]]; then
    echo "需要 iOS 27 或更新的 SDK。请使用 xcode-select 选择 Xcode 27+。" >&2
    exit 1
fi

derived_data="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/LightMeter-iOS27-compatibility}"
xcodebuild -version
echo "Validating with iOS SDK $sdk_version"

# 同时覆盖模拟器调试构建与真机优化构建；无需签名或连接设备。
xcodebuild -project LightMeter.xcodeproj -scheme LightMeter \
    -configuration Debug -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build

xcodebuild -project LightMeter.xcodeproj -scheme LightMeter \
    -configuration Release -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO build
