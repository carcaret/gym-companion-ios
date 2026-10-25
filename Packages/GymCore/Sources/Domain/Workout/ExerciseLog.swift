/// Lo hecho (o por hacer) con un ejercicio en una sesión.
///
/// A diferencia de `db.json`, no copia el nombre del ejercicio: se busca en el catálogo por `exerciseID`.
public struct ExerciseLog: Hashable, Sendable {
    public var exerciseID: ExerciseID
    public var series: Int
    /// Reps objetivo por serie.
    public var targetReps: Int
    /// Reps hechas en cada serie; `nil` = serie sin rellenar.
    public var actualReps: [Int?]
    /// Peso en kg (0 = peso corporal).
    public var weight: Double
    /// Saltado en esta sesión: no cuenta como trabajo hecho, pero conserva los datos.
    public var skipped: Bool
    /// Si se cambió por otro ejercicio en esta sesión, el de la rutina original.
    public var swappedFrom: ExerciseID?
    /// Añadido solo para esta sesión, fuera de la rutina.
    public var oneOff: Bool

    public init(
        exerciseID: ExerciseID, series: Int, targetReps: Int, actualReps: [Int?], weight: Double,
        skipped: Bool = false, swappedFrom: ExerciseID? = nil, oneOff: Bool = false
    ) {
        self.exerciseID = exerciseID
        self.series = series
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weight = weight
        self.skipped = skipped
        self.swappedFrom = swappedFrom
        self.oneOff = oneOff
    }
}
