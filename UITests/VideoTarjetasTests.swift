import XCTest

/// Solo para la rama de prueba visual: el CI graba el simulador mientras este test toca las
/// tarjetas y abre y cierra los desplegables. Cada paso deja su hora en el log.
final class VideoTarjetasTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func mark(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("MARCA \(formatter.string(from: .now)) \(text)")
    }

    private func pause(_ seconds: Double = 1.5) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    func testTarjetasYDesplegables() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        let routine = app.buttons["routine-DIA1"]
        XCTAssertTrue(routine.appears(timeout: 20))
        pause()

        mark("sonda: crecer en 2 s")
        app.buttons["sonda-animacion"].tap()
        pause(3)
        mark("sonda: encoger en 2 s")
        app.buttons["sonda-animacion"].tap()
        pause(3)

        mark("rutina: pulsación larga a la derecha")
        routine.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).press(forDuration: 1.0)
        let card = app.buttons["card-press_banca"].firstMatch
        XCTAssertTrue(card.appears(timeout: 10))
        pause()

        mark("vista previa: abrir tarjeta")
        card.tap()
        pause()
        mark("vista previa: cerrar tarjeta")
        card.tap()
        pause()

        mark("volver al selector")
        app.tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(routine.appears(timeout: 10))
        pause()
        mark("rutina: toque rápido a la izquierda")
        routine.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.3)).tap()
        XCTAssertTrue(card.appears(timeout: 10))
        pause()
        app.tabBars.buttons["Rutinas"].tap()
        pause()

        app.tabBars.buttons["Historial"].tap()
        let session = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-'")).firstMatch
        XCTAssertTrue(session.appears(timeout: 10))
        pause()
        mark("historial: pulsación larga a la izquierda")
        session.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 1.0)
        XCTAssertTrue(card.appears(timeout: 10))
        pause()
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(session.appears(timeout: 10))
        pause()
        mark("historial: toque rápido en el centro")
        session.tap()
        XCTAssertTrue(card.appears(timeout: 10))
        pause()
        mark("historial: abrir tarjeta")
        card.tap()
        pause()
        mark("historial: cerrar tarjeta")
        card.tap()
        pause()

        app.tabBars.buttons["Progreso"].tap()
        let exercises = app.buttons["stats-exercises"]
        XCTAssertTrue(exercises.appears(timeout: 10))
        pause()
        mark("progreso: abrir ejercicios")
        exercises.tap()
        pause()
        let row = app.buttons["stats-row-press_banca"]
        if row.appears(timeout: 5) {
            mark("progreso: abrir fila")
            row.tap()
            pause()
            mark("progreso: cerrar fila")
            row.tap()
            pause()
        }
        mark("progreso: cerrar ejercicios")
        exercises.tap()
        pause()
        mark("fin")
    }
}
