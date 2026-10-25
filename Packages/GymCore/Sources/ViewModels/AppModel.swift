import Application
import Domain
import Observation
import Presentation

/// Qué hacer con un conflicto de sincronización (las opciones del aviso de la PWA).
public enum ConflictChoice: Sendable {
    case cancel
    /// "Subir local → GitHub".
    case keepLocal
    /// "Bajar GitHub → local".
    case takeRemote
}

/// Estado de la app: los datos del usuario y su sincronización con GitHub.
@MainActor
@Observable
public final class AppModel {
    public private(set) var data: TrainingData?
    /// Si los datos guardados no se pudieron leer: no se machacan, se avisa.
    public private(set) var loadError: String?
    public private(set) var syncStatus: SyncStatus = .disabled
    /// Aviso breve para la interfaz (el `toast` de la PWA).
    public var notice: String?
    /// Hay que ofrecer las opciones del conflicto.
    public private(set) var showsConflict = false

    private let startUp: StartUp
    private let synchronizer: Synchronizer
    private var listening: Task<Void, Never>?

    public init(startUp: StartUp, synchronizer: Synchronizer) {
        self.startUp = startUp
        self.synchronizer = synchronizer
    }

    public func start() async {
        guard data == nil else { return }
        do {
            let loaded = try await startUp.run()
            data = loaded
            loadError = nil
            listen()
            await synchronizer.start(with: loaded)
            syncStatus = await synchronizer.status
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Un cambio de los datos (lo usarán las pantallas): se guarda y se sincroniza.
    public func save(_ new: TrainingData) async throws {
        data = new
        try await synchronizer.save(new)
    }

    public func tapSyncIndicator() {
        if syncStatus == .conflict { showsConflict = true } else { notice = SyncText.indicator(syncStatus) }
    }

    /// "Subir a GitHub" de Ajustes.
    public func uploadToGitHub() async {
        switch await synchronizer.uploadNow() {
        case .done: notice = SyncText.uploaded
        case .notConfigured: notice = SyncText.notConfigured
        case .conflict: showsConflict = true
        case .failed: notice = SyncText.uploadFailed
        }
        syncStatus = await synchronizer.status
    }

    /// "Sincronizar desde GitHub" de Ajustes (tras confirmar): lo de GitHub sustituye a lo local.
    public func downloadFromGitHub() async {
        switch await synchronizer.downloadRemote() {
        case .success(let remote):
            data = remote
            notice = SyncText.downloaded
        case .failure:
            notice = SyncText.downloadFailed
        }
        syncStatus = await synchronizer.status
    }

    public func resolveConflict(_ choice: ConflictChoice) {
        showsConflict = false
        guard choice != .cancel else { return }
        Task { await perform(choice) }
    }

    /// `resolveConflict` esperando a que termine (para los tests y para quien lo necesite).
    public func resolveConflictAndWait(_ choice: ConflictChoice) async {
        showsConflict = false
        await perform(choice)
    }

    /// La app pasa a segundo plano: subir lo que esperaba.
    public func didEnterBackground() async {
        await synchronizer.flush()
    }

    /// La app vuelve al primer plano: reintentar lo pendiente.
    public func didBecomeActive() async {
        await synchronizer.retryIfPending()
    }

    /// Deja que se procesen los eventos de la sincronización recibidos hasta ahora.
    public func waitForEvents() async {
        for _ in 0..<50 { await Task.yield() }
    }

    private func perform(_ choice: ConflictChoice) async {
        switch choice {
        case .cancel:
            return
        case .keepLocal:
            notice = await synchronizer.keepLocal() == .done ? SyncText.keptLocal : SyncText.uploadFailed
        case .takeRemote:
            await downloadFromGitHub()
        }
        syncStatus = await synchronizer.status
    }

    private func listen() {
        guard listening == nil else { return }
        let events = synchronizer.events
        listening = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                switch event {
                case .status(let status): syncStatus = status
                case .uploaded: notice = SyncText.saved
                case .remoteApplied(let remote):
                    data = remote
                    notice = SyncText.remoteApplied
                }
            }
        }
    }
}
