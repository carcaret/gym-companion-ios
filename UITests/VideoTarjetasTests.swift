import XCTest

/// Solo para la rama de prueba visual: el CI graba el simulador mientras este test abre y cierra
/// una tarjeta del entreno en curso con varias formas de animarla (`-variante`), y una fila de
/// Progreso.
final class VideoTarjetasTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func mark(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("MARCA \(formatter.string(from: .now)) \(text)")
    }

    /// La cabecera: arriba del todo de la tarjeta (en el centro, abierta, cae en el peso).
    @MainActor
    private func tapHeader(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0)).withOffset(CGVector(dx: 0, dy: 24)).tap()
    }

    @MainActor
    func testEntreno() {
        for variant in ["pr", "sin-offset", "por-valor"] {
            let app = XCUIApplication()
            app.launchArguments = ["-demo", "-variante", variant]
            app.launch()
            app.tabBars.buttons["Rutinas"].tap()
            let routine = app.buttons["routine-DIA1"]
            XCTAssertTrue(routine.appears(timeout: 20))
            routine.tap()
            XCTAssertTrue(app.buttons["start-workout"].appears(timeout: 10))
            app.buttons["start-workout"].tap()
            XCTAssertTrue(app.buttons["finish-workout"].appears(timeout: 10))
            let card = app.buttons["card-press_banca"].firstMatch
            XCTAssertTrue(card.appears(timeout: 10))
            Thread.sleep(forTimeInterval: 1.5)
            for round in 1...2 {
                mark("\(variant): abrir \(round)")
                tapHeader(card)
                Thread.sleep(forTimeInterval: 1.5)
                mark("\(variant): cerrar \(round)")
                tapHeader(card)
                Thread.sleep(forTimeInterval: 1.5)
            }
            if variant == "pr" {
                app.tabBars.buttons["Progreso"].tap()
                let expand = app.buttons["stats-exercises"]
                XCTAssertTrue(expand.appears(timeout: 10))
                expand.tap()
                let row = app.buttons["stats-row-press_banca"]
                XCTAssertTrue(row.appears(timeout: 10))
                Thread.sleep(forTimeInterval: 1.5)
                mark("progreso: abrir")
                row.tap()
                Thread.sleep(forTimeInterval: 1.5)
                mark("progreso: cerrar")
                row.tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
            app.terminate()
        }
        mark("fin")
    }
}
