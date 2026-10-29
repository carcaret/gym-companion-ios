import XCTest

/// La app de entreno del reloj (Series 10 de 46 mm) con datos de ejemplo y un entreno de mentira, y
/// sus capturas; el CI las publica en el artefacto "capturas" junto a las del iPhone (ver CLAUDE.md).
final class WatchScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// El entreno midiéndose: el tiempo y el primer ejercicio; con la corona, el segundo; el
    /// descanso, que un toque empieza y otro para; la música, los controles y el resumen.
    @MainActor
    func testEntreno() {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demo.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Press Banca"].appears(timeout: 20))
        XCTAssertTrue(app.staticTexts["toca para descansar"].exists)
        capture(app, "70-reloj-entreno")

        for _ in 0..<15 where !app.staticTexts["Curl Bíceps"].exists {
            XCUIDevice.shared.rotateDigitalCrown(delta: 0.1)
        }
        XCTAssertTrue(app.staticTexts["Curl Bíceps"].appears(timeout: 5))
        capture(app, "71-reloj-siguiente")

        let rest = app.buttons[AccessibilityID.watchRest]
        rest.tap()
        XCTAssertTrue(app.staticTexts["descanso"].appears(timeout: 5))
        capture(app, "72-reloj-descanso")
        rest.tap()
        XCTAssertTrue(app.staticTexts["toca para descansar"].appears(timeout: 5))

        app.swipeRight()
        capture(app, "73-reloj-musica")
        app.swipeLeft()
        XCTAssertTrue(rest.appears(timeout: 5))

        app.swipeLeft()
        let finish = app.buttons[AccessibilityID.watchFinish]
        XCTAssertTrue(finish.appears(timeout: 5))
        capture(app, "74-reloj-controles")

        finish.tap()
        XCTAssertTrue(app.staticTexts["Entreno terminado"].appears(timeout: 10))
        capture(app, "75-reloj-resumen")

        // El entreno sigue abierto en el iPhone: se puede volver a empezar.
        app.buttons[AccessibilityID.watchDone].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.watchStart].appears(timeout: 5))
        capture(app, "76-reloj-empezar")
    }

    @MainActor
    func testSinEntreno() {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demoWithoutWorkout.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Empieza el entreno en el iPhone"].appears(timeout: 20))
        capture(app, "79-reloj-sin-entreno")
    }
}
