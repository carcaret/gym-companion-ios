import Application
import Domain
import Observation
import Presentation

/// Los ajustes de sincronización (`views/settings.js` de la PWA), en la hoja que abre el indicador:
/// dónde está el `db.json` de GitHub y el token, y los botones de probar, subir y descargar. La
/// sincronización la hace `SyncModel`.
@MainActor
@Observable
public final class SettingsModel {
    // Al cambiar un campo, el resultado de la última prueba ya no dice nada de lo escrito.
    public var repository = "" { didSet { connectionResult = nil } }
    public var branch = "" { didSet { connectionResult = nil } }
    public var path = "" { didSet { connectionResult = nil } }
    public var token = "" { didSet { connectionResult = nil } }
    /// Confirmación de "Descargar de GitHub" (sobreescribe lo local).
    public var isDownloadConfirmationPresented = false

    /// Lo que está en marcha: su fila enseña una ruedita y los botones esperan (en la PWA, un
    /// aviso «Probando conexión...», «Subiendo...»).
    public enum Activity: Hashable, Sendable {
        case saving, testing, downloading
    }

    public private(set) var activity: Activity?
    /// El resultado de «Probar conexión», debajo del botón.
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

    /// Repo y token escritos, y nada en marcha.
    public var canSave: Bool { activity == nil && SyncModel.isComplete(repository: repository, token: token) }
    /// Se prueba lo escrito, sin guardarlo antes.
    public var canTestConnection: Bool { canSave }
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

    /// "Guardar": rama y ruta vacías toman las de siempre.
    public func save() async {
        guard canSave else { return }
        await run(.saving) {
            await sync.configure(repository: repository, branch: branch, path: path, token: token)
            await load()
        }
    }

    /// "Probar conexión": con lo escrito, sin guardar nada ni tocar los datos.
    public func testConnection() async {
        guard canTestConnection else { return }
        connectionResult = nil
        await run(.testing) {
            let result = await sync.testConnection(repository: repository, branch: branch, path: path, token: token)
            connectionResult = result
        }
    }

    /// "Descargar de GitHub": primero se confirma.
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
