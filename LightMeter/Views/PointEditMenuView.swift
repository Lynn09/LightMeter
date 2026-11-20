import SwiftUI

// MARK: - PointEditMenuView

/// 测光点编辑菜单视图
struct PointEditMenuView: View {
    @ObservedObject var viewModel: MeteringViewModel
    let point: MeteringPoint
    let onDismiss: () -> Void

    // MARK: - Camera Manager for remetering

    // 从父视图传入的 CameraManager，确保使用同一个实例
    @ObservedObject var cameraManager: CameraManager

    @State private var showingCalibration = false
    @State private var referenceEV = ""
    @State private var calibrationError: String?
    private var displayedPoint: MeteringPoint {
        viewModel.meteringPoints.first { $0.id == point.id } ?? point
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖动条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // 测光点预览
            pointPreview
                .padding(.bottom, 24)

            // 操作按钮
            VStack(spacing: 12) {
                // 重新测光按钮
                menuButton(
                    title: "重新测光",
                    icon: "arrow.counterclockwise",
                    color: .blue
                ) {
                    Task {
                        guard let reading = await cameraManager.meter(at: CGPoint(x: displayedPoint.x, y: displayedPoint.y)) else { return }
                        viewModel.remeterPoint(id: displayedPoint.id, reading: reading)
                    }
                }

                // 删除按钮
                menuButton(
                    title: "删除",
                    icon: "trash",
                    color: .red
                ) {
                    viewModel.deleteMeteringPoint(id: point.id)
                    onDismiss()
                }
            }
            .padding(.horizontal, 20)

            // 测光信息（包含快门速度）
            meteringInfo
                .padding(.top, 24)
                .padding(.bottom, 20)

            if displayedPoint.rawEV100 != nil && displayedPoint.cameraID != nil {
                Button("对照测光表校准") {
                    referenceEV = String(format: "%.2f", displayedPoint.ev)
                    showingCalibration = true
                }
                .font(.system(size: 13))
                .padding(.bottom, 16)
                if let calibrationError { Text(calibrationError).font(.caption).foregroundStyle(.orange) }
            }

            // 提示文字
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("锁定光圈后，每个测光点的快门速度会根据其EV值自动计算")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(Color(hex: "#8E8E93")!)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .alert("对照校准", isPresented: $showingCalibration) {
            TextField("参考 EV100", text: $referenceEV)
                .keyboardType(.numbersAndPunctuation)
            Button("应用") {
                guard let reference = Double(referenceEV.replacingOccurrences(of: ",", with: ".")),
                      let raw = displayedPoint.rawEV100, let cameraID = displayedPoint.cameraID,
                      let offset = cameraManager.calibrate(rawEV100: raw, referenceEV100: reference, cameraID: cameraID) else {
                    calibrationError = "请输入有效 EV100，校准差应在 ±5 档内。"
                    return
                }
                viewModel.applyCalibration(cameraID: cameraID, offset: offset)
                calibrationError = nil
            }
            Button("清除校准") {
                if let cameraID = displayedPoint.cameraID,
                   let offset = cameraManager.calibrate(rawEV100: 0, referenceEV100: 0, cameraID: cameraID) {
                    viewModel.applyCalibration(cameraID: cameraID, offset: offset)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在相同光线下对准同一块灰卡测光，再填入参考测光表的 ISO 100 EV。校准按手机镜头保存。")
        }
    }

    // MARK: - 测光点预览

    private var pointPreview: some View {
        ZStack {
            // 发光效果
            RoundedRectangle(cornerRadius: 8)
                .fill(displayedPoint.swiftColor.opacity(0.3))
                .frame(width: 60, height: 60)
                .blur(radius: 15)

            // 主方框
            RoundedRectangle(cornerRadius: 8)
                .fill(displayedPoint.swiftColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(displayedPoint.swiftColor, lineWidth: 3)
                )

            // 十字准星
            PlusShape()
                .stroke(displayedPoint.swiftColor, lineWidth: 2)
                .frame(width: 30, height: 30)
        }
    }

    // MARK: - 菜单按钮

    private func menuButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 测光信息

    private var meteringInfo: some View {
        VStack(spacing: 12) {
            // 第一行：Zone, EV, 快门
            HStack(spacing: 16) {
                infoItem(label: "Zone", value: displayedPoint.zoneLabel)
                Divider()
                    .background(Color.white.opacity(0.1))
                infoItem(label: "EV100", value: String(format: "%.1f", displayedPoint.ev))
                Divider()
                    .background(Color.white.opacity(0.1))
                // 快门速度（根据当前锁定光圈计算）
                shutterInfoItem
            }
            .frame(height: 50)

            Divider()
                .background(Color.white.opacity(0.1))

            // 第二行：位置信息
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(String(format: "位置: (%.1f%%, %.1f%%)", displayedPoint.x * 100, displayedPoint.y * 100))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    /// 快门信息项（根据锁定光圈计算）
    private var shutterInfoItem: some View {
        let shutterText: String
        let shutterColor: Color

        if let lockedAperture = viewModel.lockedAperture {
            // 计算该测光点在锁定光圈下的快门速度
            // Use the same compensated recommendation as the exposure bar.
            shutterText = displayedPoint.exposureParams?.formattedShutterSpeed
                ?? ExposureCalculator.formatShutterSpeed(ExposureCalculator.calculateShutterForLockedAperture(
                    aperture: lockedAperture, pointEV: displayedPoint.ev, iso: viewModel.selectedFilm.iso))
            shutterColor = Color(hex: "#34C759")! // 绿色表示锁定模式
        } else {
            // 使用当前曝光计算的快门
            shutterText = viewModel.currentExposure.formattedShutterSpeed
            shutterColor = .white
        }

        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isApertureLocked ? "lock.fill" : "stopwatch")
                    .font(.system(size: 9))
                    .foregroundColor(viewModel.isApertureLocked ? Color(hex: "#34C759") : .gray)
                Text(viewModel.isApertureLocked ? "快门*" : "快门")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(viewModel.isApertureLocked ? Color(hex: "#34C759") : .gray)
            }

            Text(shutterText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(shutterColor)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PlusShape

/// 十字准星形状
struct PlusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let lineLength = min(rect.width, rect.height) * 0.3
        let centerX = rect.midX
        let centerY = rect.midY

        // 水平线
        path.move(to: CGPoint(x: centerX - lineLength, y: centerY))
        path.addLine(to: CGPoint(x: centerX + lineLength, y: centerY))

        // 垂直线
        path.move(to: CGPoint(x: centerX, y: centerY - lineLength))
        path.addLine(to: CGPoint(x: centerX, y: centerY + lineLength))

        return path
    }
}
