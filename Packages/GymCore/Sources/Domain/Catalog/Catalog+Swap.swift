extension Catalog {
    /// Candidatos para cambiar `exercise` en la rutina `currentRoutine`, en cuatro niveles y por
    /// orden alfabético dentro de cada uno:
    /// 0. mismo grupo y en la rutina de otro día;
    /// 1. mismo grupo y en ninguna rutina;
    /// 2. otro grupo y en la rutina de otro día;
    /// 3. el resto.
    /// Sin grupo no hay "mismo grupo" (ni siquiera entre dos sin grupo).
    public func sortedForSwap(
        _ candidates: [Exercise], replacing exercise: ExerciseID, routines: [Routine], currentRoutine: RoutineID
    ) -> [Exercise] {
        let targetGroup = self[exercise]?.group
        let inOtherRoutines = Set(routines.filter { $0.id != currentRoutine }.flatMap(\.exerciseIDs))
        let inAnyRoutine = Set(routines.allExerciseIDs)

        func tier(_ candidate: Exercise) -> Int {
            let sameGroup = candidate.isSameGroup(as: targetGroup)
            if sameGroup && inOtherRoutines.contains(candidate.id) { return 0 }
            if sameGroup && !inAnyRoutine.contains(candidate.id) { return 1 }
            if inOtherRoutines.contains(candidate.id) { return 2 }
            return 3
        }

        return candidates.sorted { a, b in
            let (tierA, tierB) = (tier(a), tier(b))
            return tierA != tierB ? tierA < tierB : SpanishCollation.precedes(a.name, b.name)
        }
    }
}

/// Los candidatos de `sortedForSwap`, partidos en los del grupo del ejercicio que se cambia y el
/// resto, cada parte en su orden.
public struct SwapCandidates: Hashable, Sendable {
    /// El grupo del ejercicio que se cambia; sin grupo, todo va en `others`.
    public let group: MuscleGroup?
    public let sameGroup: [Exercise]
    public let others: [Exercise]
}

extension Catalog {
    public func swapCandidates(
        _ candidates: [Exercise], replacing exercise: ExerciseID, routines: [Routine], currentRoutine: RoutineID
    ) -> SwapCandidates {
        let group = self[exercise]?.group
        let sorted = sortedForSwap(candidates, replacing: exercise, routines: routines, currentRoutine: currentRoutine)
        return SwapCandidates(group: group, sameGroup: sorted.filter { $0.isSameGroup(as: group) },
                              others: sorted.filter { !$0.isSameGroup(as: group) })
    }
}

extension Exercise {
    /// Es de `group`. Sin grupo no hay "mismo grupo" (ni siquiera entre dos sin grupo).
    func isSameGroup(as group: MuscleGroup?) -> Bool {
        group != nil && self.group == group
    }
}
