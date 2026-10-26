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
                    ("Progreso", "Estadísticas", "03-progreso"), ("Gráficas", "Gráficas", "04-graficas")]
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
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
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
        capture(app, "21-historial-detalle")

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
        app.tabBars.buttons["Progreso"].tap()  // tocar otra vez la pestaña vuelve a Estadísticas
        XCTAssertTrue(app.navigationBars["Estadísticas"].appears(timeout: 10))

        // La tarjeta del catálogo está al final de la lista: la List no la crea hasta que se ve.
        let catalog = app.buttons["catalog-card"].firstMatch
        for _ in 0..<6 where !catalog.isHittable {
            app.swipeUp()
        }
        catalog.tap()
        XCTAssertTrue(app.navigationBars["Ejercicios"].appears(timeout: 10))
        capture(app, "50-catalogo")

        // El indicador (y con él los ajustes) está en la pantalla de entrada de cada pestaña, no en
        // las empujadas como el catálogo.
        app.tabBars.buttons["Rutinas"].tap()
        app.openSyncSettings()
        XCTAssertTrue(app.staticTexts["settings-version"].appears(timeout: 10))
        capture(app, "60-ajustes")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
