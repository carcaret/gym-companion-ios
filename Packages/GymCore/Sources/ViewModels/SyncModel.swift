import Application
import Domain
import Observation
import Presentation

/// La sincronización vista desde la interfaz: el indicador, sus avisos, el diálogo de conflicto y
/// los botones de GitHub de Ajustes (`app.js` y `views/settings.js` de la PWA).
@MainActor
@Observable
public final class SyncModel {
    public private(set) var status = SyncStatus(state: .disabled)
    /// El aviso de la app (`AppModel.notice`).
    public var notice: Notice? {
        get { app.notice }
        set { app.notice = newValue }
    }
    /// Diálogo de conflicto: subir lo local, bajar lo remoto o cancelar.
    public var isConflictPresented = false
    /// Aviso de que el entreno terminado se quedó en el iPhone sin subir.
    public var isSavedLocallyPresented = false

    private let repository: TrainingRepository
    private let app: AppModel

    public init(repository: TrainingRepository, app: AppModel) {
        self.repository = repository
        self.app = app
    }

    /// Escucha lo que pasa sin que nadie lo pida (subidas diferidas, cambios de estado). Dura
    /// mientras viva la vista que la lanza.
    public func observe() async {
        for await event in repository.events {
            switch event {
            case .status(let new): status = new
            case .autoSaved: notice = SyncText.autoSaved
            }
        }
    }

    public func refresh() async {
        status = await repository.status
    }

    /// Al arrancar, al volver a la app o al volver la red.
    public func synchronize(afterReconnect: Bool = false) async {
        switch await repository.synchronize() {
        case .remoteApplied(let remote):
            app.replace(with: remote)
            notice = SyncText.remoteApplied
        case .uploaded where afterReconnect:
            notice = SyncText.savedAfterReconnect
        case .uploaded, .nothing, .failed:
            break
        }
        await refresh()
    }

    public func tapIndicator() {
        switch status.state {
        case .pending where status.conflict: isConflictPresented = true
        case .pending: notice = SyncText.pendingChanges
        case .ok: notice = SyncText.synced
        case .disabled: notice = SyncText.notConfigured
        }
    }

    /// Tras terminar un entreno: si había GitHub y no se pudo subir, se avisa.
    public func workoutFinished(_ result: UploadResult) {
        switch result {
        case .unreachable, .failed, .conflict: isSavedLocallyPresented = true
        case .uploaded, .notConfigured: break
        }
    }

    // MARK: - Botones

    /// "Subir a GitHub".
    public func forceUpload() async {
        notice = SyncText.uploading
        switch await repository.forceUpload() {
        case .uploaded: notice = SyncText.uploaded
        case .notConfigured: notice = SyncText.notConfiguredWarning
        case .conflict:
            notice = nil
            isConflictPresented = true
        case .unreachable, .failed: notice = SyncText.uploadFailed
        }
        await refresh()
    }

    /// "Descargar de GitHub", ya confirmado.
    public func download() async {
        notice = SyncText.downloading
        switch await repository.download() {
        case .applied(let remote):
            app.replace(with: remote)
            notice = SyncText.downloaded
        case .notConfigured: notice = SyncText.notConfiguredWarning
        case .failed: notice = SyncText.downloadFailed
        }
        await refresh()
    }

    /// Conflicto → "Subir local → GitHub". Si falla, el diálogo sigue abierto.
    public func keepLocal() async {
        switch await repository.keepLocal() {
        case .uploaded:
            isConflictPresented = false
            notice = SyncText.keptLocal
        case .unreachable: notice = SyncText.cannotConnect
        case .notConfigured: notice = SyncText.notConfiguredWarning
        case .conflict, .failed: notice = SyncText.keepLocalFailed
        }
        await refresh()
    }

    /// Conflicto → "Bajar GitHub → local". Si falla, el diálogo sigue abierto.
    public func keepRemote() async {
        switch await repository.download() {
        case .applied(let remote):
            app.replace(with: remote)
            isConflictPresented = false
            notice = SyncText.keptRemote
        case .notConfigured: notice = SyncText.notConfiguredWarning
        case .failed: notice = SyncText.keepRemoteFailed
        }
        await refresh()
    }

    public func cancelConflict() {
        isConflictPresented = false
    }

    // MARK: - Configuración

    /// "Probar conexión" con lo que hay escrito, sin guardar nada.
    public func testConnection(repository name: String, branch: String, path: String, token: String) async {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else {
            notice = SyncText.repoAndTokenRequired
            return
        }
        notice = SyncText.testing
        switch await repository.testConnection(location, token: token) {
        case .connected: notice = SyncText.connected
        case .status(let code): notice = SyncText.connectionError(status: code)
        case .unreachable: notice = SyncText.cannotConnectAtAll
        case .invalidContent: notice = SyncText.invalidRemoteContent
        }
    }

    /// "Guardar": rama y ruta vacías toman las de siempre (`master`, `db.json`).
    public func configure(repository name: String, branch: String, path: String, token: String) async {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else {
            notice = SyncText.repoAndTokenRequired
            return
        }
        notice = SyncText.configSaved
        do {
            switch try await repository.configure(location, token: token) {
            case .downloaded(let remote):
                app.replace(with: remote)
                notice = SyncText.downloaded
            case .downloadFailed: notice = SyncText.downloadFailed
            case .uploading: break
            }
        } catch {
            notice = Notice(String(describing: error), .error)
        }
        await refresh()
    }

    private static func location(_ name: String, _ branch: String, _ path: String) -> SyncLocation? {
        guard let name = trimmed(name) else { return nil }
        return SyncLocation(repository: name, branch: trimmed(branch) ?? "master", path: trimmed(path) ?? "db.json")
    }

    private static func trimmed(_ text: String) -> String? {
        let result = text.trimmingWhitespace()
        return result.isEmpty ? nil : result
    }
}
