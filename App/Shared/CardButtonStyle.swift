import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Una tarjeta que se toca entera (rutinas de Hoy, sesiones del Historial): al apoyar el dedo, un
/// círculo blanco nace donde se toca y crece hasta los bordes, y la tarjeta se encoge un pelín; al
/// soltar, el círculo se desvanece. La acción espera a que el círculo llene la tarjeta: en una
/// `List`, un toque rápido no llega a marcar el botón como pulsado y la pantalla cambiaba antes de
/// que se viera nada. Todo se pinta según la hora (`TimelineView`), sin `withAnimation`: en una fila
/// de `List` el cambio de la pulsación llega sin animación y el círculo salía ya entero (vídeo del
/// CI, 2026-10-27). El label ya lleva su `.card()`.
struct CardButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableCard(configuration: configuration)
    }
}

extension PrimitiveButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}

private struct PressableCard: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    /// Dónde apoyó el dedo por última vez, en la ventana.
    @State private var touch: CGPoint?
    /// El círculo en curso: dónde nació (en la ventana), cuándo y cuándo se soltó.
    @State private var ripple: Ripple?
    /// Cuenta las pulsaciones, para que el final de un desvanecido no borre el círculo de la siguiente.
    @State private var presses = 0

    private struct Ripple {
        var origin: CGPoint?
        var startedAt: Date
        var releasedAt: Date?
    }

    private static let growDuration = 0.2
    private static let fadeDuration = 0.3
    private static let pressedScale = 0.985

    var body: some View {
        Button(action: tap) {
            TimelineView(.animation(paused: ripple == nil)) { timeline in
                let state = RippleState(ripple, at: timeline.date, reduceMotion: reduceMotion)
                configuration.label
                    .overlay { circle(state) }
                    .clipShape(.rect(cornerRadius: Theme.radius))
                    .scaleEffect(1 - (1 - Self.pressedScale) * state.pressed)
            }
            .gesture(TouchDownLocation { touch = $0 })
        }
        .buttonStyle(PressState(isPressed: $isPressed))
        .onChange(of: isPressed) { _, pressed in
            if pressed { press() } else { release() }
        }
    }

    /// Lo que se pinta en un instante: lo que ha crecido el círculo, lo que queda de él y lo
    /// encogida que está la tarjeta (0…1 los tres).
    private struct RippleState {
        var origin: CGPoint?
        var growth = 0.0
        var veil = 0.0
        var pressed = 0.0

        init(_ ripple: Ripple?, at date: Date, reduceMotion: Bool) {
            guard let ripple else { return }
            origin = ripple.origin
            let elapsed = date.timeIntervalSince(ripple.startedAt)
            growth = reduceMotion ? 1 : Self.easeOut(elapsed / PressableCard.growDuration)
            guard let releasedAt = ripple.releasedAt else {
                veil = 1
                pressed = reduceMotion ? 0 : Self.easeOut(elapsed / PressableCard.growDuration)
                return
            }
            // El desvanecido empieza cuando el círculo ha llenado la tarjeta.
            let fadeStart = max(releasedAt, ripple.startedAt.addingTimeInterval(PressableCard.growDuration))
            let fade = Self.easeOut(date.timeIntervalSince(fadeStart) / PressableCard.fadeDuration)
            veil = 1 - fade
            pressed = reduceMotion ? 0 : (1 - Self.easeOut(date.timeIntervalSince(releasedAt) / PressableCard.fadeDuration))
                * Self.easeOut(releasedAt.timeIntervalSince(ripple.startedAt) / PressableCard.growDuration)
        }

        private static func easeOut(_ progress: Double) -> Double {
            let t = min(max(progress, 0), 1)
            return 1 - (1 - t) * (1 - t)
        }
    }

    /// El marco se lee al pintar, sin guardarlo: guardarlo en un estado mientras la tarjeta se
    /// encoge volvía a pintarla sin parar.
    private func circle(_ state: RippleState) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            // Sin el dedo dentro de la tarjeta (VoiceOver), el círculo nace en el centro.
            let center = state.origin.flatMap { point in
                frame.insetBy(dx: -1, dy: -1).contains(point) ? CGPoint(x: point.x - frame.minX, y: point.y - frame.minY) : nil
            } ?? CGPoint(x: frame.width / 2, y: frame.height / 2)
            // El radio llega a la esquina más lejana del dedo.
            let radius = [CGPoint.zero, CGPoint(x: frame.width, y: 0), CGPoint(x: 0, y: frame.height), CGPoint(x: frame.width, y: frame.height)]
                .map { hypot($0.x - center.x, $0.y - center.y) }
                .max() ?? 0
            Circle()
                .fill(Color.white.opacity(0.12 * state.veil))
                .frame(width: radius * 2 * state.growth, height: radius * 2 * state.growth)
                .position(center)
        }
        .allowsHitTesting(false)
    }

    /// Lo que le falta al círculo para llenar la tarjeta.
    private var remaining: Double {
        guard let ripple else { return 0 }
        return max(0, Self.growDuration - Date.now.timeIntervalSince(ripple.startedAt))
    }

    private func press() {
        guard ripple == nil || ripple?.releasedAt != nil else { return }
        presses += 1
        ripple = Ripple(origin: touch, startedAt: .now)
    }

    /// Un toque rápido suelta antes de que el círculo llegue a los bordes: el desvanecido espera.
    private func release() {
        guard var current = ripple, current.releasedAt == nil else { return }
        current.releasedAt = .now
        ripple = current
        let press = presses
        let end = remaining + Self.fadeDuration
        Task {
            try? await Task.sleep(for: .seconds(end))
            if press == presses { ripple = nil }
        }
    }

    private func tap() {
        // En una `List`, un toque rápido llega sin haber marcado la pulsación: no hay círculo, o
        // es el de una pulsación anterior que se soltó hace rato (al desplazar la lista).
        let isStale = ripple.map { ripple in ripple.releasedAt.map { Date.now.timeIntervalSince($0) > 0.1 } ?? false } ?? true
        if isStale { press() }
        release()
        let wait = remaining
        if wait > 0 {
            Task {
                try? await Task.sleep(for: .seconds(wait))
                configuration.trigger()
            }
        } else {
            configuration.trigger()
        }
    }
}

/// Pasa al `PressableCard` si el botón está pulsado (en una `List`, el sistema lo marca tarde o
/// no lo marca, según lo rápido que sea el toque).
private struct PressState: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in isPressed = pressed }
    }
}

/// Dónde apoya el dedo, en la ventana. El reconocedor falla nada más empezar: así no compite con
/// el botón, el desplazamiento ni los gestos de la lista.
private struct TouchDownLocation: UIGestureRecognizerRepresentable {
    let action: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> TouchDownRecognizer {
        let recognizer = TouchDownRecognizer()
        recognizer.action = action
        recognizer.cancelsTouchesInView = false
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TouchDownRecognizer, context: Context) {
        recognizer.action = action
    }
}

private final class TouchDownRecognizer: UIGestureRecognizer {
    var action: (CGPoint) -> Void = { _ in }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first { action(touch.location(in: nil)) }
        state = .failed
    }
}
