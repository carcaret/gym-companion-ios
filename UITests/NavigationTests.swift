import XCTest

/// La navegación de iOS. Volver deslizando desde el borde: la pantalla se arrastra con el dedo y,
/// si se suelta a medias, se queda donde estaba (antes el `onAppear` de la pantalla de debajo
/// cerraba el detalle en cuanto empezaba el gesto). Y las pestañas: cada una conserva su pantalla,
/// y tocar otra vez la activa vuelve a la de entrada.
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

    /// Como en iOS: cambiar de pestaña y volver deja la pantalla donde estaba (decisión del
    /// usuario, 2026-10-25; la PWA volvía a la de entrada).
    @MainActor
    func testCambiarDePestanaConservaLaPantalla() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        first.tap()
        let card = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))

        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Al volver a Historial tiene que seguir el detalle")
    }

    /// Tocar otra vez la pestaña activa vuelve a su pantalla de entrada: el detalle del historial,
    /// la vista previa de una rutina y lo empujado en Progreso.
    @MainActor
    func testTocarOtraVezLaPestanaVuelveALaEntrada() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        first.tap()
        XCTAssertTrue(app.buttons["card-press_banca"].firstMatch.waitForExistence(timeout: 20))
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Tocar otra vez Historial vuelve a la lista")

        app.tabBars.buttons["Rutinas"].tap()
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 10), "Tocar otra vez Rutinas vuelve al selector")

        app.tabBars.buttons["Progreso"].tap()
        openChartsFromProgress(app)
        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.navigationBars["Estadísticas"].waitForExistence(timeout: 10), "Tocar otra vez Progreso cierra las gráficas")
    }

    /// «Ver en Gráficas» empuja las gráficas dentro de Progreso, sin cambiar de pestaña, y se vuelve
    /// deslizando desde el borde, como en iOS (decisión del usuario, 2026-10-25).
    @MainActor
    func testVerEnGraficasEntraEmpujadaEnProgreso() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Progreso"].tap()
        openChartsFromProgress(app)
        XCTAssertTrue(app.tabBars.buttons["Progreso"].isSelected, "Las gráficas se abren dentro de Progreso")
        // La fila del ejercicio es un `NavigationLink`: su texto va en la etiqueta del botón.
        XCTAssertTrue(app.buttons["chart-exercise"].label.contains("Press Banca"), "Con el ejercicio elegido")

        swipeBackFully(app)
        XCTAssertTrue(app.navigationBars["Estadísticas"].waitForExistence(timeout: 10), "Deslizar vuelve a Estadísticas")
    }

    @MainActor
    private func openChartsFromProgress(_ app: XCUIApplication) {
        let expand = app.buttons["stats-exercises"]
        XCTAssertTrue(expand.waitForExistence(timeout: 20))
        expand.tap()
        let row = app.buttons["stats-row-press_banca"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let open = app.buttons["Ver en Gráficas"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.navigationBars["Gráficas"].waitForExistence(timeout: 20))
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
