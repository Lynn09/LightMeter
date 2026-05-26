import Foundation

// 模拟 ExposureCalculator 的方法
let calibrationConstant: Double = 12.5
let referenceEV: Double = 12.5

func brightnessToEV(brightness: Double) -> Double {
    guard brightness > 0 else { return 0 }
    return log2(brightness / calibrationConstant)
}

func evToZone(ev: Double) -> Int {
    let rawZone = Int(round((ev - referenceEV) + 5.0))
    return max(0, min(10, rawZone))
}

// 测试不同亮度值
print("测试亮度到 Zone 的转换:")
print("============================")

let testValues = [0.005, 0.01, 0.03, 0.09, 0.18, 0.36, 0.72, 1.44, 2.88, 5.76, 11.52, 18.0]

for brightness in testValues {
    let ev = brightnessToEV(brightness: brightness)
    let zone = evToZone(ev: ev)
    print(String(format: "brightness: %.3f -> EV: %.2f -> Zone: %d", brightness, ev, zone))
}
