import SwiftUI

extension View {
    /// Un botón a lo ancho, centrado en su fila. En watchOS un botón no pasa de 178 pt aunque su
    /// etiqueta pida todo el ancho (en el Series 10 de 46 mm la pantalla tiene 208): en un `VStack`
    /// alineado a la izquierda se quedaba pegado a ese lado, con un hueco a la derecha (medido en el
    /// simulador, 2026-10-31).
    func centeredInRow() -> some View {
        frame(maxWidth: .infinity)
    }
}
