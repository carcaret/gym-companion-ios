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
    /// La hoja de los ajustes de sincronización (`SettingsModel`), que se abre desde el indicador.
    public var isSettingsPresented = false

    /// Lo que ofrece el menú del indicador, según el estado.
    public enum MenuAction: Hashable, Sendable {
        case syncNow
        case resolveConflict
        /// Sin GitHub: abrir los ajustes de sincronización.
        case configure
    }

    /// Lo que dura un aviso que no es un error: 2,5 s, como el toast de la PWA. Los tests de
    /// interfaz que lo buscan tras una animación larga lo alargan (`-avisos-largos`).
    public let noticeDuration: Duration

    private let repository: TrainingRepository
    private let app: AppModel

    public init(repository: TrainingRepository, app: AppModel, noticeDuration: Duration = .seconds(2.5)) {
        self.repository = repository
        self.app = app
        self.noticeDuration = noticeDuration
    }

    /// Cerrar el aviso (tocarlo, deslizarlo hacia arriba o la acción de VoiceOver).
    public func dismissNotice() {
        notice = nil
    }

    /// Se le acaba el tiempo a `expired`: se va, salvo que sea un error (espera a que lo cierren) o
    /// que ya lo haya sustituido otro.
    public func expire(_ expired: Notice) {
        guard !expired.staysUntilDismissed, notice == expired else { return }
        notice = nil
    }

    /// La pantalla del error de los datos ofrece bajarlos de GitHub, si está configurado.
    public var offersDownload: Bool { status.state != .disabled }

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

    /// Lo pendiente de subir sale ya, con tiempo pedido al sistema.
    public func flush() async {
        await repository.flush()
    }

    public func refresh() async {
        status = await repository.status
    }

    /// Al arrancar, al volver a la app o al volver la red. Solo avisa si los datos han cambiado: lo
    /// subido lo dice el indicador.
    public func synchronize() async {
        _ = await synchronizeAndApply()
        await refresh()
    }

    /// Sincroniza y, si lo remoto sustituye a lo local, lo aplica y lo dice. Devuelve si lo aplicó.
    private func synchronizeAndApply() async -> Bool {
        guard case .remoteApplied(let remote) = await repository.synchronize() else { return false }
        app.replace(with: remote)
        notice = SyncText.remoteApplied
        return true
    }

    /// Tirar hacia abajo en Historial o «Sincronizar ahora» en el menú del indicador: sincroniza al
    /// momento y, como lo ha pedido el usuario, dice siempre cómo ha quedado.
    public func pullToRefresh() async {
        let applied = await synchronizeAndApply()
        await refresh()
        guard !applied else { return }
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

    // MARK: - Botones

    /// «Sustituir por los datos de GitHub», ya confirmado.
    public func download() async {
        await applyRemote()
        await refresh()
    }

    /// Conflicto → «Usar los de este iPhone». La alerta se cierra siempre (SwiftUI ya la ha cerrado
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

    /// Conflicto → «Usar los de GitHub», como `keepLocal`.
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

    /// Probar la conexión con lo que hay escrito, sin guardar nada. El resultado no es un aviso: va
    /// debajo de los campos. Sin repo o sin token no hay nada que probar (la ✓ está apagada).
    public func testConnection(repository name: String, branch: String, path: String, token: String) async -> Notice? {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else { return nil }
        return switch await repository.testConnection(location, token: token) {
        case nil: SyncText.connected
        case .unauthorized: SyncText.tokenRejected
        case .notFound: SyncText.remoteNotFound
        case .failed: SyncText.remoteFailed
        case .unreachable: SyncText.offline
        case .invalidContent: SyncText.invalidRemoteContent
        // Leer no da conflicto; si llegara, como cualquier otro error.
        case .conflict: SyncText.remoteFailed
        }
    }

    /// La ✓ de los ajustes: rama y ruta vacías toman las de siempre (`master`, `db.json`). Sin repo o sin
    /// token no guarda (el botón está desactivado).
    /// Devuelve si se guardó.
    @discardableResult
    public func configure(repository name: String, branch: String, path: String, token: String) async -> Bool {
        guard let location = Self.location(name, branch, path), let token = Self.trimmed(token) else { return false }
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
            await refresh()
            return false
        }
        await refresh()
        return true
    }

    /// Repo y token escritos, sin contar los espacios: lo mínimo para guardar o probar.
    public static func isComplete(repository name: String, token: String) -> Bool {
        trimmed(name) != nil && trimmed(token) != nil
    }

    private static func location(_ name: String, _ branch: String, _ path: String) -> SyncLocation? {
        guard let name = trimmed(name) else { return nil }
        return SyncLocation(repository: name, branch: trimmed(branch) ?? SyncLocation.defaultBranch,
                            path: trimmed(path) ?? SyncLocation.defaultPath)
    }

    private static func trimmed(_ text: String) -> String? {
        let result = text.trimmingWhitespace()
        return result.isEmpty ? nil : result
    }
}
