import SwiftUI
import UIKit

extension View {
    /// En una pantalla con campos de texto: el teclado se cierra al desplazar la pantalla y con
    /// "OK" encima del teclado (el numérico no tiene tecla de retorno). Una vez por pantalla, o el
    /// botón sale repetido.
    func keyboardDismissal() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { Keyboard.dismiss() }
                }
            }
    }
}

extension View {
    /// Tocar fuera de un campo de texto cierra el teclado, en toda la ventana. Se pone una vez, en
    /// la raíz: la vista invisible del fondo instala el reconocedor cuando ya está en la ventana
    /// (en `onAppear` la ventana aún no existe).
    func dismissesKeyboardOnTapOutside() -> some View {
        background(WindowHook().allowsHitTesting(false))
    }
}

private struct WindowHook: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { HookView() }
    func updateUIView(_ view: UIView, context: Context) {}

    private final class HookView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { Keyboard.dismissOnTapOutside(in: window) }
        }

        // DIAGNÓSTICO TEMPORAL (KeyboardTests): lo que ha pasado con el reconocedor.
        override var isAccessibilityElement: Bool { get { true } set {} }
        override var accessibilityIdentifier: String? { get { "keyboard-debug" } set {} }
        override var accessibilityValue: String? { get { Keyboard.trace.joined(separator: " | ") } set {} }
        override var accessibilityFrame: CGRect { get { CGRect(x: 0, y: 0, width: 1, height: 1) } set {} }
    }
}

/// Cerrar el teclado, también al tocar fuera de un campo de texto en cualquier pantalla.
@MainActor
enum Keyboard {
    private static let tapOutside = TapOutside()
    /// DIAGNÓSTICO TEMPORAL.
    static var trace: [String] = []

    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Pone en la ventana un reconocedor de toques que cierra el teclado. No se queda con el toque
    /// (los botones siguen funcionando) ni actúa al tocar otro campo de texto.
    static func dismissOnTapOutside(in window: UIWindow) {
        trace.append("ventana \(type(of: window))")
        guard !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === tapOutside }) else { return }
        trace.append("instalado")
        let recognizer = UITapGestureRecognizer(target: tapOutside, action: #selector(TapOutside.tap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = tapOutside
        window.addGestureRecognizer(recognizer)
    }

    private final class TapOutside: NSObject, UIGestureRecognizerDelegate {
        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            let closed = recognizer.view?.endEditing(true) ?? false
            Keyboard.trace.append("toque estado=\(recognizer.state.rawValue) cerrado=\(closed)")
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            var chain: [String] = []
            while let current = view {
                chain.append(String(describing: type(of: current)))
                if current is UITextField || current is UITextView {
                    Keyboard.trace.append("recibe NO: \(chain.prefix(3).joined(separator: ">"))")
                    return false
                }
                view = current.superview
            }
            Keyboard.trace.append("recibe SÍ: \(chain.prefix(3).joined(separator: ">"))")
            return true
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
