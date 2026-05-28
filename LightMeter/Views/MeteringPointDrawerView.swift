import SwiftUI

// MARK: - Metering Point Drawer View

struct MeteringPointDrawerView: View {
    let points: [MeteringPoint]
    let selectedPointId: UUID?
    @Binding var isExpanded: Bool
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onRemeter: (MeteringPoint) -> Void

    private var selectedPoint: MeteringPoint? {
        MeteringPointDrawerState.selectedPoint(
            from: points,
            selectedPointId: selectedPointId
        )
    }

    var body: some View {
        if !points.isEmpty {
            VStack(spacing: 8) {
                header

                if isExpanded {
                    expandedContent
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text("测光点")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(points.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.9)))

                if let selectedPoint {
                    Circle()
                        .fill(selectedPoint.swiftColor)
                        .frame(width: 8, height: 8)

                    Text("\(selectedPoint.exposureValueLabel) · Zone \(selectedPoint.zoneLabel)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(points) { point in
                        pointChip(point)
                    }
                }
                .padding(.vertical, 1)
            }

            if let selectedPoint {
                HStack(spacing: 10) {
                    Button {
                        onRemeter(selectedPoint)
                    } label: {
                        Label("重新测光", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DrawerActionButtonStyle())

                    Button(role: .destructive) {
                        onDelete(selectedPoint.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DrawerActionButtonStyle(tint: .red, isDestructive: true))
                }
            }
        }
    }

    private func pointChip(_ point: MeteringPoint) -> some View {
        let isSelected = point.id == selectedPoint?.id

        return Button {
            onSelect(point.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(point.swiftColor)
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 1) {
                    Text(point.exposureValueLabel)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))

                    Text("Zone \(point.zoneLabel)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.62))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? point.swiftColor.opacity(0.22) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? point.swiftColor : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DrawerActionButtonStyle: ButtonStyle {
    var tint: Color = .white
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(tint.opacity(isDestructive ? 0.5 : 0.18), lineWidth: 1)
            )
    }
}

#Preview("Metering Point Drawer") {
    ZStack {
        Color.black.ignoresSafeArea()

        MeteringPointDrawerView(
            points: [
                MeteringPoint(x: 0.25, y: 0.3, color: "#34C759", zone: 4, ev: 11.5),
                MeteringPoint(x: 0.7, y: 0.6, color: "#FF9500", zone: 6, ev: 13.6)
            ],
            selectedPointId: nil,
            isExpanded: .constant(true),
            onSelect: { _ in },
            onDelete: { _ in },
            onRemeter: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
