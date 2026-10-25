import XCTest

/// Recorre las pantallas principales y guarda una captura de cada una en el resultado de los
/// tests; el CI las publica como artefacto "capturas" (ver CLAUDE.md).
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testInicio() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Gym Companion"].waitForExistence(timeout: 10))
        capture(app, "01-inicio")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
