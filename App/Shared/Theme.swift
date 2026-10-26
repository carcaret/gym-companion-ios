import Presentation
import SwiftUI

/// El estilo de la PWA (`index.css`): tema oscuro con la paleta tipo VS Code, tarjetas separadas
/// con borde fino y el color de cada día. La app va siempre en oscuro.
enum Theme {
    // Fondos y superficies
    static let background = Color(hex: 0x0F0F11)      // --bg-deep
    static let surface = Color(hex: 0x181A20)         // --surface: tarjeta
    static let surface2 = Color(hex: 0x1E2028)        // --surface-2: anidada o elevada
    static let cardSolid = Color(hex: 0x1C1E26)       // --bg-card-solid
    static let input = Color.white.opacity(0.05)      // --bg-input
    static let border = Color.white.opacity(0.09)     // --border
    static let borderLight = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.16)

    // Texto
    static let text = Color(hex: 0xD4D4D4)
    static let textSecondary = Color(hex: 0xD4D4D4).opacity(0.6)
    static let textMuted = Color(hex: 0xD4D4D4).opacity(0.35)

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
    static let focus = Color(hex: 0xE8B84B)           // la serie que se está editando

    // Radios
    static let radius: CGFloat = 14
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
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
