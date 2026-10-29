import XCTest

/// Recorre las pantallas principales y guarda una captura de cada una en el resultado de los
/// tests; el CI las publica como artefacto "capturas" (ver CLAUDE.md).
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Cada pestaña se abre y enseña su título.
    @MainActor
    func testPestanas() {
        let app = XCUIApplication()
        app.launch()
        // Pestaña, título de su pantalla y nombre de la captura.
        let tabs = [("Rutinas", "Rutinas", "01-rutinas"), ("Historial", "Historial", "02-historial"),
                    ("Progreso", "Progreso", "03-progreso"), ("Gráficas", "Gráficas", "04-graficas")]
        for (tab, title, name) in tabs {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[title].appears(timeout: 10), "No se abrió \(tab)")
            capture(app, name)
        }
        XCTAssertTrue(app.buttons["sync-indicator"].exists)
    }

    /// Hoy con datos de ejemplo (`-demo`): selector, vista previa, entreno, tarjeta abierta y
    /// entreno terminado.
    @MainActor
    func testHoy() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].appears(timeout: 10))
        capture(app, "10-hoy-selector")

        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
        capture(app, "11-hoy-vista-previa")

        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["finish-workout"].appears(timeout: 10))
        capture(app, "12-hoy-entreno")

        app.buttons["card-press_banca"].firstMatch.tap()
        capture(app, "13-hoy-tarjeta")

        // Un toque en la penúltima barra de «Últimas sesiones»: su bocadillo.
        let bars = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'strip-bar-'"))
        XCTAssertTrue(bars.firstMatch.appears(timeout: 10))
        bars.element(boundBy: bars.count - 2).tap()
        capture(app, "15-hoy-tira-bocadillo")

        app.buttons["finish-workout"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["workout-completed"].firstMatch.appears(timeout: 10))
        capture(app, "14-hoy-terminado")

        app.tabBars.buttons["Historial"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(first.appears(timeout: 10))
        capture(app, "20-historial-lista")

        first.tap()
        XCTAssertTrue(app.buttons["card-press_banca"].firstMatch.appears(timeout: 10))
        app.buttons["card-press_banca"].firstMatch.tap()
        // Con la tarjeta ya abierta del todo: sin esperar, la captura salía a medio abrir.
        XCTAssertTrue(app.descendants(matching: .any)["series-0"].firstMatch.appears(timeout: 10))
        capture(app, "21-historial-detalle")

        app.buttons["session-edit"].tap()
        XCTAssertTrue(app.buttons["session-done"].appears(timeout: 10))
        XCTAssertTrue(app.buttons["weight-plus"].firstMatch.appears(timeout: 10))
        capture(app, "22-historial-editando")
        // Sin cambios, la ✕ cierra la hoja sin preguntar.
        app.buttons["session-cancel"].tap()
        XCTAssertTrue(app.buttons["session-edit"].appears(timeout: 10))

        app.tabBars.buttons["Gráficas"].tap()
        let exercise = app.buttons["chart-exercise"]
        XCTAssertTrue(exercise.appears(timeout: 10))
        exercise.tap()
        XCTAssertTrue(app.buttons["Press Banca"].firstMatch.appears(timeout: 10))
        capture(app, "30-graficas-elegir")
        app.buttons["Press Banca"].firstMatch.tap()
        XCTAssertTrue(exercise.appears(timeout: 10))
        capture(app, "31-graficas")

        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.buttons["stats-exercises"].appears(timeout: 10))
        app.buttons["stats-exercises"].tap()
        capture(app, "40-progreso")

        app.buttons["stats-row-press_banca"].tap()
        app.buttons["Ver en Gráficas"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Gráficas"].appears(timeout: 10))
        capture(app, "41-progreso-graficas")
        app.tabBars.buttons["Progreso"].tap()  // tocar otra vez la pestaña vuelve a Progreso
        XCTAssertTrue(app.navigationBars["Progreso"].appears(timeout: 10))

        // El catálogo, en la barra de Progreso.
        app.buttons["catalog-button"].tap()
        XCTAssertTrue(app.navigationBars["Ejercicios"].appears(timeout: 10))
        capture(app, "50-catalogo")

        // Los ajustes, desde la nube de la pantalla de entrada de Rutinas.
        app.tabBars.buttons["Rutinas"].tap()
        app.openSyncSettings()
        XCTAssertTrue(app.staticTexts["settings-version"].appears(timeout: 10))
        capture(app, "60-ajustes")
    }
}
