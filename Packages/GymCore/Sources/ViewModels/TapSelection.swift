/// La barra o el punto de una gráfica cuyo valor se ve en el bocadillo («Últimas sesiones» y las
/// gráficas de Gráficas), que se elige con un toque y se va solo a los pocos segundos.
///
/// Un toque en otra barra cambia el bocadillo directamente, sin cerrar primero el que se ve
/// (decisión del usuario, 2026-10-28); en la que ya se ve, o donde no hay nada que enseñar, lo
/// cierra.
public struct TapSelection<ID: Hashable & Sendable>: Hashable, Sendable {
    public private(set) var selected: ID?

    public init(_ selected: ID? = nil) {
        self.selected = selected
    }

    /// Un toque en `id`, o `nil` si no cae en nada que tenga valor.
    public mutating func tap(_ id: ID?) {
        selected = id == selected ? nil : id
    }

    /// Se acabó el tiempo del bocadillo de `id`: solo se cierra si sigue siendo el que se ve, no
    /// el que ha salido después con otro toque.
    public mutating func expire(_ id: ID) {
        if selected == id { selected = nil }
    }
}
