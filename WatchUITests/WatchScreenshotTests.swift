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
        app.launchArguments = [LaunchArgument.demo.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Press Banca"].appears(timeout: 20))
        capture(app, "70-reloj-ejercicio")

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Curl Bíceps"].appears(timeout: 10))
        capture(app, "71-reloj-siguiente")
    }

    @MainActor
    func testSinEntreno() {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demoWithoutWorkout.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sin entreno en curso"].appears(timeout: 20))
        capture(app, "72-reloj-sin-entreno")
    }
}
