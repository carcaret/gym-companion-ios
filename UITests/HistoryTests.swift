import XCTest

/// El borrado de una sesión tal como lo hace el usuario: deslizar, "Borrar" y confirmar en el globo
/// que apunta a la fila, como quitar un ejercicio del entreno (repaso de la HIG, 2026-10-28; antes,
/// una alerta). Lo que no ven los tests del modelo: SwiftUI cierra el globo antes de ejecutar la
/// acción del botón, y el borrado no puede depender de lo que ese cierre descarta.
final class HistoryTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBorrarDeslizandoLaFila() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.appears(timeout: 10))
        let row = app.buttons[first.identifier]

        row.swipeLeft()
        let swipeDelete = app.buttons["Borrar"].firstMatch
        XCTAssertTrue(swipeDelete.appears(timeout: 5))
        swipeDelete.tap()

        let confirm = app.buttons["Borrar entreno"].firstMatch
        XCTAssertTrue(confirm.appears(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists, "Es un globo, no una alerta")
        confirm.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
        wait(for: [gone], timeout: 5)
    }

    /// Mientras se confirma, la lista no cambia: con `role: .destructive` la lista daba la fila
    /// por borrada al tocar el botón de deslizar, la quitaba y SwiftUI la volvía a meter, con las
    /// filas cambiadas de sitio a la vista (2026-10-25). Cancelar la deja igual.
    @MainActor
    func testConfirmarElBorradoNoQuitaLaFilaAntesDeTiempo() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'"))
        XCTAssertTrue(rows.firstMatch.appears(timeout: 10))
        let before = rows.allElementsBoundByIndex.map(\.identifier)
        XCTAssertGreaterThan(before.count, 2)

        app.buttons[before[0]].swipeLeft()
        let swipeDelete = app.buttons["Borrar"].firstMatch
        XCTAssertTrue(swipeDelete.appears(timeout: 5))
        swipeDelete.tap()
        let confirm = app.buttons["Borrar entreno"].firstMatch
        XCTAssertTrue(confirm.appears(timeout: 5))
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), before)

        // En iOS 26 el globo no tiene «Cancelar»: se cierra tocando fuera.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: confirm)
        wait(for: [closed], timeout: 5)
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.identifier), before)
    }

    /// Tirar hacia abajo de la lista sincroniza con GitHub y dice cómo ha quedado; con `-demo` no
    /// hay GitHub, y lo dice. Con `-avisos-largos`: XCUITest espera a que acaben las animaciones
    /// del refresco antes de buscar, y con los 2,5 s de siempre el aviso ya se había ido (en la
    /// grabación del CI se ve la lista bajar, la ruedita y el aviso; 2026-10-26).
    @MainActor
    func testTirarHaciaAbajoSincroniza() {
        let app = XCUIApplication.launchDemo(.longNotices)
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
        // deslizándolo hacia arriba: un arrastre corto, dentro de la pantalla, como el del dedo
        // (`swipeUp` arrastra media pantalla y acaba fuera de ella).
        XCTAssertLessThan(notice.frame.maxY, app.frame.height / 3)
        let start = notice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -50)))
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
        wait(for: [gone], timeout: 5)
    }
    /// El detalle es de solo lectura y se corrige con «Editar», en una hoja (2026-10-27): con cambios
    /// no se cierra deslizando, y la ✕ pregunta y, al descartar, deja lo guardado.
    @MainActor
    func testEditarYCancelarDescarta() {
        let app = openFirstSessionCard()
        let value = app.descendants(matching: .any)["weight-value"].firstMatch
        XCTAssertTrue(value.appears(timeout: 10))
        let saved = value.value as? String
        XCTAssertFalse(app.buttons["weight-plus"].exists, "Sin «Editar», la tarjeta no se puede cambiar")
        // «Editar», a la izquierda de la nube, que sigue en la esquina (2026-10-27).
        XCTAssertLessThan(app.buttons["session-edit"].frame.maxX, app.buttons["sync-indicator"].firstMatch.frame.minX)

        app.buttons["session-edit"].tap()
        let plus = app.buttons["weight-plus"].firstMatch
        XCTAssertTrue(plus.appears(timeout: 5))
        plus.tap()
        XCTAssertNotEqual(app.textFields["weight-field"].firstMatch.value as? String, saved)

        // La hoja de editar, con cambios, no se cierra deslizando hacia abajo.
        app.navigationBars.firstMatch.swipeDown()
        XCTAssertTrue(app.buttons["session-cancel"].appears(timeout: 5), "Con cambios, deslizar no cierra la hoja")

        app.buttons["session-cancel"].tap()
        let discard = app.buttons["Descartar cambios"].firstMatch
        XCTAssertTrue(discard.appears(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["session-edit"].appears(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["weight-value"].firstMatch.value as? String, saved)
    }

    /// La ✓ guarda y vuelve a solo lectura con lo cambiado.
    @MainActor
    func testEditarYOKGuarda() {
        let app = openFirstSessionCard()
        let value = app.descendants(matching: .any)["weight-value"].firstMatch
        XCTAssertTrue(value.appears(timeout: 10))
        let saved = value.value as? String

        app.buttons["session-edit"].tap()
        let plus = app.buttons["weight-plus"].firstMatch
        XCTAssertTrue(plus.appears(timeout: 5))
        // La ✓, apagada sin cambios (2026-10-28).
        XCTAssertFalse(app.buttons["session-done"].isEnabled)
        plus.tap()
        XCTAssertTrue(app.buttons["session-done"].isEnabled)
        let edited = app.textFields["weight-field"].firstMatch.value as? String
        app.buttons["session-done"].tap()

        XCTAssertTrue(app.buttons["session-edit"].appears(timeout: 5))
        let after = app.descendants(matching: .any)["weight-value"].firstMatch
        XCTAssertTrue(after.appears(timeout: 5))
        XCTAssertNotEqual(after.value as? String, saved)
        // El número: el campo y el valor de solo lectura pueden decir o no los kilos.
        XCTAssertEqual((after.value as? String)?.split(separator: " ").first, edited?.split(separator: " ").first)
    }

    /// Abre la primera sesión del Historial y la tarjeta de press banca.
    @MainActor
    private func openFirstSessionCard() -> XCUIApplication {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.appears(timeout: 10))
        first.tap()
        let card = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(card.appears(timeout: 10))
        card.tap()
        return app
    }
}
