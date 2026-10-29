import Domain

/// Lo que enseña el reloj en las capturas del CI: el Día 1 de `DemoData` en curso, como si se
/// acabara de empezar en el iPhone, o nada con `-demo-sin-entreno`. Nunca se usa en el reloj.
enum WatchDemo {
    static func snapshot(arguments: [String], today: LocalDate) -> WatchSnapshot? {
        if LaunchArgument.demoWithoutWorkout.isPresent(in: arguments) { return WatchSnapshot(workout: nil) }
        guard LaunchArgument.demo.isPresent(in: arguments) else { return nil }
        var data = DemoData.make(today: today)
        let history = data.history
        let routine = data.routines[0]
        data.history.append(.planned(date: today, routine: routine.id, exerciseIDs: routine.exerciseIDs) { id, _ in
            history.bestRecentSeed(for: id, today: today)
        })
        return data.watchSnapshot(today: today)
    }
}
