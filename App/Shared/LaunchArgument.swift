/// Los argumentos de arranque de las capturas y los tests de interfaz. Los comparten la app del
/// iPhone, la del reloj y sus tests de interfaz (`project.yml`), para que nadie escriba el texto a
/// mano.
enum LaunchArgument: String {
    /// Datos de ejemplo en una carpeta temporal y sin GitHub (`DemoData`).
    case demo = "-demo"
    /// El reloj, sin entreno en curso.
    case demoWithoutWorkout = "-demo-sin-entreno"
    /// Con `demo`, el fichero de los datos estropeado (la pantalla de error).
    case unreadableData = "-datos-ilegibles"
    /// Avisos de 10 s: XCUITest espera a que la app se quede quieta, y tras una animación larga
    /// (tirar para sincronizar) el aviso de 2,5 s ya se había ido.
    case longNotices = "-avisos-largos"

    func isPresent(in arguments: [String]) -> Bool {
        arguments.contains(rawValue)
    }
}
