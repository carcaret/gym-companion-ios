/// Todo lo que guarda la app: el catálogo de ejercicios, las rutinas, los cambios recíprocos
/// pendientes y el historial de sesiones. (El `db` de la PWA.)
public struct TrainingData: Hashable, Sendable {
    public var catalog: Catalog
    /// En el orden en que se muestran.
    public var routines: [Routine]
    /// Como mucho uno por rutina destino.
    public var pendingSwaps: [RoutineID: PendingSwap]
    /// En cualquier orden; las consultas que lo necesitan ordenan.
    public var history: [Session]

    public init(
        catalog: Catalog = Catalog([]), routines: [Routine] = Routine.defaults,
        pendingSwaps: [RoutineID: PendingSwap] = [:], history: [Session] = []
    ) {
        self.catalog = catalog
        self.routines = routines
        self.pendingSwaps = pendingSwaps
        self.history = history
    }
}

extension TrainingData {
    /// Sin historial ni catálogo: la app recién instalada (las rutinas por defecto no cuentan).
    public var isEmpty: Bool { history.isEmpty && catalog.ids.isEmpty }
}
