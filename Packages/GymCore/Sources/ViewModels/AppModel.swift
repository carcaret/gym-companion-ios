import Application
import Domain
import Observation
import Presentation

/// Estado de la app: los datos del usuario, cargados al arrancar. Las pantallas los leen de aquí
/// y le pasan sus cambios, que se guardan y se sincronizan (`TrainingRepository`).
@MainActor
@Observable
public final class AppModel {
    public private(set) var data: TrainingData? {
        didSet { watch?.send(data) }
    }
    /// Los datos, o vacíos mientras no se han cargado: lo que leen las pantallas.
    var current: TrainingData { data ?? TrainingData() }
    /// Si los datos guardados no se pudieron leer: no se machacan, se avisa.
    public private(set) var loadError: String?
    /// Si un cambio no se pudo guardar en el iPhone. Al pasar de guardar bien a fallar, se avisa
    /// una vez (`isSaveErrorPresented`); los fallos siguientes no repiten el aviso.
    public private(set) var saveError: String? {
        didSet { if oldValue == nil, saveError != nil { isSaveErrorPresented = true } }
    }
    public var isSaveErrorPresented = false
    /// El aviso breve que hay que enseñar (uno para toda la app, como el toast de la PWA); la
    /// vista lo quita cuando se ha visto.
    public var notice: Notice?

    private let repository: TrainingRepository
    private let watch: WatchRelay?

    public init(repository: TrainingRepository, watch: WatchRelay? = nil) {
        self.repository = repository
        self.watch = watch
    }

    public func start() async {
        guard data == nil else { return }
        do {
            data = try await repository.start()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    /// Un cambio de cualquier pantalla: se ve al momento y se guarda.
    public func update(_ newData: TrainingData) async {
        data = newData
        do {
            try await repository.update(newData)
            saveError = nil
        } catch {
            saveError = String(describing: error)
        }
    }

    /// «Reintentar» en la alerta de «No se pudo guardar»: vuelve a guardar lo que se ve. Si sigue
    /// fallando, lo vuelve a decir, porque lo ha pedido el usuario.
    public func retrySave() async {
        guard let data else { return }
        await update(data)
        if saveError != nil { isSaveErrorPresented = true }
    }

    /// Terminar el entreno: se guarda y se sube ya.
    public func finishWorkout(_ newData: TrainingData) async -> UploadResult {
        data = newData
        do {
            let result = try await repository.saveAndUpload(newData)
            saveError = nil
            return result
        } catch {
            saveError = String(describing: error)
            return .failed
        }
    }

    /// Al volver a la app: el reloj se pone al día aunque los datos no hayan cambiado (puede ser
    /// otro día).
    public func refreshWatch() {
        watch?.send(data)
    }

    /// Lo remoto sustituye a lo local (lo decide la sincronización). Si los datos no se podían leer,
    /// ya están: los de GitHub, guardados encima.
    func replace(with remoteData: TrainingData) {
        data = remoteData
        loadError = nil
    }
}
