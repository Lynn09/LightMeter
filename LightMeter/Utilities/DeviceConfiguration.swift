import SwiftUI

// MARK: - iPhone 16 Pro 设备配置

/// iPhone 16 Pro 屏幕规格
enum iPhone16ProConfig {
    /// 屏幕宽度（点）
    static let screenWidth: CGFloat = 402

    /// 屏幕高度（点）
    static let screenHeight: CGFloat = 874

    /// 安全区域顶部边距（Dynamic Island）
    static let safeAreaTop: CGFloat = 59

    /// 安全区域底部边距
    static let safeAreaBottom: CGFloat = 34

    /// 灵动岛高度
    static let dynamicIslandHeight: CGFloat = 37

    /// 灵动岛宽度
    static let dynamicIslandWidth: CGFloat = 126

    /// 屏幕圆角半径
    static let screenCornerRadius: CGFloat = 55
}

// MARK: - iOS 26+ 特性检测

/// iOS 26+ 新特性可用性检测
@available(iOS 26.0, *)
enum iOS26Features {

    /// 检查是否支持新的 SwiftUI 特性
    static var supportsNewSwiftUIFeatures: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// 检查 Metal 3 支持
    static var supportsMetal3: Bool {
        // iPhone 16 Pro 支持 Metal 3
        return true
    }
}

// MARK: - 设备类型检测

/// 设备类型工具
enum DeviceType {

    /// 是否是 iPhone 16 Pro
    static var isiPhone16Pro: Bool {
        #if os(iOS)
        let screenSize = UIScreen.main.bounds.size
        // iPhone 16 Pro: 402 x 874 points
        let isProSize = abs(screenSize.width - 402) < 1 && abs(screenSize.height - 874) < 1
        return isProSize
        #else
        return false
        #endif
    }

    /// 是否是带灵动岛的设备
    static var hasDynamicIsland: Bool {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            // iOS 26+ 的检测方式
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first { $0.isKeyWindow }

            let topInset = keyWindow?.safeAreaInsets.top ?? 0
            // 灵动岛设备的 top inset 大于 50
            return topInset > 50
        }
        return false
        #else
        return false
        #endif
    }

    /// 屏幕安全区域边距
    static var safeAreaInsets: EdgeInsets {
        #if os(iOS)
        let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene
        let insets = scene?.windows.first?.safeAreaInsets ?? .zero
        return EdgeInsets(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
        #else
        return EdgeInsets()
        #endif
    }
}

// MARK: - SwiftUI View 扩展

extension View {

    /// 应用 iPhone 16 Pro 安全区域边距
    func iPhone16ProSafeArea() -> some View {
        self.safeAreaInset(edge: .top, spacing: iPhone16ProConfig.safeAreaTop) {
            EmptyView()
        }
        .safeAreaInset(edge: .bottom, spacing: iPhone16ProConfig.safeAreaBottom) {
            EmptyView()
        }
    }

    /// 条件修饰符
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - 预览配置

#Preview("iPhone 16 Pro") {
    if #available(iOS 26.0, *) {
        Text("iPhone 16 Pro 预览")
            .frame(width: iPhone16ProConfig.screenWidth,
                   height: iPhone16ProConfig.screenHeight)
    } else {
        Text("需要 iOS 26+")
    }
}
