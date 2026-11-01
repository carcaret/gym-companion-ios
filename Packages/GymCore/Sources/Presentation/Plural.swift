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

    static func weighings(_ count: Int) -> String {
        count == 1 ? "1 pesaje" : "\(count) pesajes"
    }

    static func waistMeasurements(_ count: Int) -> String {
        count == 1 ? "1 medida de cintura" : "\(count) medidas de cintura"
    }

    static func nutritionDays(_ count: Int) -> String {
        count == 1 ? "1 día de comida" : "\(count) días de comida"
    }
}
