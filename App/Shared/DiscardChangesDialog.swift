import Presentation
import SwiftUI

extension View {
    /// La pregunta de la ✕ de una hoja con cambios: «Descartar cambios» o «Seguir editando». Va
    /// colgada de la ✕: en iOS 26 sale como globo que apunta a su vista, y tocar fuera cierra el
    /// globo y sigue editando (`keep`).
    func discardChangesDialog(_ title: String = FormText.discardTitle, isPresented: Bool,
                              discard: @escaping @MainActor () -> Void, keep: @escaping @MainActor () -> Void) -> some View {
        confirmationDialog(title, isPresented: Binding(get: { isPresented }, set: { if !$0 { keep() } }),
                           titleVisibility: .visible) {
            Button(FormText.discardConfirm, role: .destructive, action: discard)
            Button(FormText.keepEditing, role: .cancel, action: keep)
        }
    }
}
