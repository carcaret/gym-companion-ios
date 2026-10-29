import Domain

public enum UploadResult: Hashable, Sendable {
    case uploaded
    case notConfigured
    /// Hay que resolver el conflicto antes de subir.
    case conflict
    /// Sin red: no se pudo ni preguntar a GitHub.
    case unreachable
    /// GitHub respondió con un error.
    case failed
}

public enum DownloadResult: Hashable, Sendable {
    case applied(TrainingData)
    case notConfigured
    /// Sin red, con error o con un contenido que no es válido: lo local no se toca.
    case failed
}

public enum ConnectionResult: Hashable, Sendable {
    case connected
    case status(Int)
    case unreachable
    /// Conecta, pero el fichero no es un `db.json` válido.
    case invalidContent
}

public enum ConfigureResult: Hashable, Sendable {
    /// La app estaba vacía: se han bajado los datos de GitHub.
    case downloaded(TrainingData)
    /// La app estaba vacía y no se pudo bajar nada (se queda configurada).
    case downloadFailed
    /// Había datos locales: se suben, como hacía la PWA.
    case uploading
}

public enum SyncOutcome: Hashable, Sendable {
    case nothing
    case uploaded
    /// Lo remoto era distinto y no había nada pendiente: sustituye a lo local.
    case remoteApplied(TrainingData)
    case failed
}
