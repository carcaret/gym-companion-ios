/// Un color RGB de 0 a 255.
public struct RGB: Hashable, Sendable {
    public let r: Int
    public let g: Int
    public let b: Int

    public init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// "rgb(30,58,80)", como el CSS de la PWA.
    public var text: String { "rgb(\(r),\(g),\(b))" }

    public init(hex: UInt32) {
        self.init(r: Int((hex >> 16) & 0xFF), g: Int((hex >> 8) & 0xFF), b: Int(hex & 0xFF))
    }
}
