/// Un aviso breve para el usuario (el `toast` de la PWA).
public struct Notice: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Algo en curso, sin juicio.
        case info
        case success
        case warning
        case error
    }

    public let text: String
    public let kind: Kind

    public init(_ text: String, _ kind: Kind = .info) {
        self.text = text
        self.kind = kind
    }

    /// Un error no se va solo: espera a que se cierre (repaso de la HIG, 2026-10-28). Lo demás se
    /// va a los pocos segundos.
    public var staysUntilDismissed: Bool { kind == .error }

    /// La acción de VoiceOver que cierra el aviso (con el dedo, se desliza hacia arriba o se toca).
    public static let dismissLabel = "Cerrar aviso"
}
