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
        let inAnyRoutine = Set(routines.flatMap(\.exerciseIDs))

        func tier(_ candidate: Exercise) -> Int {
            let sameGroup = targetGroup != nil && candidate.group == targetGroup
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
