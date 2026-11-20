import SwiftUI

struct PointEditMenuView: View {
    @ObservedObject var viewModel: MeteringViewModel
    let point: MeteringPoint
    @ObservedObject var cameraManager: CameraManager
    @State private var showingCalibration = false
    @State private var referenceEV = ""
    @State private var calibrationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle().fill(point.swiftColor).frame(width: 8, height: 8)
                Text("点测 · \(point.zoneLabel)")
                Spacer()
                Button("重测") {
                    Task {
                        guard let reading = await cameraManager.meter(at: CGPoint(x: point.x, y: point.y)) else { return }
                        viewModel.remeterPoint(id: point.id, reading: reading)
                    }
                }
                .disabled(cameraManager.isMetering)
                if point.rawEV100 != nil && point.cameraID != nil {
                    Button("校准") {
                        referenceEV = String(format: "%.2f", point.ev)
                        showingCalibration = true
                    }
                }
                Button(role: .destructive) {
                    viewModel.deleteMeteringPoint(id: point.id)
                } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }
                .accessibilityLabel("删除测光点")
            }
            .buttonStyle(.borderless)
            if let calibrationError { Text(calibrationError).foregroundStyle(.orange) }
        }
        .alert("对照校准", isPresented: $showingCalibration) {
            TextField("参考 EV100", text: $referenceEV)
                .keyboardType(.numbersAndPunctuation)
            Button("应用") {
                guard let reference = Double(referenceEV.replacingOccurrences(of: ",", with: ".")),
                      let raw = point.rawEV100, let cameraID = point.cameraID,
                      let offset = cameraManager.calibrate(rawEV100: raw, referenceEV100: reference, cameraID: cameraID) else {
                    calibrationError = "请输入有效 EV100，校准差应在 ±5 档内。"
                    return
                }
                viewModel.applyCalibration(cameraID: cameraID, offset: offset)
                calibrationError = nil
            }
            Button("清除校准") {
                if let cameraID = point.cameraID,
                   let offset = cameraManager.calibrate(rawEV100: 0, referenceEV100: 0, cameraID: cameraID) {
                    viewModel.applyCalibration(cameraID: cameraID, offset: offset)
                    calibrationError = nil
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在相同光线下对准同一块灰卡测光，再填入参考测光表的 ISO 100 EV。校准按手机镜头保存。")
        }
    }

}
