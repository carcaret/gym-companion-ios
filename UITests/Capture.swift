import XCTest

extension XCTestCase {
    /// Guarda una captura de la pantalla en el resultado; el CI la publica en el artefacto
    /// "capturas" con este nombre (ver CLAUDE.md).
    @MainActor
    func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
