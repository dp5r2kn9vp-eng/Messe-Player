import SwiftUI

/// 16:9-Vorschau mit verschiebbaren Ebenen. Nutzt dieselben Bausteine wie der Ausgang.
struct LayerCanvas: View {
    let item: PlayableMedium?
    let layers: [RenderLayer]
    @Binding var selection: Layer.ID?
    /// Startpunkt der Animationsvorschau; `nil` zeigt die Ebenen im Endzustand zum Bearbeiten.
    var animationStart: Date?
    let onMove: (Layer.ID, RelativePoint) -> Void

    @State private var dragStart: RelativePoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let item {
                    MediaView(item: item, isMuted: true)
                } else {
                    Color.black
                }
                AnimationClock(startedAt: animationStart, settlesAfter: LayerAnimation.settlesAfter(layers.map(\.layer.animation))) { time in
                    ForEach(layers) { renderLayer in
                        editableLayer(renderLayer, canvas: geometry.size, time: time)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selection = nil }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func editableLayer(_ renderLayer: RenderLayer, canvas: CGSize, time: TimeInterval?) -> some View {
        let layer = renderLayer.layer
        let isSelected = selection == layer.id
        return LayerView(renderLayer: renderLayer, canvas: canvas, time: time)
            .padding(Theme.Spacing.xs)
            .overlay {
                Rectangle()
                    .stroke(isSelected ? Color.brandOrange : Color.white.opacity(0.25), style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: [6, 4]))
            }
            .contentShape(Rectangle())
            .position(x: layer.position.x * canvas.width, y: layer.position.y * canvas.height)
            .onTapGesture { selection = layer.id }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? layer.position
                        dragStart = start
                        selection = layer.id
                        let moved = start.offset(
                            dx: value.translation.width / canvas.width,
                            dy: value.translation.height / canvas.height
                        )
                        onMove(layer.id, moved)
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }
}
