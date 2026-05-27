import Foundation

// MARK: - Metering Point Drawer State

enum MeteringPointDrawerState {
    static func selectedPoint(
        from points: [MeteringPoint],
        selectedPointId: UUID?
    ) -> MeteringPoint? {
        guard !points.isEmpty else { return nil }

        if let selectedPointId,
           let point = points.first(where: { $0.id == selectedPointId }) {
            return point
        }

        return points.first
    }
}
