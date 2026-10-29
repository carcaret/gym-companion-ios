import SwiftUI

/// La fila de botones fija abajo, encima de la barra de pestañas: el secundario y el principal a
/// partes iguales (se distinguen por el estilo, no por el tamaño: repaso de la HIG, 2026-10-28), o
/// solo el principal a todo el ancho. Píldoras de cristal
/// (`.glassPill`) sin fondo detrás: las tarjetas pasan por debajo al desplazarse.
struct BottomActions<Secondary: View, Primary: View>: View {
    @ViewBuilder let secondary: Secondary
    @ViewBuilder let primary: Primary

    /// El margen de la barra de pestañas de iOS 26, para que los dos cristales tengan el mismo
    /// ancho (decisión del usuario, 2026-10-27). iOS no lo da: medido en el iPhone 17 Pro del CI
    /// (21 pt; las tarjetas van a 16). Si cambia con otra versión de iOS, se vuelve a medir.
    private static var tabBarMargin: CGFloat { 21 }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                secondary
                primary
            }
        }
        .padding(.horizontal, Self.tabBarMargin)
        .padding(.vertical, 8)
    }
}

extension BottomActions where Secondary == EmptyView {
    init(@ViewBuilder primary: () -> Primary) {
        self.init(secondary: { EmptyView() }, primary: primary)
    }
}
