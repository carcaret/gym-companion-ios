extension Collection where Element == Routine {
    /// Las rutinas distintas de `routine` que llevan `exercise`, en su orden.
    public func others(than routine: RoutineID?, containing exercise: ExerciseID) -> [Routine] {
        filter { $0.id != routine && $0.exerciseIDs.contains(exercise) }
    }

    /// La otra rutina que debe hacer el cambio inverso al meter `exercise` en `routine`: solo si
    /// el ejercicio está en exactamente una rutina distinta (en ninguna, o en varias, no aplica).
    public func reciprocalSwapTarget(from routine: RoutineID, for exercise: ExerciseID) -> RoutineID? {
        let matches = others(than: routine, containing: exercise)
        return matches.count == 1 ? matches.first?.id : nil
    }
}

/// Qué hacer con los ejercicios de una rutina al generar su sesión, dado un pendiente.
public struct SwapConsumption: Hashable, Sendable {
    public let exerciseIDs: [ExerciseID]
    /// `true` = el pendiente ya no sirve (caducado o inaplicable) y hay que borrarlo ya; `false`
    /// con cambio aplicado = debe seguir hasta que el entreno termine.
    public let clearNow: Bool

    public init(exerciseIDs: [ExerciseID], clearNow: Bool) {
        self.exerciseIDs = exerciseIDs
        self.clearNow = clearNow
    }
}

extension PendingSwap {
    /// Pendiente para la rutina destino, o `nil` si `to` ya está en ella (quedaría duplicado).
    public static func make(from: ExerciseID, to: ExerciseID, targetRoutine: [ExerciseID], weekStart: LocalDate) -> PendingSwap? {
        targetRoutine.contains(to) ? nil : PendingSwap(from: from, to: to, weekStart: weekStart)
    }

    /// Aplica el pendiente (si lo hay) a los ejercicios de la rutina al generar su sesión.
    ///
    /// Caso conocido y aceptado: si `to` se añade a la rutina destino después de crear el pendiente
    /// y antes de consumirlo, puede quedar duplicado (`make` solo lo comprueba al crearlo). Con un
    /// solo usuario y un solo aparato no compensa vigilarlo aquí.
    public static func consume(_ pending: PendingSwap?, in exerciseIDs: [ExerciseID], weekStart: LocalDate) -> SwapConsumption {
        guard let pending else { return SwapConsumption(exerciseIDs: exerciseIDs, clearNow: false) }
        guard pending.weekStart == weekStart, let index = exerciseIDs.firstIndex(of: pending.from) else {
            return SwapConsumption(exerciseIDs: exerciseIDs, clearNow: true)
        }
        var swapped = exerciseIDs
        swapped[index] = pending.to
        return SwapConsumption(exerciseIDs: swapped, clearNow: false)
    }
}
