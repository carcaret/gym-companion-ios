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
    /// El cristal sobre un fondo con un resplandor suave de los colores de los días, para que el
    /// cristal tenga algo que refractar.
    case ambiente

    static var launchStyle: DesignStyle {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-estilo"), arguments.indices.contains(index + 1) else { return .pwa }
        return DesignStyle(rawValue: arguments[index + 1]) ?? .pwa
    }

    var isGlass: Bool { self == .cristal || self == .ambiente }
}

extension EnvironmentValues {
    @Entry var designStyle: DesignStyle = .pwa
}
