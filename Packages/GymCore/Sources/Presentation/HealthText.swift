import Domain

/// Los textos de lo que se sube de Salud (`salud.json`, #104), en los ajustes de sincronización.
public enum HealthText {
    public static let section = "Salud"
    public static let explanation = "Peso, grasa, cintura y comida de Salud, en salud.json junto al db.json, para analizarlos. Se sube solo al abrir la app."

    public static let checking = "Comprobando…"
    public static let notConfigured = "Sin GitHub no se sube"
    public static let unavailable = "Este aparato no tiene Salud"
    public static let readFailed = "No se pudo leer Salud"
    /// iOS no dice a la app si se negó el permiso de lectura: parece que no hay datos.
    public static let empty = "Sin datos. Revisa en Salud que Gym pueda leer peso, grasa, cintura y nutrición."
    public static let offline = "Sin conexión con GitHub; se subirá al volver a la app"
    public static let uploadFailed = "No se pudo subir a GitHub; se intentará al volver a la app"

    /// «412 pesajes · 6 medidas de cintura · 380 días de comida · al día».
    public static func upToDate(_ summary: HealthRecord.Summary) -> String { "\(counts(summary)) · al día" }
    public static func uploaded(_ summary: HealthRecord.Summary) -> String { "\(counts(summary)) · subido" }

    static func counts(_ summary: HealthRecord.Summary) -> String {
        [Plural.weighings(summary.weighings), Plural.waistMeasurements(summary.waistMeasurements),
         Plural.nutritionDays(summary.nutritionDays)].joined(separator: " · ")
    }
}
