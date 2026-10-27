import SwiftUI
import UIKit

extension View {
    /// En una pantalla con campos de texto: el teclado se cierra al desplazar la pantalla. Sin botón
    /// "OK" encima del teclado: tocar fuera de un campo ya lo cierra (decisión del usuario, 2026-10-25).
    func keyboardDismissal() -> some View {
        scrollDismissesKeyboard(.interactively)
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

    /// Pone en la ventana un reconocedor de toques que cierra el teclado. No se queda con el toque
    /// (los botones siguen funcionando) ni actúa al tocar otro campo de texto. Sin teclado no hace
    /// nada: `endEditing` en cada toque dejaba sin animar lo que cambiaba con ese toque (abrir una
    /// tarjeta, el círculo al tocar una rutina; vídeo del CI, 2026-10-27).
    static func dismissOnTapOutside(in window: UIWindow) {
        guard !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === tapOutside }) else { return }
        let recognizer = UITapGestureRecognizer(target: tapOutside, action: #selector(TapOutside.tap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = tapOutside
        window.addGestureRecognizer(recognizer)
    }

    private final class TapOutside: NSObject, UIGestureRecognizerDelegate {
        private var isKeyboardVisible = false

        override init() {
            super.init()
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardShown), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardHidden), name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        @objc private func keyboardShown() { isKeyboardVisible = true }
        @objc private func keyboardHidden() { isKeyboardVisible = false }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            isKeyboardVisible
        }

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
