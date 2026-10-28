/// Los recuentos, con el número y la palabra concordando (repaso de la HIG, 2026-10-28: salía
/// «1 ejercicios»).
enum Plural {
    static let noExercises = "Sin ejercicios"

    static func exercises(_ count: Int) -> String {
        count == 1 ? "1 ejercicio" : "\(count) ejercicios"
    }

    static func sessions(_ count: Int) -> String {
        count == 1 ? "1 sesión" : "\(count) sesiones"
    }
}
