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
        let card = app.buttons["card-curl_biceps"].firstMatch

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
        let card = app.buttons["card-curl_biceps"].firstMatch

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
        let card = app.buttons["card-curl_biceps"].firstMatch
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
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

    /// Con el entreno de hoy terminado, empezar otra rutina pregunta antes de sustituirlo
    /// (2026-10-27; la PWA lo borraba sin decir nada). «Cancelar» lo deja y «Sustituir» empieza.
    @MainActor
    func testEmpezarOtraRutinaElMismoDiaPregunta() {
        let app = startWorkout()
        app.buttons["finish-workout"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["workout-completed"].firstMatch.appears(timeout: 10))
        // Tocar otra vez la pestaña vuelve a las rutinas.
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA2"].appears(timeout: 10))
        app.buttons["routine-DIA2"].tap()
        let start = app.buttons["start-workout"]
        XCTAssertTrue(start.appears(timeout: 10))

        start.tap()
        let replace = app.buttons["Sustituir"].firstMatch
        XCTAssertTrue(replace.appears(timeout: 5), "Tiene que preguntar antes de sustituir el entreno de hoy")
        app.buttons["Cancelar"].firstMatch.tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: replace)
        wait(for: [closed], timeout: 5)
        XCTAssertFalse(app.buttons["finish-workout"].exists, "Cancelar no empieza nada")

        start.tap()
        XCTAssertTrue(replace.appears(timeout: 5))
        replace.tap()
        XCTAssertTrue(app.buttons["finish-workout"].appears(timeout: 10), "Sustituir empieza el entreno nuevo")
    }

    @MainActor
    private func startWorkout() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].appears(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["card-curl_biceps"].firstMatch.appears(timeout: 10))
        return app
    }
}
