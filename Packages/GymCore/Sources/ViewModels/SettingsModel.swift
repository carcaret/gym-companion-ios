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
    public var repository = ""
    public var branch = ""
    public var path = ""
    public var token = ""
    /// Confirmación de "Descargar de GitHub" (sobreescribe lo local).
    public var isDownloadConfirmationPresented = false

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
        await sync.configure(repository: repository, branch: branch, path: path, token: token)
        await load()
    }

    /// "Probar conexión": con lo guardado y el token escrito, sin tocar los datos.
    public func testConnection() async {
        guard let location = savedLocation, !token.trimmingWhitespace().isEmpty else {
            sync.notice = SyncText.saveFirst
            return
        }
        await sync.testConnection(repository: location.repository, branch: location.branch, path: location.path, token: token)
    }

    /// "Subir a GitHub".
    public func upload() async {
        await sync.forceUpload()
    }

    /// "Descargar de GitHub": primero se confirma.
    public func requestDownload() {
        isDownloadConfirmationPresented = true
    }

    public func confirmDownload() async {
        isDownloadConfirmationPresented = false
        await sync.download()
    }
}
