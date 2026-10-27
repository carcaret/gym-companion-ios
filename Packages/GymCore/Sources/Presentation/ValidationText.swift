/// Mensajes de error para la interfaz. Los de cada regla («Peso debe ser >= 0»…) eran los de la
/// PWA y ya no salen: la interfaz no deja llegar a esos errores (borrados el 2026-10-27).
public enum ValidationText {
    /// Al terminar el entreno o guardar una sesión del historial con campos sin rellenar o mal: los
    /// campos ya salen marcados, el aviso dice por qué no ha pasado nada.
    public static let reviewMarked = Notice("Revisa los campos marcados", .warning)
}
