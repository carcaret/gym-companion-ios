import XCTest

/// La app de entreno del reloj (Series 10 de 46 mm) con datos de ejemplo y un entreno de mentira, y
/// sus capturas; el CI las publica en el artefacto "capturas" junto a las del iPhone (ver CLAUDE.md).
final class WatchScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// El entreno midiéndose: el tiempo y el primer ejercicio; con la corona, el segundo; el
    /// descanso, que un toque empieza y otro para; la música, los controles y el resumen.
    @MainActor
    func testEntreno() {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demo.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Press Banca"].appears(timeout: 20))
        XCTAssertTrue(app.staticTexts["toca para descansar"].exists)
        // Pasados 10 minutos (la demo va por 23:41), nada se monta: el pulso, en la fila de la
        // hora, queda encima del tiempo, y el tiempo no pisa su texto.
        let heartRate = app.descendants(matching: .any)[AccessibilityID.watchHeartRate].firstMatch
        let elapsed = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+:[0-9]{2}$")).firstMatch
        let restLabel = app.staticTexts["toca para descansar"]
        XCTAssertTrue(heartRate.exists)
        XCTAssertLessThanOrEqual(heartRate.frame.maxY, elapsed.frame.minY, "pulso \(heartRate.frame), tiempo \(elapsed.frame)")
        XCTAssertFalse(elapsed.frame.intersects(restLabel.frame), "tiempo \(elapsed.frame), texto \(restLabel.frame)")
        XCTAssertLessThanOrEqual(restLabel.frame.maxX, app.windows.firstMatch.frame.maxX, "el texto se sale: \(restLabel.frame)")
        capture(app, "70-reloj-entreno")

        // Los ejercicios son páginas de un `ScrollView`: todos están en la jerarquía y, recortados,
        // siguen siendo «hittable», así que se mira cuál cae dentro de la lista. Deslizar es lo
        // mismo que la corona, que mueve el `ScrollView` sola.
        let exercises = app.descendants(matching: .any)[AccessibilityID.watchExercises].firstMatch
        let first = app.staticTexts["Press Banca"], second = app.staticTexts["Curl Bíceps"]
        func frames() -> String { "lista \(exercises.frame), primero \(first.frame), segundo \(second.frame)" }
        XCTAssertTrue(first.isShown(in: exercises), frames())
        // La lista llega hasta abajo: antes se cortaba unos 30 pt por encima de los puntos de las
        // páginas y «Última» no cabía (foto del reloj, 2026-10-30).
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(exercises.frame.maxY, screen.maxY - 12, "la lista no llega abajo: \(frames()), pantalla \(screen)")
        XCTAssertFalse(second.isShown(in: exercises), "se ve más de un ejercicio a la vez: \(frames())")
        exercises.swipeUp()
        XCTAssertTrue(second.becomesShown(in: exercises, timeout: 5), frames())
        XCTAssertFalse(first.isShown(in: exercises), "se ve más de un ejercicio a la vez: \(frames())")
        capture(app, "71-reloj-siguiente")

        let rest = app.buttons[AccessibilityID.watchRest]
        rest.tap()
        XCTAssertTrue(app.staticTexts["descanso"].appears(timeout: 5))
        capture(app, "72-reloj-descanso")
        rest.tap()
        XCTAssertTrue(app.staticTexts["toca para descansar"].appears(timeout: 5))

        // Como en Entreno: a la derecha, la música; a la izquierda, los controles.
        app.swipeLeft()
        capture(app, "73-reloj-musica")
        app.swipeRight()
        XCTAssertTrue(rest.appears(timeout: 5))

        app.swipeRight()
        let finish = app.buttons[AccessibilityID.watchFinish]
        XCTAssertTrue(finish.appears(timeout: 5))
        capture(app, "74-reloj-controles")

        // Pregunta antes de terminar (decisión del usuario, 2026-10-31).
        // Los botones de una alerta no llevan identificador (SwiftUI no les pasa los modificadores):
        // el de confirmar es el «Terminar» que no es el de la página.
        finish.tap()
        XCTAssertTrue(app.staticTexts["¿Terminar el entreno?"].appears(timeout: 5), "Tiene que preguntar antes de terminar")
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Terminar' AND identifier != %@", AccessibilityID.watchFinish)).firstMatch
        XCTAssertTrue(confirm.appears(timeout: 5), "La alerta no tiene el botón «Terminar»")
        capture(app, "75-reloj-terminar")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Entreno terminado"].appears(timeout: 10))
        capture(app, "76-reloj-resumen")

        // En la demo no hay iPhone que lo termine: el entreno sigue ahí y se puede volver a empezar.
        app.buttons[AccessibilityID.watchDone].tap()
        XCTAssertTrue(app.buttons[AccessibilityID.watchStart].appears(timeout: 5))
        capture(app, "77-reloj-empezar")
    }

    @MainActor
    func testSinEntreno() {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demoWithoutWorkout.rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["Empieza el entreno en el iPhone"].appears(timeout: 20))
        capture(app, "79-reloj-sin-entreno")
    }
}

private extension XCUIElement {
    /// Cae dentro de `container` (la parte visible de una lista).
    func isShown(in container: XCUIElement) -> Bool {
        exists && container.frame.intersection(frame).height > 1
    }

    func becomesShown(in container: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isShown(in: container) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return isShown(in: container)
    }
}
