import SwiftUI

/// PRUEBA DE DISEÑO (rama `diseno-ios`): el mismo contenido con varios acabados, para compararlos
/// en las capturas del CI antes de elegir uno. Se elige al arrancar con `-estilo <nombre>`; sin él,
/// el de la PWA. Al decidir, se queda el elegido y esto desaparece.
enum DesignStyle: String, CaseIterable {
    /// El de ahora: superficies planas con borde fino y el filete del día a la izquierda.
    case pwa
    /// Liquid Glass de iOS 26 (como el botón de la nube), teñido con el color del día.
    case cristal
    /// Celdas de iOS sólidas: esquinas continuas más redondas, sin borde, el color del día en una
    /// píldora y botones rellenos como los de iOS.
    case nativo
    /// Cristal teñido en las tarjetas que se tocan enteras (rutinas, sesiones del historial, las que
    /// llevan el color del día) y sólido como `nativo` en las de ejercicio; botones de cristal.
    case mixto

    static var launchStyle: DesignStyle {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-estilo"), arguments.indices.contains(index + 1) else { return .pwa }
        return DesignStyle(rawValue: arguments[index + 1]) ?? .pwa
    }
}

extension EnvironmentValues {
    @Entry var designStyle: DesignStyle = .pwa
}

/// PRUEBA DE DISEÑO: la pantalla en la que arranca la app con `-pantalla <nombre>` (con `-demo`),
/// para que el CI saque cada captura con `simctl` sin tests de interfaz.
enum DesignScreen: String {
    case rutinas, historial, progreso, vistaPrevia = "vista-previa", entreno, tarjeta

    static var launchScreen: DesignScreen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-pantalla"), arguments.indices.contains(index + 1) else { return nil }
        return DesignScreen(rawValue: arguments[index + 1])
    }

    @MainActor
    func open(in root: CompositionRoot) async {
        switch self {
        case .rutinas: break
        case .historial: root.navigation.select(.history)
        case .progreso:
            root.navigation.select(.progress)
            root.progress.toggleExpanded()
        case .vistaPrevia: root.today.select("DIA1")
        case .entreno, .tarjeta:
            root.today.select("DIA1")
            await root.today.start()
            if self == .tarjeta { root.today.toggleCard("press_banca") }
        }
    }
}
