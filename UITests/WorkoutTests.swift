import XCTest

/// El entreno en curso con los gestos de iOS: deslizar una tarjeta a la izquierda ofrece quitarla y a
/// la derecha cambiarla o saltarla (sin hacer nada hasta que se elige).
final class WorkoutTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDeslizarUnaTarjetaLaSaltaYLaReactiva() {
        let app = startWorkout()
        let card = app.buttons[AccessibilityID.card("curl_biceps")].firstMatch

        card.swipeRight()
        let skip = app.buttons["Saltar"].firstMatch
        XCTAssertTrue(skip.appears(timeout: 5))
        skip.tap()

        card.swipeRight()
        XCTAssertTrue(app.buttons["Reactivar"].firstMatch.appears(timeout: 5), "Saltada, el gesto ofrece reactivarla")
    }

    @MainActor
    func testDeslizarUnaTarjetaALaDerechaOfreceCambiarla() {
        let app = startWorkout()
        let card = app.buttons[AccessibilityID.card("curl_biceps")].firstMatch

        card.swipeRight()
        let swap = app.buttons["Cambiar por otro"].firstMatch
        XCTAssertTrue(swap.appears(timeout: 5))
        XCTAssertFalse(app.navigationBars["Cambiar ejercicio"].exists, "Deslizar solo enseña las opciones")
        swap.tap()

        XCTAssertTrue(app.navigationBars["Cambiar ejercicio"].appears(timeout: 5))
    }

    @MainActor
    func testDeslizarUnaTarjetaLaQuitaTrasConfirmar() {
        let app = startWorkout()
        let card = app.buttons[AccessibilityID.card("curl_biceps")].firstMatch
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.cardPrefix))
        let before = rows.count

        card.swipeLeft()
        let remove = app.buttons["Quitar de rutina"].firstMatch
        XCTAssertTrue(remove.appears(timeout: 5))
        XCTAssertFalse(app.buttons["Saltar"].exists, "A la izquierda solo se quita")
        remove.tap()
        // Mientras se confirma, la tarjeta sigue en su sitio.
        let confirm = app.buttons["Quitar"].firstMatch
        XCTAssertTrue(confirm.appears(timeout: 5))
        XCTAssertEqual(rows.count, before)
        confirm.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: card)
        wait(for: [gone], timeout: 5)
    }

    /// «Añadir ejercicio» y «Finalizar entreno» miden lo mismo: la principal se distingue por el
    /// estilo, no por el tamaño (repaso de la HIG, 2026-10-28).
    @MainActor
    func testLosDosBotonesDeAbajoMidenLoMismo() {
        let app = startWorkout()
        let add = app.buttons[AccessibilityID.addExercise].frame
        let finish = app.buttons[AccessibilityID.finishWorkout].frame
        XCTAssertEqual(add.width, finish.width, accuracy: 1)
        XCTAssertEqual(add.height, finish.height, accuracy: 1)
    }

    /// Los botones de abajo miden 50 pt de alto, los botones grandes de iOS: medían 40, menos que
    /// los 44 de una zona de toque (repaso de la HIG, 2026-10-28).
    @MainActor
    func testLosBotonesDeAbajoMiden50DeAlto() {
        let app = startWorkout()
        for name in [AccessibilityID.addExercise, AccessibilityID.finishWorkout] {
            let height = app.buttons[name].frame.height
            XCTAssertGreaterThanOrEqual(height, 50, "\(name) mide \(height) pt de alto")
        }
    }

    /// Crear un ejercicio sin buscar es una pantalla con el nombre y el grupo, no una alerta con un
    /// campo (repaso de la HIG, 2026-10-28). La ✓ lo crea y entra en el entreno.
    @MainActor
    func testCrearUnEjercicioEnSuPantalla() {
        let app = startWorkout()
        app.buttons[AccessibilityID.addExercise].tap()
        let create = app.buttons[AccessibilityID.createExercise]
        XCTAssertTrue(create.appears(timeout: 10))
        create.tap()
        XCTAssertTrue(app.navigationBars["Crear nuevo ejercicio"].appears(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let confirm = app.buttons[AccessibilityID.createConfirm]
        XCTAssertFalse(confirm.isEnabled, "Sin nombre, la ✓ sale apagada")

        let name = app.textFields[AccessibilityID.createName]
        XCTAssertTrue(name.appears(timeout: 5))
        name.tap()
        name.typeText("Press Arnold")
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.card("press_arnold"))).firstMatch.appears(timeout: 10))
    }

    /// «Finalizar entreno» pregunta antes (decisión del usuario, 2026-10-31): tocar fuera del globo
    /// sigue con el entreno y «Finalizar» vuelve a las rutinas, sin pantalla de entreno terminado.
    @MainActor
    func testFinalizarPreguntaAntes() {
        let app = startWorkout()
        app.buttons[AccessibilityID.finishWorkout].tap()
        let confirm = app.buttons["Finalizar"].firstMatch
        XCTAssertTrue(confirm.appears(timeout: 5), "Tiene que preguntar antes de finalizar")
        // En iOS 26 el diálogo es un globo sin «Cancelar»: se cierra tocando fuera.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: confirm)
        wait(for: [closed], timeout: 5)
        XCTAssertTrue(app.buttons[AccessibilityID.finishWorkout].exists, "Tocar fuera sigue con el entreno")

        app.finishWorkout()
    }

    /// Con el entreno de hoy terminado, empezar otra rutina pregunta antes de sustituirlo
    /// (2026-10-27; la PWA lo borraba sin decir nada). Tocar fuera del globo lo deja y «Sustituir» empieza.
    @MainActor
    func testEmpezarOtraRutinaElMismoDiaPregunta() {
        let app = startWorkout()
        app.finishWorkout()
        XCTAssertTrue(app.buttons[AccessibilityID.routine("DIA2")].appears(timeout: 10))
        app.buttons[AccessibilityID.routine("DIA2")].tap()
        let start = app.buttons[AccessibilityID.startWorkout]
        XCTAssertTrue(start.appears(timeout: 10))

        start.tap()
        let replace = app.buttons["Sustituir"].firstMatch
        XCTAssertTrue(replace.appears(timeout: 5), "Tiene que preguntar antes de sustituir el entreno de hoy")
        // En iOS 26 el diálogo es un globo sin «Cancelar»: se cierra tocando fuera.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: replace)
        wait(for: [closed], timeout: 5)
        XCTAssertFalse(app.buttons[AccessibilityID.finishWorkout].exists, "Tocar fuera no empieza nada")

        start.tap()
        XCTAssertTrue(replace.appears(timeout: 5))
        replace.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.finishWorkout].appears(timeout: 10), "Sustituir empieza el entreno nuevo")
    }

    /// Si la búsqueda no encuentra el ejercicio, se crea de un toque con el teclado abierto, sin
    /// alerta (2026-10-27: con alerta, el primer toque solo cerraba el teclado; probado en el iPhone).
    @MainActor
    func testCrearLoBuscadoDeUnToque() {
        let app = startWorkout()
        app.buttons[AccessibilityID.addExercise].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.appears(timeout: 5))
        search.tap()
        search.typeText("Press Arnold")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let create = app.buttons[AccessibilityID.createFromSearch].firstMatch
        XCTAssertTrue(create.appears(timeout: 5))
        XCTAssertEqual(create.label, "Crear «Press Arnold»")
        create.tap()
        XCTAssertTrue(app.buttons[AccessibilityID.card("press_arnold")].firstMatch.appears(timeout: 5), "Un toque lo crea y lo añade al entreno")
    }

    @MainActor
    private func startWorkout() -> XCUIApplication {
        let app = XCUIApplication.launchDemo()
        app.startWorkout()
        XCTAssertTrue(app.buttons[AccessibilityID.card("curl_biceps")].firstMatch.appears(timeout: 10))
        return app
    }
}
