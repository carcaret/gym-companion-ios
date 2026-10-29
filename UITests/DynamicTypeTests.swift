import XCTest

/// La letra sigue el tamaño de texto del iPhone (Dynamic Type): con letra grande, las tarjetas
/// crecen para que quepa. Con el tamaño normal todo mide lo que en la PWA.
final class DynamicTypeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Con un solo arranque, con letra grande: abrir, cerrar y volver a abrir la app para medirla
    /// también con letra normal fallaba a veces al relanzar en el simulador (2026-10-26). La
    /// tarjeta del Día 1 mide unos 75 pt con la letra normal y unos 119 con esta.
    @MainActor
    func testLaLetraGrandeAgrandaLasTarjetas() {
        let app = XCUIApplication.launchDemo(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"])
        app.tabBars.buttons["Rutinas"].tap()
        let card = app.buttons["routine-DIA1"]
        XCTAssertTrue(card.appears(timeout: 20))
        XCTAssertGreaterThan(card.frame.height, 100, "Con letra grande la tarjeta de la rutina tiene que crecer")
        capture(app, "70-letra-grande-rutinas")

        card.tap()
        app.buttons["start-workout"].tap()
        let exercise = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(exercise.appears(timeout: 20))
        exercise.tap()
        capture(app, "70-letra-grande-entreno")
    }
}
