import Domain

/// Lo que se está tecleando en peso, series u objetivo, aún sin aplicar.
///
/// En la PWA el campo se aplicaba al perder el foco, y en la web el foco se pierde antes de que
/// llegue el toque en otro botón ("Finalizar entreno", "+", un chip...). En iOS un botón no quita
/// el foco: la vista va pasando lo tecleado al modelo y el modelo lo aplica antes de cada acción,
/// para que ninguna trabaje con el valor de antes.
public struct TypedValue: Hashable, Sendable {
    public let parameter: LogParameter
    public let text: String
    public let index: Int
}
