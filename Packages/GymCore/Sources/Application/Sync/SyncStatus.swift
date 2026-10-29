/// Estado del indicador de sincronización.
public enum SyncState: Hashable, Sendable {
    /// GitHub sin configurar.
    case disabled
    /// Todo subido.
    case ok
    /// Hay cambios sin subir (o subiéndose).
    case pending
}

public struct SyncStatus: Hashable, Sendable {
    public var state: SyncState
    /// La última subida chocó con una versión remota que no era la conocida: hay que elegir.
    public var conflict: Bool
    /// Lo pendiente espera a propósito a que acabe el entreno en curso (no se sube nada durante
    /// el entreno): no es que algo vaya mal.
    public var waitingForWorkout: Bool

    public init(state: SyncState, conflict: Bool = false, waitingForWorkout: Bool = false) {
        self.state = state
        self.conflict = conflict
        self.waitingForWorkout = waitingForWorkout
    }
}

/// Lo que pasa sin que nadie lo pida y la interfaz tiene que saber.
public enum SyncEvent: Hashable, Sendable {
    case status(SyncStatus)
    /// Terminó bien una subida diferida (en la PWA, el toast "Guardado"). La app no avisa: lo
    /// esperan los tests (`nextAutoSave`).
    case autoSaved
}
