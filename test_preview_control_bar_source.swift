import Foundation

@main
struct PreviewControlBarSourceTest {
    static func main() throws {
        let source = try String(
            contentsOfFile: "LightMeter/Views/CameraPreviewView.swift",
            encoding: .utf8
        )

        precondition(source.contains("previewControlBar"))
        precondition(source.contains("let showsPreviewControls: Bool"))
        precondition(source.contains("if showsPreviewControls"))
        precondition(source.contains("focalLengthOptionsOverlay"))
        precondition(source.contains("freezeButton"))
        precondition(source.contains("focalLengthToggleButton"))
        precondition(source.contains("popoverAnchorTriangle"))
        precondition(source.contains("focalLengthOptionLabel(for:"))
        precondition(!source.contains("FocalLengthRulerPicker"))
        precondition(source.contains("previewControlSlots"))
        precondition(source.contains("static let centerControlWidth: CGFloat"))
        precondition(source.contains("focalLengthToggleButton\n                    .frame(maxWidth: .infinity, alignment: .trailing)"))
        precondition(source.contains("freezeButton\n                .frame(width: Layout.centerControlWidth)"))
        precondition(source.contains("subjectMeteringButton"))
        precondition(source.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        precondition(source.contains("fill(isFocalLengthDrawerExpanded ? Color.white.opacity(0.18) : Color.black.opacity(0.68))"))
        precondition(source.contains("Button {\n                            onFocalLengthSelected(focalLength)"))
        precondition(!source.contains("focalLengthToggleButton\n\n                    freezeButton"))
        precondition(!source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
        precondition(!source.contains("Capsule()\n                        .fill(Color.black.opacity(0.66))"))
        precondition(!source.contains("Spacer(minLength: 0)\n\n                    if isFrameFrozen"))
        precondition(!source.contains("staticFrameControls"))
        precondition(!source.contains("focalLengthControls"))
    }
}
