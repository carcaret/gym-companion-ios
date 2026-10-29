import SwiftUI

extension Binding where Value == Bool {
    /// Una hoja o una pantalla empujada que se ve mientras `isPresented` y, al cerrarla el usuario
    /// (deslizar, la flecha de volver), llama a `dismiss` para que el modelo lo sepa.
    init(presentedWhile isPresented: @escaping () -> Bool, onDismiss dismiss: @escaping () -> Void) {
        self.init(get: isPresented, set: { if !$0 { dismiss() } })
    }
}
