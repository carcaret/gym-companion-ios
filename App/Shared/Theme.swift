import Presentation
import SwiftUI

/// El estilo de la PWA (`index.css`): tema oscuro con la paleta tipo VS Code, tarjetas separadas
/// con borde fino y el color de cada día. La app va siempre en oscuro.
enum Theme {
    // Fondos y superficies
    // Los que tienen que leerse están en `Palette`, donde sus tests comprueban el contraste.
    static let background = Color(Palette.background) // --bg-deep
    static let surface = Color(Palette.surface)       // --surface: tarjeta
    static let surface2 = Color(Palette.surface2)     // --surface-2: anidada o elevada
    static let cardSolid = Color(Palette.cardSolid)   // --bg-card-solid
    static let input = Color.white.opacity(0.05)      // --bg-input
    static let border = Color.white.opacity(0.09)     // --border
    static let borderLight = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.16)

    // Texto
    static let text = Color(Palette.text)
    /// También lo apagado (saltado, sin datos): un gris más tenue no se leía (repaso de la HIG,
    /// 2026-10-28).
    static let textSecondary = Color(Palette.text).opacity(Palette.secondaryTextOpacity)

    // Colores
    static let accent = Color(hex: 0x569CD6)
    static let accentLight = Color(hex: 0x9CDCFE)
    static let accentSoft = Color(hex: 0x93C5EA)
    static let accentTint = Color(hex: 0x569CD6).opacity(0.15)
    static let green = Color(hex: 0x6A9955)
    static let greenSoft = Color(hex: 0x5DCAA5)
    static let greenTint = Color(hex: 0x5DCAA5).opacity(0.15)
    static let red = Color(hex: 0xF44747)
    static let redSoft = Color(hex: 0xE2706A)
    static let redTint = Color(hex: 0xF44747).opacity(0.12)
    static let skipTint = Color(hex: 0xF44747).opacity(0.06)
    static let danger = Color(hex: 0xD97070)
    static let dangerTint = Color(hex: 0xD97070).opacity(0.15)
    static let orange = Color(hex: 0xCE9178)
    static let gold = Color(hex: 0xDCDCAA)

    // Un color, un significado (repaso de la HIG, 2026-10-28): verde es solo «sincronizado» o
    // «bien»; rojo, solo error o lo que borra.
    /// Por debajo del objetivo (antes, verde).
    static let below = Color(hex: 0xCE9178)
    static let belowTint = Color(hex: 0xCE9178).opacity(0.14)
    /// Por encima del objetivo: el azul de cumplido, más fuerte (antes, rojo, como un error).
    static let aboveText = Color(hex: 0xCFE6FB)
    static let aboveTint = Color(hex: 0x569CD6).opacity(0.28)

    /// Fondos de las acciones de deslizar, con el texto blanco de iOS.
    static let actionBlue = Color(Palette.actionBlue)
    static let actionRed = Color(Palette.actionRed)
    static let actionGray = Color(Palette.actionGray)

    // Radios
    /// Las tarjetas, con las esquinas de las secciones de lista de iOS 26 (la PWA usaba 14): así las
    /// tarjetas y las listas nativas son de la misma familia (decisión del usuario, 2026-10-27).
    static let radius: CGFloat = 26
    static let radiusSmall: CGFloat = 10
    static let radiusTag: CGFloat = 6

    /// `--color-dia1..3`.
    static func color(_ tint: RoutineTint?) -> Color? {
        switch tint {
        case .day1: Color(hex: 0x7AAEE0)
        case .day2: Color(hex: 0x7FCAB1)
        case .day3: Color(hex: 0xCABE7A)
        case nil: nil
        }
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
