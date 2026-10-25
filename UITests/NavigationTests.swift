import XCTest

/// Volver deslizando desde el borde: la pantalla se arrastra con el dedo y, si se suelta a medias,
/// se queda donde estaba. Antes el `onAppear` de la pantalla de debajo cerraba el detalle en cuanto
/// empezaba el gesto, y se saltaba a la anterior de golpe.
final class NavigationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDeslizarAMediasNoCierraElDetalleDelHistorial() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        let card = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))

        swipeBackHalfway(app)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Soltar a medias tiene que dejar el detalle abierto")

        swipeBackFully(app)
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Deslizar del todo vuelve a la lista")
    }

    @MainActor
    func testDeslizarAMediasNoCierraLaVistaPrevia() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        let start = app.buttons["start-workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))

        swipeBackHalfway(app)
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Soltar a medias tiene que dejar la vista previa abierta")

        swipeBackFully(app)
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 5), "Deslizar del todo vuelve al selector")
    }

    /// Desde el borde izquierdo hasta un cuarto de la pantalla, despacio, y soltar: iOS cancela.
    @MainActor
    private func swipeBackHalfway(_ app: XCUIApplication) {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    @MainActor
    private func swipeBackFully(_ app: XCUIApplication) {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }
}
