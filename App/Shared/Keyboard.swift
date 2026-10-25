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
    }
}

/// Cerrar el teclado, también al tocar fuera de un campo de texto en cualquier pantalla.
@MainActor
enum Keyboard {
    private static let tapOutside = TapOutside()

    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Pone en la ventana un reconocedor de toques que cierra el teclado. No se queda con el toque
    /// (los botones siguen funcionando) ni actúa al tocar otro campo de texto.
    static func dismissOnTapOutside(in window: UIWindow) {
        guard !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === tapOutside }) else { return }
        let recognizer = UITapGestureRecognizer(target: tapOutside, action: #selector(TapOutside.tap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = tapOutside
        window.addGestureRecognizer(recognizer)
    }

    private final class TapOutside: NSObject, UIGestureRecognizerDelegate {
        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            recognizer.view?.endEditing(true)
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
