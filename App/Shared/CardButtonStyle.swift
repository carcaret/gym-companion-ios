import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Una tarjeta que se toca entera (rutinas de Hoy, sesiones del Historial): al apoyar el dedo, un
/// círculo blanco nace donde se toca y crece hasta los bordes, y la tarjeta se encoge un pelín; al
/// soltar, el círculo se desvanece. La acción espera a que el círculo llene la tarjeta: en una
/// `List`, un toque rápido no llega a marcar el botón como pulsado y la pantalla cambiaba antes de
/// que se viera nada (2026-10-27). El label ya lleva su `.card()`.
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
    /// Dónde apoyó el dedo por última vez y dónde nació el círculo, los dos en la ventana.
    @State private var touch: CGPoint?
    @State private var origin: CGPoint?
    /// Lo que ha crecido el círculo (0…1) y lo que queda de él (0…1).
    @State private var growth: CGFloat = 0
    @State private var veil: Double = 0
    @State private var startedAt = Date.distantPast
    /// La pulsación en curso ya tiene su círculo.
    @State private var hasRipple = false
    /// Cuenta las pulsaciones, para que el final de un desvanecido no borre el círculo de la siguiente.
    @State private var presses = 0

    private static let growDuration = 0.2
    private static let fadeDuration = 0.3

    var body: some View {
        Button(action: tap) {
            configuration.label
                .overlay { ripple }
                .clipShape(.rect(cornerRadius: Theme.radius))
                .gesture(TouchDownLocation { touch = $0 })
        }
        .buttonStyle(PressState(isPressed: $isPressed))
        .animation(.easeOut(duration: Self.growDuration)) {
            $0.scaleEffect(isPressed && !reduceMotion ? 0.985 : 1)
        }
        .onChange(of: isPressed) { _, pressed in
            if pressed { press() } else { release() }
        }
    }

    /// El marco se lee al pintar, sin guardarlo: guardarlo en un estado mientras la tarjeta se
    /// encoge volvía a pintarla sin parar.
    private var ripple: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            // Sin el dedo dentro de la tarjeta (VoiceOver), el círculo nace en el centro.
            let center = origin.flatMap { point in
                frame.insetBy(dx: -1, dy: -1).contains(point) ? CGPoint(x: point.x - frame.minX, y: point.y - frame.minY) : nil
            } ?? CGPoint(x: frame.width / 2, y: frame.height / 2)
            // El radio llega a la esquina más lejana del dedo.
            let radius = [CGPoint.zero, CGPoint(x: frame.width, y: 0), CGPoint(x: 0, y: frame.height), CGPoint(x: frame.width, y: frame.height)]
                .map { hypot($0.x - center.x, $0.y - center.y) }
                .max() ?? 0
            Circle()
                .fill(Color.white.opacity(0.12 * veil))
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(growth)
                .position(center)
        }
        .allowsHitTesting(false)
    }

    /// Lo que le falta al círculo para llenar la tarjeta.
    private var remaining: Double {
        max(0, Self.growDuration - Date.now.timeIntervalSince(startedAt))
    }

    private func press() {
        guard !hasRipple else { return }
        hasRipple = true
        presses += 1
        startedAt = .now
        origin = touch
        growth = 0
        veil = 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: Self.growDuration)) { growth = 1 }
    }

    /// Un toque rápido suelta antes de que el círculo llegue a los bordes: el desvanecido espera.
    private func release() {
        let press = presses
        withAnimation(.easeOut(duration: Self.fadeDuration).delay(remaining)) {
            veil = 0
        } completion: {
            if press == presses {
                growth = 0
                hasRipple = false
            }
        }
    }

    private func tap() {
        // En una `List`, un toque rápido llega sin haber marcado la pulsación.
        if !hasRipple {
            press()
            release()
        }
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
