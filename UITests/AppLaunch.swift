import XCTest

extension XCUIApplication {
    /// La app arrancada con los datos de ejemplo (`-demo`) y lo que se pida además.
    @MainActor
    static func launchDemo(_ extra: LaunchArgument..., arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.demo.rawValue] + extra.map(\.rawValue) + arguments
        app.launch()
        return app
    }

    /// Rutinas → Día 1 → «Iniciar entreno», hasta que sale el entreno en curso.
    @MainActor
    func startWorkout(timeout: TimeInterval = 10) {
        tabBars.buttons["Rutinas"].tap()
        XCTAssertTrue(buttons["routine-DIA1"].appears(timeout: timeout))
        buttons["routine-DIA1"].tap()
        XCTAssertTrue(buttons["start-workout"].appears(timeout: 10))
        buttons["start-workout"].tap()
        XCTAssertTrue(buttons["finish-workout"].appears(timeout: 10))
    }
}
