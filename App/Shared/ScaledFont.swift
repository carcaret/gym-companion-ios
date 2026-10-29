import SwiftUI

extension View {
    /// La letra del sistema al tamaño de la PWA, que crece y mengua con la letra del iPhone
    /// (Dynamic Type). Con el tamaño normal mide lo mismo que `.font(.system(size:))`, que no
    /// escala: no se usa en ninguna vista.
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.style(for: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }

    /// El estilo de iOS de tamaño más parecido, para que crezca a su ritmo: los pequeños crecen
    /// menos que el cuerpo del texto.
    private static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14.5: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<19: .body
        default: .title3
        }
    }
}
