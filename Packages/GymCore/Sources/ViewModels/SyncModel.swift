import Application
import Domain
import Observation
import Presentation

/// La sincronización vista desde la interfaz: el menú del indicador, los avisos, el diálogo de
/// conflicto y los botones de GitHub de los ajustes (`app.js` y `views/settings.js` de la PWA).
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
    /// La hoja de los ajustes de sincronización (`SettingsModel`), que se abre desde el indicador.
    public var isSettingsPresented = false

    /// Lo que ofrece el menú del indicador, según el estado.
    public enum MenuAction: Hashable, Sendable {
        case syncNow
        case resolveConflict
        /// Sin GitHub: abrir los ajustes de sincronización.
        case configure
    }

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
            // Sin aviso: el indicador ya dice que está subido (en la PWA, el toast «Guardado»).
            case .autoSaved: break
            }
        }
    }

    public func refresh() async {
        status = await repository.status
    }

    /// Al arrancar, al volver a la app o al volver la red. Solo avisa si los datos han cambiado: lo
    /// subido lo dice el indicador.
    public func synchronize() async {
        if case .remoteApplied(let remote) = await repository.synchronize() {
            app.replace(with: remote)
            notice = SyncText.remoteApplied
        }
        await refresh()
    }

    /// Tirar hacia abajo en Historial o «Sincronizar ahora» en el menú del indicador: sincroniza al
    /// momento y, como lo ha pedido el usuario, dice siempre cómo ha quedado.
    public func pullToRefresh() async {
        if case .remoteApplied(let remote) = await repository.synchronize() {
            app.replace(with: remote)
            notice = SyncText.remoteApplied
            await refresh()
            return
        }
        await refresh()
        if status.conflict {
            isConflictPresented = true
            return
        }
        notice = switch status.state {
        case .pending where status.waitingForWorkout: SyncText.waitingForWorkout
        // Se ha pedido subir y no se ha podido.
        case .pending: SyncText.uploadFailed
        case .ok: SyncText.synced
        case .disabled: SyncText.notConfigured
        }
    }

    /// El estado, en el menú del indicador y en los ajustes.
    public var statusText: String {
        if status.conflict { return SyncText.conflictTitle }
        return switch status.state {
        case .pending where status.waitingForWorkout: SyncText.waitingForWorkout.text
        case .pending: SyncText.pendingStatus
        case .ok: SyncText.synced.text
        case .disabled: SyncText.notConfigured.text
        }
    }

    public var menuAction: MenuAction {
        switch status.state {
        case .disabled: .configure
        case .pending where status.conflict: .resolveConflict
        case .ok, .pending: .syncNow
        }
    }

    /// Con GitHub configurado, el menú ofrece además los ajustes; sin él, ya es su acción principal
    /// («Configurar GitHub»).
    public var offersSettings: Bool { menuAction != .configure }

    /// «Configurar GitHub» o «Ajustes de sincronización» en el menú del indicador.
    public func showSettings() {
        isSettingsPresented = true
    }

    /// «Resolver conflicto» en el menú del indicador.
    public func resolveConflict() {
        isConflictPresented = true
    }

    /// El indicador late cuando hay algo por subir que no espera al entreno: la subida está en
    /// marcha o no ha salido. Durante el entreno, amarillo quieto: esperar es lo normal.
    public var indicatorPulses: Bool {
        status.state == .pending && !status.waitingForWorkout
    }

    /// Tras terminar un entreno: si había GitHub y no se pudo subir, se avisa.
    public func workoutFinished(_ result: UploadResult) {
        switch result {
        case .unreachable, .failed, .conflict: isSavedLocallyPresented = true
        case .uploaded, .notConfigured: break
        }
    }

    // MARK: - Botones

    /// "Subir a GitHub". Lo que está en marcha lo dice la fila del botón (`SettingsModel.activity`).
    public func forceUpload() async {
        switch await repository.forceUpload() {
        case .uploaded: notice = SyncText.uploaded
        case .notConfigured: notice = SyncText.notConfigured
        case .conflict: isConflictPresented = true
        case .unreachable: notice = SyncText.offline
        case .failed: notice = SyncText.uploadFailed
        }
        await refresh()
    }

    /// "Descargar de GitHub", ya confirmado.
    public func download() async {
        await applyRemote()
        await refresh()
    }

    /// Conflicto → "Subir local → GitHub". La alerta se cierra siempre (SwiftUI ya la ha cerrado
    /// al tocar): si falla, sale el error y el indicador sigue ofreciendo resolverlo.
    public func keepLocal() async {
        isConflictPresented = false
        switch await repository.keepLocal() {
        case .uploaded: notice = SyncText.uploaded
        case .unreachable: notice = SyncText.offline
        case .notConfigured: notice = SyncText.notConfigured
        case .conflict, .failed: notice = SyncText.uploadFailed
        }
        await refresh()
    }

    /// Conflicto → "Bajar GitHub → local", como `keepLocal`.
    public func keepRemote() async {
        isConflictPresented = false
        await applyRemote()
        await refresh()
    }

    private func applyRemote() async {
        switch await repository.download() {
        case .applied(let remote):
            app.replace(with: remote)
            notice = SyncText.remoteApplied
        case .notConfigured: notice = SyncText.notConfigured
        case .failed: notice = SyncText.downloadFailed
        }
    }

    public func cancelConflict() {
        isConflictPresented = false
    }

    // MARK: - Configuración

    /// "Probar conexión" con lo que hay escrito, sin guardar nada. El resultado no es un aviso: va
    /// debajo del botón. Sin repo o sin token no hay nada que probar (el botón está desactivado).
    public func testConnection(repository name: String, branch: String, path: String, token: String) async -> Notice? {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else { return nil }
        return switch await repository.testConnection(location, token: token) {
        case .connected: SyncText.connected
        case .status(let code): SyncText.connectionError(status: code)
        case .unreachable: SyncText.offline
        case .invalidContent: SyncText.invalidRemoteContent
        }
    }

    /// "Guardar": rama y ruta vacías toman las de siempre (`master`, `db.json`). Sin repo o sin
    /// token no guarda (el botón está desactivado).
    public func configure(repository name: String, branch: String, path: String, token: String) async {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else { return }
        do {
            switch try await repository.configure(location, token: token) {
            case .downloaded(let remote):
                app.replace(with: remote)
                notice = SyncText.remoteApplied
            case .downloadFailed: notice = SyncText.downloadFailed
            // Lo que pase con la subida lo dice el indicador.
            case .uploading: break
            }
        } catch {
            notice = SyncText.configureFailed
        }
        await refresh()
    }

    /// Repo y token escritos, sin contar los espacios: lo mínimo para guardar o probar.
    public static func isComplete(repository name: String, token: String) -> Bool {
        trimmed(name) != nil && trimmed(token) != nil
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
