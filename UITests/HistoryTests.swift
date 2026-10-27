import XCTest

/// El borrado de una sesión tal como lo hace el usuario: deslizar, "Borrar" y confirmar en la
/// alerta. Lo que no ven los tests del modelo: SwiftUI cierra la alerta antes de ejecutar la acción
/// del botón, y el borrado no puede depender de lo que ese cierre descarta.
final class HistoryTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBorrarDeslizandoLaFila() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.appears(timeout: 10))
        let row = app.buttons[first.identifier]

        row.swipeLeft()
        let swipeDelete = app.buttons["Borrar"].firstMatch
        XCTAssertTrue(swipeDelete.appears(timeout: 5))
        swipeDelete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.appears(timeout: 5))
        alert.buttons["Borrar"].tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
        wait(for: [gone], timeout: 5)
    }

    /// Mientras se confirma, la lista no cambia: con `role: .destructive` la lista daba la fila
    /// por borrada al tocar el botón de deslizar, la quitaba y SwiftUI la volvía a meter, con las
    /// filas cambiadas de sitio a la vista (2026-10-25). Cancelar la deja igual.
    @MainActor
    func testConfirmarElBorradoNoQuitaLaFilaAntesDeTiempo() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'"))
        XCTAssertTrue(rows.firstMatch.appears(timeout: 10))
        let before = rows.allElementsBoundByIndex.map(\.identifier)
        XCTAssertGreaterThan(before.count, 2)

        app.buttons[before[0]].swipeLeft()
        let swipeDelete = app.buttons["Borrar"].firstMatch
        XCTAssertTrue(swipeDelete.appears(timeout: 5))
        swipeDelete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.appears(timeout: 5))
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), before)

        alert.buttons["Cancelar"].tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: alert)
        wait(for: [closed], timeout: 5)
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), before)
    }

    /// Tirar hacia abajo de la lista sincroniza con GitHub y dice cómo ha quedado; con `-demo` no
    /// hay GitHub, y lo dice. Con `-avisos-largos`: XCUITest espera a que acaben las animaciones
    /// del refresco antes de buscar, y con los 2,5 s de siempre el aviso ya se había ido (en la
    /// grabación del CI se ve la lista bajar, la ruedita y el aviso; 2026-10-26).
    @MainActor
    func testTirarHaciaAbajoSincroniza() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-avisos-largos"]
        app.launch()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.appears(timeout: 20))

        // Desde la parte vacía de la lista, debajo de las filas, hasta abajo, aguantando antes de
        // soltar para pasar del umbral del refresco.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            .press(forDuration: 0, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)),
                   withVelocity: .default, thenHoldForDuration: 1)
        let notice = app.staticTexts.matching(identifier: "notice").firstMatch
        XCTAssertTrue(notice.appears(timeout: 10))
        XCTAssertEqual(notice.label, "GitHub no configurado")

        // Sale arriba, lejos de las píldoras y de la barra de pestañas (2026-10-27), y se va
        // deslizándolo hacia arriba.
        XCTAssertLessThan(notice.frame.maxY, app.frame.height / 3)
        notice.swipeUp()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
        wait(for: [gone], timeout: 5)
    }
}
