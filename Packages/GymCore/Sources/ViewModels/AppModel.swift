import Application
import Domain
import Observation

/// Estado de la app: los datos del usuario, cargados al arrancar.
@MainActor
@Observable
public final class AppModel {
    public private(set) var data: TrainingData?
    /// Si los datos guardados no se pudieron leer: no se machacan, se avisa.
    public private(set) var loadError: String?

    private let startUp: StartUp

    public init(startUp: StartUp) {
        self.startUp = startUp
    }

    public func start() async {
        guard data == nil else { return }
        do {
            data = try await startUp.run()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }
}
