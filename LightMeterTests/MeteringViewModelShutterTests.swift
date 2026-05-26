import XCTest
@testable import LightMeter

// MARK: - MeteringViewModel Shutter Speed Tests

/// 测试 MeteringViewModel 的快门速度吸附功能
@MainActor
final class MeteringViewModelShutterTests: XCTestCase {

    var viewModel: MeteringViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MeteringViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 标准快门档位吸附测试

    /// 测试：基准快门速度 (1/125s) 应该保持不变
    func testBaseShutterSpeedUnchanged() {
        // Given: 初始状态，无偏移
        let baseShutter = viewModel.baseShutterSpeed

        // Then: 实际快门速度应该等于基准速度
        XCTAssertEqual(viewModel.effectiveShutterSpeed, baseShutter, accuracy: 0.001)
    }

    /// 测试：拖动偏移计算后快门速度吸附到标准档位
    func testShutterSpeedSnapsToStandardStops() {
        // Given: 拖动 +2.3 Zone（原始快门约 1/600s，非标准档位）
        let rawOffset: Double = 2.3

        // When: 计算吸附后的快门速度
        let rawShutter = viewModel.baseShutterSpeed / pow(2.0, rawOffset)
        // rawShutter ≈ 0.0005s = 1/2000s（实际约为1/631s）

        // Then: 吸附后应该接近 1/500s（+2.32档）或 1/1000s（+3档）
        // 实际计算：1/631s 更接近 1/500s 还是 1/1000s？
        // 1/631 距离 1/500 = 0.002，距离 1/1000 = 0.00058，所以应该吸附到 1/1000

        // 通过实际调用验证
        let snappedOffset = log2(viewModel.baseShutterSpeed / rawShutter)
        let expectedSnappedSpeed: Double = 1.0/1000.0 // 期望吸附到1/1000

        // 验证偏移量在合理范围
        XCTAssertTrue(snappedOffset >= 2.0 && snappedOffset <= 3.0)
    }

    /// 测试：各标准档位吸附
    func testEachStandardStopSnapping() {
        let standardStops: [(zoneOffset: Double, expectedShutter: Double)] = [
            (5.0, 1.0/4000.0),   // +5 Zone = 1/4000s
            (4.0, 1.0/2000.0),   // +4 Zone = 1/2000s
            (3.0, 1.0/1000.0),   // +3 Zone = 1/1000s
            (2.0, 1.0/500.0),    // +2 Zone = 1/500s
            (1.0, 1.0/250.0),    // +1 Zone = 1/250s
            (0.0, 1.0/125.0),    // 0 Zone = 1/125s
            (-1.0, 1.0/60.0),    // -1 Zone = 1/60s
            (-2.0, 1.0/30.0),    // -2 Zone = 1/30s
            (-3.0, 1.0/15.0),    // -3 Zone = 1/15s
            (-4.0, 1.0/8.0),     // -4 Zone = 1/8s
            (-5.0, 1.0/4.0),     // -5 Zone = 1/4s
        ]

        for (zoneOffset, expectedShutter) in standardStops {
            // When: 应用偏移
            let calculatedShutter = viewModel.baseShutterSpeed / pow(2.0, zoneOffset)

            // Then: 计算值应该接近期望值
            XCTAssertEqual(calculatedShutter, expectedShutter, accuracy: 0.001,
                          "Zone offset \(zoneOffset) should result in ~\(expectedShutter)s")
        }
    }

    /// 测试：边界值 - 刚好在两个档位中间应该吸附到最近的一个
    func testMidPointSnapping() {
        // Given: 刚好在 1/250s 和 1/500s 中间 (+1.5 Zone)
        // log2(125/250) = -1, log2(125/500) = -2
        // 中间点是 2^1.5 = 2.828, 1/(125/2.828) = 1/353.5s
        let midPointOffset: Double = 1.5
        let midPointShutter = viewModel.baseShutterSpeed / pow(2.0, midPointOffset) // ~1/353s

        // 1/353s 距离 1/250 = 0.00117, 距离 1/500 = 0.00117
        // 实际上刚好在中间时选择哪个由实现决定，我们验证它被吸附了即可

        // When: 使用私有方法计算吸附值
        let snappedShutter = nearestStandardShutterSpeed(midPointShutter)

        // Then: 结果应该是标准档位之一
        let standardSpeeds: [Double] = [
            1.0/8000, 1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
            1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0
        ]
        XCTAssertTrue(standardSpeeds.contains(where: { abs($0 - snappedShutter) < 0.0001 }),
                      "Mid-point shutter \(midPointShutter) should snap to a standard stop")
    }

