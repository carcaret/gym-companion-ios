import XCTest

/// Capturas del reloj (Series 10 de 46 mm) con datos de ejemplo; el CI las publica en el artefacto
/// "capturas" junto a las del iPhone (ver CLAUDE.md).
final class WatchScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// El entreno en curso: el primer ejercicio y, deslizando, el segundo.
    @MainActor
    func testEntreno() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Press Banca"].waitForExistence(timeout: 20))
        capture(app, "70-reloj-ejercicio")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Curl Bíceps"].waitForExistence(timeout: 10))
        capture(app, "71-reloj-siguiente")
    }

    @MainActor
    func testSinEntreno() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-sin-entreno"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sin entreno en curso"].waitForExistence(timeout: 20))
        capture(app, "72-reloj-sin-entreno")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
