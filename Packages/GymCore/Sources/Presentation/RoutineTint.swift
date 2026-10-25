import Domain

/// El color de una rutina: el de `--color-dia1..3` de la PWA, que pinta el filete de las tarjetas
/// de rutina e historial, el título y la etiqueta del día. Los colores los pone la vista.
public enum RoutineTint: Hashable, Sendable, CaseIterable {
    case day1, day2, day3

    /// DIA1, DIA2 y DIA3 tienen el de su día, como en la PWA; otra rutina, el de su posición, de
    /// tres en tres. Una rutina que ya no existe no tiene color.
    public static func of(_ routine: RoutineID, in routines: [RoutineID]) -> RoutineTint? {
        switch routine.rawValue {
        case "DIA1": return .day1
        case "DIA2": return .day2
        case "DIA3": return .day3
        default:
            guard let index = routines.firstIndex(of: routine) else { return nil }
            return allCases[index % allCases.count]
        }
    }
}
