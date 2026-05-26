import SwiftUI

// MARK: - Light Meter App

/// 应用入口
@main
struct LightMeterApp: App {

    var body: some Scene {
        WindowGroup {
            MainMeteringView()
                .preferredColorScheme(.dark)
        }
    }
}