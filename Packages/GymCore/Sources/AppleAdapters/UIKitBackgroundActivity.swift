#if canImport(UIKit)
import Application
import UIKit

/// Pide a iOS tiempo para terminar un trabajo aunque la app pase a segundo plano (unos
/// segundos: de sobra para subir el `db.json`).
public struct UIKitBackgroundActivity: BackgroundActivity {
    public init() {}

    public func run(_ work: @escaping @Sendable () async -> Void) async {
        let task = await BackgroundTask.begin()
        await work()
        await task.end()
    }
}

@MainActor
private final class BackgroundTask {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    static func begin() -> BackgroundTask {
        let task = BackgroundTask()
        task.identifier = UIApplication.shared.beginBackgroundTask(withName: "Subir a GitHub") { task.end() }
        return task
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
#endif
