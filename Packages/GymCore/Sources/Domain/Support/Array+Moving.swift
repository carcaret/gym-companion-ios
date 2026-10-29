extension Array {
    /// Copia con el elemento de `from` movido a `to` (reordenar ejercicios). (`reorderByIndex`.)
    public func moving(from: Int, to: Int) -> [Element] {
        guard !isEmpty, from != to else { return self }
        var result = self
        result.insert(result.remove(at: from), at: to)
        return result
    }
}
