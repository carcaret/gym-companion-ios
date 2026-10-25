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

/// Cerrar el teclado, también al tocar fuera de un campo de texto en cualquier pantalla.
@MainActor
enum Keyboard {
    private static let tapOutside = TapOutside()

    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Pone en la ventana un reconocedor de toques que cierra el teclado. No se queda con el toque
    /// (los botones siguen funcionando) ni actúa al tocar otro campo de texto.
    static func dismissOnTapOutside() {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === tapOutside }) {
            let recognizer = UITapGestureRecognizer(target: tapOutside, action: #selector(TapOutside.tap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = tapOutside
            window.addGestureRecognizer(recognizer)
        }
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
