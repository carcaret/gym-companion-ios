import SwiftUI

extension View {
    /// El teclado numérico de iOS no tiene tecla de cerrar: un "OK" encima del teclado, y
    /// desplazar la pantalla también lo cierra. Lo usan las pantallas con tarjetas editables.
    func numberPadDismissal() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
    }
}
