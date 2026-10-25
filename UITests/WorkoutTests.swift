import XCTest

/// El entreno en curso con los gestos de iOS: deslizar una tarjeta a la izquierda ofrece Saltar y
/// Quitar, lo mismo que los botones del pie de la tarjeta.
final class WorkoutTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDeslizarUnaTarjetaLaSaltaYLaReactiva() {
        let app = startWorkout()
        let card = app.buttons["card-curl_biceps"].firstMatch

        card.swipeLeft()
        let skip = app.buttons["Saltar"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        card.swipeLeft()
        XCTAssertTrue(app.buttons["Reactivar"].firstMatch.waitForExistence(timeout: 5), "Saltada, el gesto ofrece reactivarla")
    }

    @MainActor
    func testDeslizarUnaTarjetaLaQuitaTrasConfirmar() {
        let app = startWorkout()
        let card = app.buttons["card-curl_biceps"].firstMatch
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
        let before = rows.count

        card.swipeLeft()
        let remove = app.buttons["Quitar de rutina"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        // Mientras se confirma, la tarjeta sigue en su sitio.
        let confirm = app.buttons["Quitar"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, before)
        confirm.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: card)
        wait(for: [gone], timeout: 5)
    }

    @MainActor
    private func startWorkout() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(app.buttons["routine-DIA1"].waitForExistence(timeout: 10))
        app.buttons["routine-DIA1"].tap()
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
        app.buttons["start-workout"].tap()
        XCTAssertTrue(app.buttons["card-curl_biceps"].firstMatch.waitForExistence(timeout: 10))
        return app
    }
}