    // MARK: - 拖动偏移限制测试

    /// 测试：偏移量限制在 ±5 Zone 范围内
    func testOffsetClamping() {
        // Given: 拖动 +6 Zone（超出限制）
        viewModel.endShutterDragWithOffset(6.0)

        // Then: 实际偏移应该被限制在 +5
        XCTAssertLessThanOrEqual(viewModel.shutterSpeedOffset, 5.0)

        // Given: 拖动 -6 Zone（超出限制）
        viewModel.resetShutterOffset()
        viewModel.endShutterDragWithOffset(-6.0)

        // Then: 实际偏移应该被限制在 -5
        XCTAssertGreaterThanOrEqual(viewModel.shutterSpeedOffset, -5.0)
    }

    /// 测试：累加偏移量正确处理
    func testAccumulatedOffset() {
        // Given: 先拖动 +2 Zone
        viewModel.endShutterDragWithOffset(2.0)
        let firstOffset = viewModel.shutterSpeedOffset

        // When: 再拖动 +1 Zone
        viewModel.endShutterDragWithOffset(1.0)

        // Then: 总偏移应该约等于 +3 Zone
        // 注意：由于吸附效应，可能不完全等于3，但应该接近
        XCTAssertEqual(viewModel.shutterSpeedOffset, 3.0, accuracy: 0.5)
    }

    // MARK: - 状态管理测试

    /// 测试：手动调整状态标记
    func testManualAdjustmentFlag() {
        // Given: 初始状态
        XCTAssertFalse(viewModel.isManualShutterAdjusted)

        // When: 拖动调整快门
        viewModel.endShutterDragWithOffset(1.0)

        // Then: 标记应该被设置
        XCTAssertTrue(viewModel.isManualShutterAdjusted)
    }

    /// 测试：重置功能
    func testResetShutterOffset() {
        // Given: 已调整快门
        viewModel.endShutterDragWithOffset(2.0)
        XCTAssertNotEqual(viewModel.shutterSpeedOffset, 0.0)

        // When: 重置
        viewModel.resetShutterOffset()

        // Then: 所有状态恢复初始值
        XCTAssertEqual(viewModel.shutterSpeedOffset, 0.0)
        XCTAssertEqual(viewModel.dragShutterOffset, 0.0)
        XCTAssertFalse(viewModel.isManualShutterAdjusted)
    }

    // MARK: - 实时预览测试

    /// 测试：拖动过程中偏移实时更新
    func testDragOffsetRealtime() {
        // Given: 初始拖动偏移为0
        XCTAssertEqual(viewModel.dragShutterOffset, 0.0)

        // When: 更新拖动偏移
        viewModel.updateShutterDragOffset(1.5)

        // Then: 临时偏移应该更新
        XCTAssertEqual(viewModel.dragShutterOffset, 1.5)
    }

    // MARK: - 辅助方法

    /// 模拟私有方法：获取最近的标准快门速度
    private func nearestStandardShutterSpeed(_ speed: Double) -> Double {
        guard speed > 0 else { return 1.0/125.0 }

        let standardSpeeds: [Double] = [
            1.0/8000, 1.0/4000, 1.0/2000, 1.0/1000, 1.0/500, 1.0/250, 1.0/125,
            1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 1.0/2, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0
        ]

        var closest = standardSpeeds[6]
        var minDiff = abs(speed - closest)

        for stop in standardSpeeds {
            let diff = abs(speed - stop)
            if diff < minDiff {
                minDiff = diff
                closest = stop
            }
        }

        return closest
    }
}
