import XCTest

/// Solo para la rama de prueba visual: el CI graba el simulador mientras este test mantiene el
/// dedo sobre una gráfica de la pestaña Gráficas, para ver el valor del punto.
final class VideoTarjetasTests: XCTestCase {
    @MainActor
    func testGrafica() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        app.tabBars.buttons["Gráficas"].tap()
        let exercise = app.buttons["chart-exercise"]
        XCTAssertTrue(exercise.appears(timeout: 20))
        Thread.sleep(forTimeInterval: 1.5)
        exercise.tap()
        XCTAssertTrue(app.buttons["Press Banca"].firstMatch.appears(timeout: 10))
        app.buttons["Press Banca"].firstMatch.tap()
        XCTAssertTrue(exercise.appears(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        // La primera gráfica, debajo de los filtros: el dedo en el centro, dos veces.
        for dx in [0.5, 0.85] {
            app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.62)).press(forDuration: 2.0)
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
}
