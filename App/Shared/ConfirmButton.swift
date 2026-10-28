import SwiftUI

/// La ✓ de una hoja: la acción principal, la única de la barra con color. `role: .confirm` la pinta
/// con el color de acento, que es claro (`AccentColor`) y con la marca blanca encima no se leía;
/// lleva el azul de los botones principales (`.glassPill`). Apple reserva el `.tint` en la barra
/// justo para esto: la acción que hay que hacer (WWDC25, «Build a SwiftUI app with the new design»).
struct ConfirmButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .confirm, action: action)
            .tint(Theme.accent)
    }
}
