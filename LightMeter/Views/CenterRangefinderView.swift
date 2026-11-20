import SwiftUI

struct CenterRangefinderView: View {
    let isLocked: Bool

    var body: some View {
        ZStack {
            Rectangle().frame(width: 28, height: 2)
            Rectangle().frame(width: 2, height: 28)
        }
        .foregroundStyle(isLocked ? Color.orange : .white)
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DistanceControls: View {
    let reading: RangefinderReading
    let status: String
    let isSupported: Bool
    let onToggleLock: () -> Void

    private var tint: Color { reading.isLocked ? .orange : .white.opacity(0.9) }
    private var distanceText: String {
        reading.meters.map { String(format: "%.2f m", $0) } ?? "— m"
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(distanceText)
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                Text(reading.isLocked ? "距离已锁定" : (reading.meters == nil ? status : "实时测距"))
                    .font(.system(size: 11))
                    .foregroundStyle(tint.opacity(0.75))
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            Button(action: onToggleLock) {
                Label(reading.isLocked ? "解锁" : "锁定",
                      systemImage: reading.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isSupported || (reading.meters == nil && !reading.isLocked))
            .accessibilityLabel(reading.isLocked ? "解锁测距" : "锁定测距")
            .accessibilityHint("锁定当前距离，再次点击恢复实时测距")
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.2), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
    }
}
