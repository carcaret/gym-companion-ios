import Application
import Domain
import Observation
import Presentation

/// Los ajustes de sincronización (`views/settings.js` de la PWA), en la hoja que abre el indicador:
/// dónde está el `db.json` de GitHub y el token. La ✓ prueba lo escrito y, si va bien, guarda y
/// cierra la hoja, como al añadir una cuenta de correo (2026-10-27; la PWA tenía «Probar conexión»
/// aparte). La sincronización la hace `SyncModel`.
@MainActor
@Observable
public final class SettingsModel {
    // Al cambiar un campo, el resultado de la última prueba ya no dice nada de lo escrito.
    public var repository = "" { didSet { connectionResult = nil } }
    public var branch = "" { didSet { connectionResult = nil } }
    public var path = "" { didSet { connectionResult = nil } }
    public var token = "" { didSet { connectionResult = nil } }
    /// Confirmación de «Sustituir por los datos de GitHub» (sobreescribe lo local).
    public var isDownloadConfirmationPresented = false
    /// La X con algo escrito sin guardar: «Descartar cambios» o seguir.
    public var isDiscardPromptPresented = false

    /// Lo que está en marcha: una ruedita en su sitio y los botones esperan (en la PWA, un aviso
    /// «Probando conexión...»).
    public enum Activity: Hashable, Sendable {
        case saving, downloading
    }

    public private(set) var activity: Activity?
    /// Por qué no se guardó (la conexión falló), debajo de los campos.
    public private(set) var connectionResult: Notice?

    public let version: AppVersion
    private let sync: SyncModel
    private let repositoryActor: TrainingRepository
    private var savedLocation: SyncLocation?
    /// Lo que tenían los campos al abrir, para saber si hay algo escrito sin guardar.
    private var loadedFields: [String] = ["", "", "", ""]

    public init(sync: SyncModel, repository: TrainingRepository, version: AppVersion) {
        self.sync = sync
        repositoryActor = repository
        self.version = version
    }

    /// "Versión 0.1 (15)": lo que ha instalado el NAS.
    public var versionLabel: String { "Versión \(version.label)" }

    /// Algo cambiado, con repo y token escritos, y nada en marcha.
    public var canSave: Bool {
        activity == nil && hasUnsavedChanges && SyncModel.isComplete(repository: repository, token: token)
    }
    /// Descargar trabaja con lo guardado.
    public var canTransfer: Bool { activity == nil && savedLocation != nil }

    public var status: SyncStatus { sync.status }
    public var statusText: String { sync.statusText }

    /// Al abrir: los campos con lo guardado.
    public func load() async {
        let configuration = await repositoryActor.configuration
        savedLocation = configuration.location
        if let location = configuration.location {
            repository = location.repository
            branch = location.branch
            path = location.path
        }
        token = configuration.token ?? ""
        loadedFields = fields
    }

    /// Algo escrito y sin guardar: deslizar la hoja hacia abajo no la cierra, para no perderlo
    /// (cerrarla con su botón sí lo descarta, y al volver a abrirla salen los campos guardados).
    public var hasUnsavedChanges: Bool { fields != loadedFields }

    private var fields: [String] { [repository, branch, path, token] }

    /// "Guardar": prueba lo escrito y, si va bien, lo guarda y cierra la hoja; si no, dice por qué
    /// debajo de los campos y no guarda nada. Rama y ruta vacías toman las de siempre.
    public func save() async {
        guard canSave else { return }
        connectionResult = nil
        await run(.saving) {
            let result = await sync.testConnection(repository: repository, branch: branch, path: path, token: token)
            guard result == SyncText.connected else {
                connectionResult = result
                return
            }
            let saved = await sync.configure(repository: repository, branch: branch, path: path, token: token)
            await load()
            if saved { sync.isSettingsPresented = false }
        }
    }

    /// La X: sin cambios, cierra; con cambios, pregunta antes de tirarlos.
    public func requestClose() {
        guard hasUnsavedChanges else { return sync.isSettingsPresented = false }
        isDiscardPromptPresented = true
    }

    /// «Descartar cambios». No depende del diálogo, que SwiftUI cierra antes de la acción.
    public func discardAndClose() {
        isDiscardPromptPresented = false
        sync.isSettingsPresented = false
    }

    public func keepEditing() {
        isDiscardPromptPresented = false
    }

    /// «Sustituir por los datos de GitHub»: primero se confirma.
    public func requestDownload() {
        isDownloadConfirmationPresented = true
    }

    public func confirmDownload() async {
        isDownloadConfirmationPresented = false
        guard canTransfer else { return }
        await run(.downloading) { await sync.download() }
    }

    private func run(_ activity: Activity, _ work: () async -> Void) async {
        self.activity = activity
        await work()
        self.activity = nil
    }
}
