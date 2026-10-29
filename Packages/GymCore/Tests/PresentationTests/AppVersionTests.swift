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
