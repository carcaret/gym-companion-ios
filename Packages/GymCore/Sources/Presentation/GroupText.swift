import Domain

/// Nombres de los grupos musculares, con su ortografía (en los datos van sin tilde).
public enum GroupText {
    private static let spelled: [MuscleGroup: String] = [.biceps: "Bíceps", .triceps: "Tríceps"]

    /// "Bíceps", "Pecho"…; sin grupo, "Sin grupo" (la PWA, "(sin grupo)").
    public static func name(_ group: MuscleGroup?) -> String {
        guard let group else { return "Sin grupo" }
        return spelled[group] ?? group.rawValue.prefix(1).uppercased() + group.rawValue.dropFirst()
    }
}
