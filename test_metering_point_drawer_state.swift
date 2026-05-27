import Foundation

@main
struct MeteringPointDrawerStateTest {
    static func main() {
        let firstID = UUID()
        let secondID = UUID()
        let points = [
            MeteringPoint(id: firstID, x: 0.2, y: 0.2, color: "#34C759", zone: 4, ev: 11.5),
            MeteringPoint(id: secondID, x: 0.8, y: 0.8, color: "#FF9500", zone: 6, ev: 13.5)
        ]

        precondition(MeteringPointDrawerState.selectedPoint(from: points, selectedPointId: secondID)?.id == secondID)
        precondition(MeteringPointDrawerState.selectedPoint(from: points, selectedPointId: UUID())?.id == firstID)
        precondition(MeteringPointDrawerState.selectedPoint(from: [], selectedPointId: firstID) == nil)
    }
}
