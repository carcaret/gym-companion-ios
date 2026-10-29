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
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let first = app.firstHistorySession
        XCTAssertTrue(first.appears(timeout: 10))
        first.tap()
        let card = app.buttons[AccessibilityID.card("press_banca")].firstMatch
        XCTAssertTrue(card.appears(timeout: 10))

        swipeBackHalfway(app)
        XCTAssertTrue(card.appears(timeout: 5), "Soltar a medias tiene que dejar el detalle abierto")

        swipeBackFully(app)
        XCTAssertTrue(first.appears(timeout: 5), "Deslizar del todo vuelve a la lista")
    }

    @MainActor
    func testDeslizarAMediasNoCierraLaVistaPrevia() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 10))
        app.buttons[AccessibilityID.routine("DIA1")].tap()
        let start = app.buttons[AccessibilityID.startWorkout]
        XCTAssertTrue(start.appears(timeout: 10))

        swipeBackHalfway(app)
        XCTAssertTrue(start.appears(timeout: 5), "Soltar a medias tiene que dejar la vista previa abierta")

        swipeBackFully(app)
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 5), "Deslizar del todo vuelve al selector")
    }

    /// Como en iOS: cambiar de pestaña y volver deja la pantalla donde estaba (decisión del
    /// usuario, 2026-10-25; la PWA volvía a la de entrada).
    @MainActor
    func testCambiarDePestanaConservaLaPantalla() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let first = app.firstHistorySession
        XCTAssertTrue(first.appears(timeout: 20))
        first.tap()
        let card = app.buttons[AccessibilityID.card("press_banca")].firstMatch
        XCTAssertTrue(card.appears(timeout: 20))

        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 20))
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(card.appears(timeout: 10), "Al volver a Historial tiene que seguir el detalle")
    }

    /// Tocar otra vez la pestaña activa vuelve a su pantalla de entrada: el detalle del historial,
    /// la vista previa de una rutina y lo empujado en Progreso.
    @MainActor
    func testTocarOtraVezLaPestanaVuelveALaEntrada() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Historial"].tap()
        let first = app.firstHistorySession
        XCTAssertTrue(first.appears(timeout: 20))
        first.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.card("press_banca")].firstMatch.appears(timeout: 20))
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(first.appears(timeout: 10), "Tocar otra vez Historial vuelve a la lista")

        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 20))
        app.buttons[AccessibilityID.routine("DIA1")].tap()
        let start = app.buttons[AccessibilityID.startWorkout]
        XCTAssertTrue(start.appears(timeout: 20))
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 10), "Tocar otra vez Rutinas vuelve al selector")
        // Hasta que la vista previa acaba de cerrarse: un toque en la barra de pestañas durante la
        // animación de volver se pierde, y el test seguía en Rutinas (2026-10-26).
        XCTAssertTrue(start.waitForNonExistence(timeout: 10))

        app.tabBars.buttons["Progreso"].tap()
        app.openChartsFromProgress()
        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.navigationBars["Progreso"].appears(timeout: 10), "Tocar otra vez Progreso cierra las gráficas")
    }

    /// «Ver en Gráficas» empuja las gráficas dentro de Progreso, sin cambiar de pestaña, y se vuelve
    /// deslizando desde el borde, como en iOS (decisión del usuario, 2026-10-25).
    @MainActor
    func testVerEnGraficasEntraEmpujadaEnProgreso() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Progreso"].tap()
        app.openChartsFromProgress()
        XCTAssertTrue(app.tabBars.buttons["Progreso"].isSelected, "Las gráficas se abren dentro de Progreso")
        // La fila del ejercicio es un `NavigationLink`: su texto va en la etiqueta del botón.
        XCTAssertTrue(app.buttons[AccessibilityID.chartExercise].label.contains("Press Banca"), "Con el ejercicio elegido")

        swipeBackFully(app)
        XCTAssertTrue(app.navigationBars["Progreso"].appears(timeout: 10), "Deslizar vuelve a Progreso")
    }

    /// El entreno terminado entra empujado sobre las rutinas: se vuelve deslizando desde el borde,
    /// como en la vista previa (decisión del usuario, 2026-10-27).
    @MainActor
    func testDeslizarDesdeElEntrenoTerminadoVuelveALasRutinas() {
        let app = XCUIApplication.launchDemo()
        app.tabBars.buttons["Rutinas"].tap()
        let routine = app.buttons[AccessibilityID.routine("DIA1")]
        XCTAssertTrue(routine.appears(timeout: 20))
        routine.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.startWorkout].appears(timeout: 10))
        app.buttons[AccessibilityID.startWorkout].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.finishWorkout].appears(timeout: 10))
        app.buttons[AccessibilityID.finishWorkout].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.workoutCompleted].firstMatch.appears(timeout: 10))

        swipeBackFully(app)
        XCTAssertTrue(routine.appears(timeout: 10), "Deslizar desde el entreno terminado vuelve a las rutinas")
    }

    /// La nube de la sincronización sale también en las pantallas empujadas, que traen su propia
    /// barra: antes solo estaba en la de entrada de cada pestaña (2026-10-27).
    @MainActor
    func testLaNubeSaleEnLasPantallasEmpujadas() {
        let app = XCUIApplication.launchDemo()

        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA1")].appears(timeout: 20))
        app.buttons[AccessibilityID.routine("DIA1")].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.startWorkout].appears(timeout: 10))
        assertSyncIndicator(app, "en la vista previa de una rutina")

        app.tabBars.buttons["Historial"].tap()
        let session = app.firstHistorySession
        XCTAssertTrue(session.appears(timeout: 10))
        session.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.card("press_banca")].firstMatch.appears(timeout: 10))
        assertSyncIndicator(app, "en el detalle del historial")

        app.tabBars.buttons["Gráficas"].tap()
        let exercise = app.buttons[AccessibilityID.chartExercise]
        XCTAssertTrue(exercise.appears(timeout: 10))
        exercise.tap()
        XCTAssertTrue(app.buttons["Press Banca"].firstMatch.appears(timeout: 10))
        assertSyncIndicator(app, "al elegir ejercicio en Gráficas")

        app.tabBars.buttons["Progreso"].tap()
        app.openChartsFromProgress()
        assertSyncIndicator(app, "en las gráficas abiertas desde Progreso")

        app.tabBars.buttons["Progreso"].tap()
        XCTAssertTrue(app.navigationBars["Progreso"].appears(timeout: 10))
        // El catálogo, en la barra de Progreso, a la izquierda de la nube: el borde izquierdo es
        // para volver (repaso de la HIG, 2026-10-28).
        let catalog = app.buttons[AccessibilityID.catalogButton]
        let indicator = app.buttons[AccessibilityID.syncIndicator]
        XCTAssertGreaterThan(catalog.frame.minX, app.windows.firstMatch.frame.midX, "El catálogo va a la derecha")
        XCTAssertLessThanOrEqual(catalog.frame.maxX, indicator.frame.minX, "El catálogo va a la izquierda de la nube")
        catalog.tap()
        XCTAssertTrue(app.navigationBars["Ejercicios"].appears(timeout: 10))
        assertSyncIndicator(app, "en el catálogo")
    }

    @MainActor
    private func assertSyncIndicator(_ app: XCUIApplication, _ place: String) {
        let indicator = app.buttons[AccessibilityID.syncIndicator]
        XCTAssertTrue(indicator.appears(timeout: 5) && indicator.isHittable, "Falta la nube \(place)")
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
