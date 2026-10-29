/// Cómo queda una serie respecto al objetivo de reps: llegar a él ya es cumplirlo.
public enum RepOutcome: Hashable, Sendable {
    case below, atTarget, above

    public init(reps: Int, target: Int) {
        self = reps < target ? .below : reps == target ? .atTarget : .above
    }

    public var meetsTarget: Bool { self != .below }
}
