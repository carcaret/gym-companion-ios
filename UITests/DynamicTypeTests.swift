import XCTest

/// La letra sigue el tamaño de texto del iPhone (Dynamic Type): con letra grande, las tarjetas
/// crecen para que quepa. Con el tamaño normal todo mide lo que en la PWA.
final class DynamicTypeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaLetraGrandeAgrandaLasTarjetas() {
        let normal = routineCardHeight(size: "UICTContentSizeCategoryL", capture: nil)
        let large = routineCardHeight(size: "UICTContentSizeCategoryAccessibilityM", capture: "70-letra-grande")
        XCTAssertGreaterThan(large, normal * 1.3, "Con letra grande la tarjeta de la rutina tiene que crecer")
    }

    /// El alto de la tarjeta del Día 1 con el tamaño de texto `size`; con `capture`, guarda las
    /// pantallas de Rutinas y del entreno para el artefacto de capturas.
    @MainActor
    private func routineCardHeight(size: String, capture: String?) -> CGFloat {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        app.tabBars.buttons["Rutinas"].tap()
        let card = app.buttons["routine-DIA1"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let height = card.frame.height
        if let capture {
            screenshot(app, "\(capture)-rutinas")
            card.tap()
            app.buttons["start-workout"].tap()
            let exercise = app.buttons["card-press_banca"].firstMatch
            XCTAssertTrue(exercise.waitForExistence(timeout: 10))
            exercise.tap()
            screenshot(app, "\(capture)-entreno")
        }
        app.terminate()
        return height
    }

    @MainActor
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
