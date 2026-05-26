#!/usr/bin/env swift

import Foundation

// 测试 Zone 计算逻辑

let calibrationConstant: Double = 12.5
let referenceEV: Double = log2(0.18 / 12.5)

print("参考 EV (Zone V): \(referenceEV)")
print()

func brightnessToEV(brightness: Double) -> Double {
    guard brightness > 0 else { return 0 }
    return log2(brightness / calibrationConstant)
}

func evToZone(ev: Double) -> Int {
    let rawZone = Int(round((ev - referenceEV) + 5.0))
    return max(0, min(10, rawZone))
}

// 测试不同 Zone 的亮度值
print("Zone 到亮度的映射验证:")
print(String(repeating: "-", count: 60))

for zone in 0...10 {
    // 从 Zone 计算亮度
    let brightness = 0.18 * pow(2.0, Double(zone) - 5.0)

    // 从亮度计算回 Zone
    let ev = brightnessToEV(brightness: brightness)
    let calculatedZone = evToZone(ev: ev)

    let match = zone == calculatedZone ? "✓" : "✗"
    print("Zone \(String(format: "%2d", zone)): brightness = \(String(format: "%7.4f", brightness)), EV = \(String(format: "%6.2f", ev)), 计算 Zone = \(calculatedZone) \(match)")
}

print()
print("前景/天空亮度值验证:")
print(String(repeating: "-", count: 60))

// 前景：Zone III
let foregroundZone = 3
let foregroundBrightness = 0.18 * pow(2.0, Double(foregroundZone) - 5.0)
let foregroundEV = brightnessToEV(brightness: foregroundBrightness)
let foregroundCalculatedZone = evToZone(ev: foregroundEV)

print("前景 (Zone \(foregroundZone)):")
print("  亮度: \(String(format: "%.4f", foregroundBrightness))")
print("  EV: \(String(format: "%.2f", foregroundEV))")
print("  计算 Zone: \(foregroundCalculatedZone)")
print()

// 天空：Zone VIII
let skyZone = 8
let skyBrightness = 0.18 * pow(2.0, Double(skyZone) - 5.0)
let skyEV = brightnessToEV(brightness: skyBrightness)
let skyCalculatedZone = evToZone(ev: skyEV)

print("天空 (Zone \(skyZone)):")
print("  亮度: \(String(format: "%.4f", skyBrightness))")
print("  EV: \(String(format: "%.2f", skyEV))")
print("  计算 Zone: \(skyCalculatedZone)")
