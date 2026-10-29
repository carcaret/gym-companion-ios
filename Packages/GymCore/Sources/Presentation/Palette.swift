/// Los colores del tema oscuro que tienen que leerse (fondos, texto y los fondos de las acciones con
/// texto blanco), aquí para que sus tests comprueben el contraste. `Theme` los pinta.
public enum Palette {
    // Fondos
    public static let background = RGB(hex: 0x0F0F11)
    public static let surface = RGB(hex: 0x181A20)
    public static let surface2 = RGB(hex: 0x1E2028)
    public static let cardSolid = RGB(hex: 0x1C1E26)
    /// Los fondos sobre los que va texto: la pantalla, las tarjetas y las anidadas.
    public static let backgrounds = [background, surface, surface2, cardSolid]

    // Texto
    public static let text = RGB(hex: 0xD4D4D4)
    /// El texto secundario es el principal con esta opacidad: 4,5:1 sobre cualquier fondo, lo que
    /// pide Apple para texto pequeño (repaso de la HIG, 2026-10-28; había un gris más tenue, de
    /// 2,5:1, que no se leía).
    public static let secondaryTextOpacity = 0.6

    // Fondos de las acciones de deslizar, con el texto blanco de iOS encima: los colores de la PWA
    // (azul 2,9:1 y rojo 3,6:1) no llegaban.
    public static let actionBlue = RGB(hex: 0x3A78AD)
    public static let actionRed = RGB(hex: 0xC93434)
    public static let actionGray = RGB(hex: 0x5A5A5F)
    public static let actions = [actionBlue, actionRed, actionGray]
    public static let white = RGB(hex: 0xFFFFFF)
}
