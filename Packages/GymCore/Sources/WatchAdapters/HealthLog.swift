#if canImport(os)
import os

/// El registro del sistema de lo que pasa con los entrenos de Salud entre el iPhone y el reloj: se
/// lee desde el NAS con pymobiledevice3 (`docs/pendiente-nas.md`), con el subsistema
/// `com.carcaret.gymcompanion` y la categoría `salud`.
public enum HealthLog {
    public static let logger = Logger(subsystem: "com.carcaret.gymcompanion", category: "salud")
}
#endif
