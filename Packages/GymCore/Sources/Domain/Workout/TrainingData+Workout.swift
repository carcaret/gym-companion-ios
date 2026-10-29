/// El entreno del día sobre todos los datos: lo que cambia en el historial, la rutina y los
/// cambios pendientes al empezar, añadir, quitar, reordenar y terminar. (`views/hoy.js` de la PWA.)
extension TrainingData {
    /// Empieza `routine` el día `day`: consume el cambio pendiente de la semana, planifica cada
    /// ejercicio con su mejor semilla reciente y sustituye el entreno de ese día, si lo había.
    public mutating func startWorkout(routine: RoutineID, on day: LocalDate) {
        let consumption = PendingSwap.consume(pendingSwaps[routine], in: routines.routine(routine)?.exerciseIDs ?? [],
                                              weekStart: day.weekStart)
        if consumption.clearNow { pendingSwaps[routine] = nil }
        let history = history
        let session = Session.planned(date: day, routine: routine, exerciseIDs: consumption.exerciseIDs) { id, _ in
            history.bestRecentSeed(for: id, today: day)
        }
        self.history.removeAll { $0.date == day }
        self.history.append(session)
    }

    /// El ejercicio entra al final del entreno y, si no es puntual, de la rutina. Sin entreno en
    /// curso ese día no cambia nada y devuelve `false`.
    @discardableResult
    public mutating func addToWorkout(_ exercise: ExerciseID, oneOff: Bool, on day: LocalDate) -> Bool {
        guard var session = activeWorkout(on: day) else { return false }
        var log = ExerciseLog(planning: exercise, from: history.bestRecentSeed(for: exercise, today: day))
        log.oneOff = oneOff
        if !oneOff { editRoutine(session.routineID) { $0.append(exercise) } }
        session.logs.append(log)
        history.replace(session)
        return true
    }

    /// Lo quita del entreno y, con `alsoFromRoutine`, también de la rutina.
    public mutating func removeFromWorkout(_ exercise: ExerciseID, alsoFromRoutine: Bool, on day: LocalDate) {
        guard var session = activeWorkout(on: day) else { return }
        if alsoFromRoutine { editRoutine(session.routineID) { $0.removeAll { $0 == exercise } } }
        session.logs.removeAll { $0.exerciseID == exercise }
        history.replace(session)
    }

    /// Mueve un ejercicio del entreno. Los logs mandan y la rutina se deriva de ellos: sin los
    /// puntuales y con cada cambio guardado por su ejercicio original. Devuelve si se movió.
    @discardableResult
    public mutating func reorderWorkout(from source: Int, to destination: Int, on day: LocalDate) -> Bool {
        guard var session = activeWorkout(on: day), source != destination, session.logs.indices.contains(source),
              session.logs.indices.contains(destination) else { return false }
        session.logs = session.logs.moving(from: source, to: destination)
        let derived = session.logs.filter { !$0.oneOff }.map { $0.swappedFrom ?? $0.exerciseID }
        editRoutine(session.routineID) { $0 = derived }
        history.replace(session)
        return true
    }

    /// Da por terminado el entreno del día y borra el cambio pendiente de su rutina. No valida: eso
    /// se mira antes (`Session.validation`).
    public mutating func finishWorkout(on day: LocalDate) {
        guard var session = activeWorkout(on: day) else { return }
        session.finish()
        pendingSwaps[session.routineID] = nil
        history.replace(session)
    }

    /// El entreno sin terminar del día, si lo hay.
    public func activeWorkout(on day: LocalDate) -> Session? {
        history.session(on: day).flatMap { $0.completed ? nil : $0 }
    }

    // MARK: - El selector de ejercicios

    /// Lo que se puede añadir al entreno del día: los del catálogo que no están ni en su rutina ni
    /// en el entreno, por orden alfabético.
    public func addCandidates(on day: LocalDate) -> [Exercise] {
        guard let session = activeWorkout(on: day) else { return [] }
        let excluded = Set(routines.routine(session.routineID)?.exerciseIDs ?? []).union(session.logs.map(\.exerciseID))
        return catalog.all.filter { !excluded.contains($0.id) }.sorted { SpanishCollation.precedes($0.name, $1.name) }
    }

    /// Queda algún ejercicio del catálogo fuera del entreno del día (para «Cambiar por otro»).
    public func hasSwapCandidates(on day: LocalDate) -> Bool {
        guard let session = activeWorkout(on: day) else { return false }
        let present = Set(session.logs.map(\.exerciseID))
        return catalog.ids.contains { !present.contains($0) }
    }

    /// Un ejercicio nuevo en el catálogo, con el id que sale de su nombre. Si ya hay uno con ese id,
    /// no cambia nada y devuelve `nil`.
    public mutating func createExercise(named name: String, group: MuscleGroup?) -> ExerciseID? {
        guard !catalog.hasExercise(named: name) else { return nil }
        let id = ExerciseID(ExerciseID.slug(from: name))
        catalog = Catalog(catalog.all + [Exercise(id: id, name: name, group: group)])
        return id
    }

    /// Tras cambiar en `routine` `outgoing` por `new`: si `new` es de otra rutina (y solo de una)
    /// que aún no se ha hecho esta semana, el cambio inverso que haría allí la próxima vez.
    public func reciprocalSwap(from routine: RoutineID, new: ExerciseID, outgoing: ExerciseID,
                               on day: LocalDate) -> (routine: RoutineID, swap: PendingSwap)? {
        guard let target = routines.reciprocalSwapTarget(from: routine, for: new),
              !history.hasCompletedSession(of: target, inWeekStarting: day.weekStart),
              let swap = PendingSwap.make(from: new, to: outgoing, targetRoutine: routines.routine(target)?.exerciseIDs ?? [],
                                          weekStart: day.weekStart)
        else { return nil }
        return (target, swap)
    }

    /// Sin historial ni catálogo: la app recién instalada (las rutinas por defecto no cuentan).
    public var isEmpty: Bool { history.isEmpty && catalog.ids.isEmpty }

    private mutating func editRoutine(_ id: RoutineID, _ change: (inout [ExerciseID]) -> Void) {
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
        change(&routines[index].exerciseIDs)
    }
}
