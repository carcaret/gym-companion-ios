import Application
import Domain
import Observation
import Presentation

/// Estado de la app: los datos del usuario, cargados al arrancar. Las pantallas los leen de aquí
/// y le pasan sus cambios, que se guardan y se sincronizan (`TrainingRepository`).
@MainActor
@Observable
public final class AppModel {
    public private(set) var data: TrainingData?
    /// Si los datos guardados no se pudieron leer: no se machacan, se avisa.
    public private(set) var loadError: String?
    /// Si un cambio no se pudo guardar en el iPhone.
    public private(set) var saveError: String?
    /// El aviso breve que hay que enseñar (uno para toda la app, como el toast de la PWA); la
    /// vista lo quita cuando se ha visto.
    public var notice: Notice?

    private let repository: TrainingRepository

    public init(repository: TrainingRepository) {
        self.repository = repository
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

    /// Lo remoto sustituye a lo local (lo decide la sincronización).
    func replace(with remoteData: TrainingData) {
        data = remoteData
    }
}
