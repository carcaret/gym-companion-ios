import SwiftUI

/// Las zonas de toque de 44 × 44 pt que pide Apple (repaso de la HIG, 2026-10-28). Un control que se
/// ve más pequeño se toca en una zona mayor, centrada, sin que crezca lo que se ve.
enum TouchTarget {
    static let minimum: CGFloat = 44

    /// La zona de toque de un control que se ve de `visible` pt: 44 como poco, y siempre 4 pt más
    /// por cada lado. Así dos controles en filas seguidas, sin hueco entre ellas, se ven a 8 pt y
    /// sus zonas no se montan, con cualquier tamaño de letra.
    static func side(for visible: CGFloat) -> CGFloat {
        max(minimum, visible + 8)
    }
}
