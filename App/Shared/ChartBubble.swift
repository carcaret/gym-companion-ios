import SwiftUI
import ViewModels

extension View {
    /// El aspecto del bocadillo que sale al tocar una barra o un punto de una gráfica.
    func chartBubble() -> some View {
        monospacedDigit()
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surface2, in: .rect(cornerRadius: Theme.radiusSmall))
            .shadow(color: .black.opacity(0.45), radius: 9, y: 4)
    }

    /// El bocadillo de `selection` se va solo a los 3 s. Cancelado por otro toque, no cierra nada:
    /// el bocadillo que se ve ya es otro (`try?` seguiría adelante y cerraría el nuevo).
    func expiringBubble<Value: Hashable & Sendable>(_ selection: Binding<TapSelection<Value>>) -> some View {
        modifier(ExpiringBubble(selection: selection))
    }
}

private struct ExpiringBubble<Value: Hashable & Sendable>: ViewModifier {
    @Binding var selection: TapSelection<Value>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var duration: Duration { .seconds(3) }

    func body(content: Content) -> some View {
        content.task(id: selection.selected) {
            guard let shown = selection.selected else { return }
            guard (try? await Task.sleep(for: Self.duration)) != nil else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { selection.expire(shown) }
        }
    }
}
