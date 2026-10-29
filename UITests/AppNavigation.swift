import XCTest

// Los recorridos que repiten los tests de UI: arrancar, empezar el entreno, abrir una sesión, las
// gráficas desde Progreso y los ajustes.
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
        XCTAssertTrue(buttons[AccessibilityID.routine("DIA1")].appears(timeout: timeout))
        buttons[AccessibilityID.routine("DIA1")].tap()
        XCTAssertTrue(buttons[AccessibilityID.startWorkout].appears(timeout: 10))
        buttons[AccessibilityID.startWorkout].tap()
        XCTAssertTrue(buttons[AccessibilityID.finishWorkout].appears(timeout: 10))
    }

    /// La primera sesión del Historial (la más reciente).
    @MainActor
    var firstHistorySession: XCUIElement {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.historyPrefix)).firstMatch
    }

    /// Progreso → Ejercicios → Press Banca → «Ver en Gráficas», hasta que salen las gráficas.
    @MainActor
    func openChartsFromProgress() {
        let expand = buttons[AccessibilityID.statsExercises]
        XCTAssertTrue(expand.appears(timeout: 20))
        expand.tap()
        let row = buttons[AccessibilityID.statsRow("press_banca")]
        XCTAssertTrue(row.appears(timeout: 10))
        row.tap()
        let open = buttons["Ver en Gráficas"].firstMatch
        XCTAssertTrue(open.appears(timeout: 10))
        open.tap()
        XCTAssertTrue(navigationBars["Gráficas"].appears(timeout: 20))
    }

    /// Abre los ajustes de sincronización como lo haría el usuario: el menú del indicador y, con
    /// `-demo` (sin GitHub), «Configurar GitHub…».
    @MainActor
    func openSyncSettings() {
        let indicator = buttons[AccessibilityID.syncIndicator].firstMatch
        XCTAssertTrue(indicator.appears(timeout: 20))
        indicator.tap()
        let configure = buttons["Configurar GitHub…"].firstMatch
        XCTAssertTrue(configure.appears(timeout: 10))
        configure.tap()
        XCTAssertTrue(navigationBars["Sincronización"].appears(timeout: 10), "No se abrió la hoja de los ajustes")
    }
}
