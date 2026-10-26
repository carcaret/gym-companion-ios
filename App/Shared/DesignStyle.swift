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
