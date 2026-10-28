import Foundation
import Presentation
import Testing

/// El texto se lee: Apple pide un contraste de 4,5:1 para texto pequeño (repaso de la HIG,
/// 2026-10-28). Antes, el gris tenue daba 2,5:1 y el blanco de las acciones de deslizar, 2,9:1
/// sobre el azul y 3,6:1 sobre el rojo.
@Suite("Contraste de los colores")
struct PaletteTests {
    @Test("el texto secundario se lee sobre cualquier fondo")
    func secondaryText() {
        for background in Palette.backgrounds {
            let text = Palette.text.over(background, opacity: Palette.secondaryTextOpacity)
            #expect(text.contrast(with: background) >= 4.5, "\(text.text) sobre \(background.text)")
        }
    }

    @Test("el texto principal se lee sobre cualquier fondo")
    func primaryText() {
        for background in Palette.backgrounds {
            #expect(Palette.text.contrast(with: background) >= 4.5, "sobre \(background.text)")
        }
    }

    @Test("el blanco de las acciones de deslizar se lee sobre su fondo")
    func actions() {
        for action in Palette.actions {
            #expect(Palette.white.contrast(with: action) >= 4.5, "sobre \(action.text)")
        }
    }

    @Test("el contraste es el de WCAG: blanco sobre negro, 21:1; un color consigo mismo, 1:1")
    func formula() {
        let black = RGB(hex: 0x000000)
        #expect(abs(Palette.white.contrast(with: black) - 21) < 0.001)
        #expect(abs(Palette.text.contrast(with: Palette.text) - 1) < 0.001)
        // El azul de la PWA con el blanco encima, el que se cambió.
        #expect(abs(Palette.white.contrast(with: RGB(hex: 0x569CD6)) - 2.95) < 0.01)
    }
}

extension RGB {
    /// Este color con `opacity` encima de `background`, como lo pinta la pantalla.
    func over(_ background: RGB, opacity: Double) -> RGB {
        func channel(_ front: Int, _ back: Int) -> Int { Int((Double(front) * opacity + Double(back) * (1 - opacity)).rounded()) }
        return RGB(r: channel(r, background.r), g: channel(g, background.g), b: channel(b, background.b))
    }

    /// El contraste entre dos colores según WCAG 2, de 1 a 21.
    func contrast(with other: RGB) -> Double {
        let (light, dark) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (light + 0.05) / (dark + 0.05)
    }

    private var luminance: Double {
        func channel(_ value: Int) -> Double {
            let c = Double(value) / 255
            return c <= 0.039_28 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
