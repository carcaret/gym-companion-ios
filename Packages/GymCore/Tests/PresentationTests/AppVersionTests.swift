import Presentation
import Testing

@Suite("AppVersion")
struct AppVersionTests {
    @Test("la etiqueta junta versión y compilación")
    func label() {
        #expect(AppVersion(marketing: "0.1", build: "7").label == "0.1 (7)")
    }

    @Test("sin datos del bundle, interrogantes")
    func missingValues() {
        #expect(AppVersion(marketing: nil, build: nil).label == "? (?)")
    }
}

@Suite("La versión en Ajustes")
struct SettingsVersionTextTests {
    @Test("la versión instalada")
    func version() {
        #expect(SettingsText.version(AppVersion(marketing: "1.0", build: "231")) == "Versión 1.0 (231)")
    }
}
