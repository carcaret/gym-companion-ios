extension Set {
    /// Lo quita si está y lo pone si no (abrir o cerrar una tarjeta, una fila…).
    mutating func toggle(_ member: Element) {
        if remove(member) == nil { insert(member) }
    }
}
