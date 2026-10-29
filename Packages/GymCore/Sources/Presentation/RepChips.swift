/// Los chips para elegir las reps de una serie (`buildChipValues`, `buildChipStripHtml`).
public enum RepChips {
    /// Cinco valores alrededor de `current`, sin bajar de 0.
    public static func values(around current: Int) -> [Int] {
        let low = max(0, current - 2)
        return Array(low...(low + 4))
    }
}
