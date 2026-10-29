/// Puerto: pedir al sistema que deje terminar un trabajo aunque la app pase a segundo plano (el
/// `keepalive` del `fetch` de la PWA; en iOS, una tarea en segundo plano).
public protocol BackgroundActivity: Sendable {
    func run(_ work: @escaping @Sendable () async -> Void) async
}
