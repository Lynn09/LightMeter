#!/usr/bin/env swift
import Foundation

print("验证修复后的曝光计算")
print("=" * 50)

let baseAperture = 8.0
let baseShutter = 1.0/125.0

// 测试：增加曝光 +2 档
let stops = 2.0
let aperture = baseAperture / pow(2.0, stops / 2.0)
let shutter = baseShutter / pow(2.0, stops)

print("基准: f/\(baseAperture), \(baseShutter)s")
print("增加 +\(Int(stops)) 档曝光:")
print("  光圈: f/\(String(format: "%.1f", aperture)) (f值变小，光圈变大)")
print("  快门: \(String(format: "%.4f", shutter))s (变慢)")
print()

// 测试：减少曝光 -2 档
let stops2 = -2.0
let aperture2 = baseAperture / pow(2.0, stops2 / 2.0)
let shutter2 = baseShutter / pow(2.0, stops2)

print("减少 \(Int(stops2)) 档曝光:")
print("  光圈: f/\(String(format: "%.1f", aperture2)) (f值变大，光圈变小)")
print("  快门: \(String(format: "%.4f", shutter2))s (变快)")
